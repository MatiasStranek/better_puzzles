import 'dart:convert';
import 'dart:io';

import 'package:bpuzzles_format/bpuzzles_format.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:puzzle_catalog_store/objectbox.g.dart' as catalog_obx;
import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';

import 'arguments.dart';
import 'csv_line_parser.dart';
import 'lichess_row.dart';

class CatalogBuildResult {
  const CatalogBuildResult({
    required this.packageFile,
    required this.catalogId,
    required this.puzzleCount,
    required this.minRating,
    required this.maxRating,
  });

  final File packageFile;
  final String catalogId;
  final int puzzleCount;
  final int minRating;
  final int maxRating;
}

class CatalogBuilder {
  CatalogBuilder(this.options);

  static const String builderVersion = '0.1.0';
  static const String objectBoxVersion = '5.3.2';

  final CatalogBuildArguments options;

  Future<CatalogBuildResult> build() async {
    final inputFile = File(options.inputPath);
    final outputFile = File(options.outputPath);
    final modelJsonFile = File(options.modelJsonPath);
    final workDirectory = Directory(options.workDirectoryPath);
    final objectBoxDirectory =
        Directory(p.join(workDirectory.path, 'objectbox'));
    final errorLogFile = File(options.errorLogPath);

    await _validateInputs(
      inputFile: inputFile,
      outputFile: outputFile,
      modelJsonFile: modelJsonFile,
      workDirectory: workDirectory,
    );

    stdout.writeln('Berechne SHA-256 der Quelldatei ...');
    final sourceSha256 = await sha256File(inputFile);
    final modelFingerprint = await sha256File(modelJsonFile);
    if (catalogModelFingerprint == 'UNGENERATED' ||
        catalogModelFingerprint != modelFingerprint) {
      throw StateError(
        'Der eingebettete Katalog-Modellfingerprint ist veraltet. '
        'Führe tool/setup_database_patch.ps1 erneut aus.',
      );
    }
    final themeDictionarySha256 = sha256
        .convert(utf8.encode(ThemeDictionaryV1.canonicalText))
        .toString();
    final catalogId =
        'lichess-${options.sourceDate.replaceAll('-', '')}-'
        '${sourceSha256.substring(0, 8)}';
    final createdAt = DateTime.now().toUtc();

    await workDirectory.create(recursive: true);
    await objectBoxDirectory.create(recursive: true);
    await errorLogFile.parent.create(recursive: true);
    if (await errorLogFile.exists()) {
      await errorLogFile.delete();
    }

    stdout
      ..writeln('Catalog ID: $catalogId')
      ..writeln('ObjectBox-Arbeitsordner: ${objectBoxDirectory.path}')
      ..writeln('Starte zstd-Streamingimport ...');

    final importStats = await _importCsvZst(
      inputFile: inputFile,
      objectBoxDirectory: objectBoxDirectory,
      errorLogFile: errorLogFile,
      catalogId: catalogId,
      createdAt: createdAt,
      sourceSha256: sourceSha256,
      modelFingerprint: modelFingerprint,
      themeDictionarySha256: themeDictionarySha256,
    );

    final databaseFile = File(p.join(objectBoxDirectory.path, 'data.mdb'));
    if (!await databaseFile.exists()) {
      throw FileSystemException(
        'ObjectBox hat keine data.mdb erzeugt',
        databaseFile.path,
      );
    }

    stdout.writeln('Berechne SHA-256 der fertigen data.mdb ...');
    final databaseSha256 = await sha256File(databaseFile);
    final databaseSizeBytes = await databaseFile.length();

    final manifest = BPuzzlesManifest(
      format: BPuzzlesManifest.supportedFormat,
      formatVersion: BPuzzlesManifest.supportedFormatVersion,
      catalogSchemaVersion: PuzzleCatalogConstants.schemaVersion,
      catalogId: catalogId,
      displayName: 'Lichess Puzzles ${options.sourceDate}',
      createdAtUtc: createdAt.toIso8601String(),
      source: BPuzzlesSourceInfo(
        name: 'Lichess Puzzle Database',
        sourceFile: p.basename(inputFile.path),
        sourceDate: options.sourceDate,
        sha256: sourceSha256,
        license: 'CC0',
      ),
      generator: BPuzzlesGeneratorInfo(
        name: 'better_puzzles_catalog_builder',
        version: builderVersion,
        objectBoxVersion: objectBoxVersion,
        command: options.commandText,
      ),
      database: BPuzzlesDatabaseInfo(
        engine: 'objectbox',
        entry: 'objectbox/data.mdb',
        catalogModelFingerprint: modelFingerprint,
        sha256: databaseSha256,
        sizeBytes: databaseSizeBytes,
        requiredMaxDbSizeKb: options.maxDbSizeKb,
      ),
      statistics: BPuzzlesStatistics(
        puzzleCount: importStats.puzzleCount,
        minRating: importStats.minRating,
        maxRating: importStats.maxRating,
        whiteToMoveCount: importStats.whiteToMoveCount,
        blackToMoveCount: importStats.blackToMoveCount,
        rejectedRowCount: importStats.rejectedRowCount,
        unknownThemeCount: importStats.unknownThemeCount,
      ),
      ratingBuckets: BPuzzlesRatingBuckets(
        size: options.ratingBucketSize,
        minBucket:
            (importStats.minRating ~/ options.ratingBucketSize) *
                options.ratingBucketSize,
        maxBucket:
            (importStats.maxRating ~/ options.ratingBucketSize) *
                options.ratingBucketSize,
      ),
      themes: BPuzzlesThemeInfo(
        dictionaryVersion: ThemeDictionaryV1.version,
        dictionarySha256: themeDictionarySha256,
        maskBits: ThemeDictionaryV1.maskBits,
        dictionary: ThemeDictionaryV1.themes,
      ),
    );

    final manifestErrors = manifest.validate(
      expectedModelFingerprint: modelFingerprint,
    );
    if (manifestErrors.isNotEmpty) {
      throw StateError(
        'Intern erzeugtes Manifest ist ungültig:\n'
        '${manifestErrors.join('\n')}',
      );
    }

    stdout.writeln('Schreibe streambares .bpuzzles-Paket ...');
    var lastPercent = -1;
    await const BPuzzlesPackageWriter().write(
      databaseFile: databaseFile,
      outputFile: outputFile,
      manifest: manifest,
      overwrite: options.overwrite,
      onProgress: (copied, total) {
        final percent = total == 0 ? 100 : (copied * 100 ~/ total);
        if (percent >= lastPercent + 5 || percent == 100) {
          lastPercent = percent;
          stdout.writeln('  Paket: $percent %');
        }
      },
    );

    if (!options.keepWork) {
      await workDirectory.delete(recursive: true);
    }

    return CatalogBuildResult(
      packageFile: outputFile,
      catalogId: catalogId,
      puzzleCount: importStats.puzzleCount,
      minRating: importStats.minRating,
      maxRating: importStats.maxRating,
    );
  }

  Future<void> _validateInputs({
    required File inputFile,
    required File outputFile,
    required File modelJsonFile,
    required Directory workDirectory,
  }) async {
    if (!await inputFile.exists()) {
      throw FileSystemException(
        'Eingabedatei nicht gefunden',
        inputFile.path,
      );
    }
    if (!inputFile.path.toLowerCase().endsWith('.csv.zst')) {
      throw FormatException(
        'Eingabe muss eine .csv.zst-Datei sein: ${inputFile.path}',
      );
    }
    if (!await modelJsonFile.exists()) {
      throw FileSystemException(
        'ObjectBox-Modell fehlt. Zuerst '
        'tool/setup_database_patch.ps1 ausführen.',
        modelJsonFile.path,
      );
    }

    if (await outputFile.exists() && !options.overwrite) {
      throw FileSystemException(
        'Ausgabedatei existiert bereits; --overwrite verwenden',
        outputFile.path,
      );
    }

    if (await workDirectory.exists()) {
      if (!options.overwrite) {
        throw FileSystemException(
          'Arbeitsordner existiert bereits; --overwrite verwenden',
          workDirectory.path,
        );
      }
      await workDirectory.delete(recursive: true);
    }
  }

  Future<_ImportStats> _importCsvZst({
    required File inputFile,
    required Directory objectBoxDirectory,
    required File errorLogFile,
    required String catalogId,
    required DateTime createdAt,
    required String sourceSha256,
    required String modelFingerprint,
    required String themeDictionarySha256,
  }) async {
    final store = catalog_obx.openStore(
      directory: objectBoxDirectory.path,
      maxDBSizeInKB: options.maxDbSizeKb,
    );
    final puzzleBox = store.box<PuzzleEntity>();
    final metaBox = store.box<CatalogMetaEntity>();
    final errorSink = errorLogFile.openWrite();
    Process? process;

    var puzzleCount = 0;
    var rejectedRowCount = 0;
    var unknownThemeCount = 0;
    var whiteToMoveCount = 0;
    var blackToMoveCount = 0;
    var minRating = 1 << 30;
    var maxRating = -1;
    var lineNumber = 0;
    var reachedLimit = false;
    final batch = <PuzzleEntity>[];

    void flushBatch() {
      if (batch.isEmpty) {
        return;
      }
      puzzleBox.putMany(batch);
      batch.clear();
    }

    try {
      process = await Process.start(
        options.zstdExecutable,
        <String>['-dc', '--', inputFile.path],
        runInShell: false,
      );
      final stderrFuture = process.stderr
          .transform(utf8.decoder)
          .join();

      await for (final line in process.stdout
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())) {
        lineNumber++;

        if (lineNumber == 1) {
          final header = parseCsvLine(line);
          if (!_sameStrings(header, LichessPuzzleRow.expectedHeader)) {
            throw FormatException(
              'CSV-Header stimmt nicht:\n'
              'Erhalten: ${header.join(',')}\n'
              'Erwartet: ${LichessPuzzleRow.expectedHeader.join(',')}',
            );
          }
          continue;
        }

        if (options.limit != null &&
            puzzleCount >= options.limit!) {
          reachedLimit = true;
          process.kill();
          break;
        }

        try {
          final fields = parseCsvLine(line);
          final row = LichessPuzzleRow.fromFields(fields);
          final transformed = row.transform(
            ratingBucketSize: options.ratingBucketSize,
            randomSeed: options.randomSeed,
          );
          final entity = transformed.entity;

          batch.add(entity);
          puzzleCount++;
          unknownThemeCount += transformed.unknownThemes.length;

          if (entity.playerColor == PuzzleCatalogConstants.white) {
            whiteToMoveCount++;
          } else {
            blackToMoveCount++;
          }

          if (entity.rating < minRating) {
            minRating = entity.rating;
          }
          if (entity.rating > maxRating) {
            maxRating = entity.rating;
          }

          if (batch.length >= options.batchSize) {
            flushBatch();
          }

          if (puzzleCount % 100000 == 0) {
            stdout.writeln(
              '  $puzzleCount Puzzles importiert '
              '($rejectedRowCount verworfen)',
            );
          }
        } on Object catch (error) {
          rejectedRowCount++;
          final puzzleId = _safePuzzleId(line);
          errorSink.writeln(
            '$lineNumber\t$puzzleId\t${_singleLine(error.toString())}',
          );

          if (options.strict) {
            rethrow;
          }
        }
      }

      flushBatch();
      final exitCode = await process.exitCode;
      final zstdError = await stderrFuture;
      if (!reachedLimit && exitCode != 0) {
        throw ProcessException(
          options.zstdExecutable,
          <String>['-dc', '--', inputFile.path],
          zstdError,
          exitCode,
        );
      }

      if (puzzleCount == 0) {
        throw StateError('Es wurde kein gültiges Puzzle importiert');
      }

      final actualCount = puzzleBox.count();
      if (actualCount != puzzleCount) {
        throw StateError(
          'ObjectBox-Anzahl stimmt nicht: '
          '$actualCount statt $puzzleCount',
        );
      }

      metaBox.put(
        CatalogMetaEntity(
          catalogId: catalogId,
          catalogSchemaVersion: PuzzleCatalogConstants.schemaVersion,
          displayName: 'Lichess Puzzles ${options.sourceDate}',
          createdAtUtcMs: createdAt.millisecondsSinceEpoch,
          sourceName: 'Lichess Puzzle Database',
          sourceFile: p.basename(inputFile.path),
          sourceDate: options.sourceDate,
          sourceSha256: sourceSha256,
          catalogModelFingerprint: modelFingerprint,
          puzzleCount: puzzleCount,
          minRating: minRating,
          maxRating: maxRating,
          ratingBucketSize: options.ratingBucketSize,
          themeDictionaryVersion: ThemeDictionaryV1.version,
          themeDictionarySha256: themeDictionarySha256,
        ),
      );
    } catch (_) {
      process?.kill();
      rethrow;
    } finally {
      await errorSink.flush();
      await errorSink.close();
      if (!store.isClosed()) {
        store.close();
      }
    }

    return _ImportStats(
      puzzleCount: puzzleCount,
      rejectedRowCount: rejectedRowCount,
      unknownThemeCount: unknownThemeCount,
      whiteToMoveCount: whiteToMoveCount,
      blackToMoveCount: blackToMoveCount,
      minRating: minRating,
      maxRating: maxRating,
    );
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      final normalizedLeft =
          index == 0 ? left[index].replaceFirst('\uFEFF', '') : left[index];
      if (normalizedLeft != right[index]) {
        return false;
      }
    }
    return true;
  }

  String _safePuzzleId(String line) {
    final comma = line.indexOf(',');
    if (comma <= 0) {
      return '';
    }
    return line.substring(0, comma).replaceAll('\t', ' ');
  }

  String _singleLine(String value) {
    return value.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
  }
}

class _ImportStats {
  const _ImportStats({
    required this.puzzleCount,
    required this.rejectedRowCount,
    required this.unknownThemeCount,
    required this.whiteToMoveCount,
    required this.blackToMoveCount,
    required this.minRating,
    required this.maxRating,
  });

  final int puzzleCount;
  final int rejectedRowCount;
  final int unknownThemeCount;
  final int whiteToMoveCount;
  final int blackToMoveCount;
  final int minRating;
  final int maxRating;
}
