import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bpuzzles_format/bpuzzles_format.dart';
import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';

import '../storage/puzzle_storage_layout.dart';
import '../stores/puzzle_catalog_store_manager.dart';
import 'puzzle_catalog_import_models.dart';

export 'puzzle_catalog_import_models.dart';

class PuzzleDatabaseImportService {
  const PuzzleDatabaseImportService({this.catalogStoreManager});

  final PuzzleCatalogStoreManager? catalogStoreManager;

  Future<PuzzleStorageLayout> getStorageLayout() {
    return PuzzleStorageLayout.fromApplicationSupport();
  }

  /// Compatibility helper for the existing controller.
  Future<Directory> getAppDatabaseRoot() async {
    final layout = await getStorageLayout();
    return layout.root;
  }

  /// Compatibility helper. New code should use layout.installedCatalogs.
  Future<Directory> getCatalogDirectory() async {
    final layout = await getStorageLayout();
    return layout.catalogsRoot;
  }

  Future<Directory> getUserDataDirectory() async {
    final layout = await getStorageLayout();
    return layout.userRoot;
  }

  Future<PuzzleDatabaseImportResult> prepareEmptyCatalogFolder() async {
    final layout = await getStorageLayout();
    await layout.ensureBaseDirectories();

    return PuzzleDatabaseImportResult(
      targetDirectory: layout.catalogsRoot,
      message: 'Katalog-Ordner vorbereitet: ${layout.catalogsRoot.path}',
    );
  }

  Future<PuzzleCatalogPackageInspection> inspectPackage(
    String packagePath,
  ) async {
    final packageFile = File(packagePath);
    final header = await const BPuzzlesPackageReader().inspect(packageFile);

    final errors = header.manifest.validate(
      expectedModelFingerprint: catalogModelFingerprint,
    );

    if (catalogModelFingerprint == 'UNGENERATED') {
      errors.add(
        'ObjectBox-Modellfingerprint wurde noch nicht erzeugt. '
        'Führe tool/setup_database_patch.ps1 aus.',
      );
    }

    return PuzzleCatalogPackageInspection(
      packageFile: packageFile,
      manifest: header.manifest,
      packageSizeBytes: header.packageLength,
      requiredTemporaryBytes: header.packageLength + header.databaseLength,
      errors: List<String>.unmodifiable(errors),
    );
  }

  Stream<PuzzleCatalogImportEvent> importPackage(
    String packagePath, {
    void Function(PuzzleCatalogImportEvent event)? onProgress,
  }) async* {
    yield const PuzzleCatalogImportEvent(
      phase: PuzzleCatalogImportPhase.inspecting,
      message: 'Paket und Manifest werden geprüft',
    );

    final packageFile = File(packagePath);
    final reader = const BPuzzlesPackageReader();
    final header = await reader.inspect(packageFile);
    var manifest = header.manifest;
    final validationErrors = manifest.validate(
      expectedModelFingerprint: catalogModelFingerprint,
    );

    if (catalogModelFingerprint == 'UNGENERATED') {
      validationErrors.add(
        'ObjectBox-Modellfingerprint fehlt. '
        'Führe tool/setup_database_patch.ps1 aus.',
      );
    }

    if (validationErrors.isNotEmpty) {
      throw FormatException(validationErrors.join('\n'));
    }

    final layout = await getStorageLayout();
    await layout.ensureBaseDirectories();

    final stagingName = _newStagingName(manifest.catalogId);
    final stagingDirectory = Directory(
      '${layout.stagingCatalogs.path}${Platform.pathSeparator}$stagingName',
    );
    final stagingObjectBox = layout.catalogObjectBox(stagingDirectory);
    final stagingDatabase = File(
      '${stagingObjectBox.path}${Platform.pathSeparator}data.mdb',
    );
    final stagedPackage = File(
      '${stagingDirectory.path}${Platform.pathSeparator}import.bpuzzles',
    );

    yield PuzzleCatalogImportEvent(
      phase: PuzzleCatalogImportPhase.preparingStaging,
      message: 'Temporärer Importordner: ${stagingDirectory.path}',
    );

    await stagingDirectory.create(recursive: true);

    try {
      yield const PuzzleCatalogImportEvent(
        phase: PuzzleCatalogImportPhase.copyingPackage,
        message: 'Paket wird in den geschützten App-Importordner kopiert',
        progress: 0,
      );

      await _copyFileStreaming(
        source: packageFile,
        target: stagedPackage,
        onProgress: (copiedBytes, totalBytes) {
          onProgress?.call(
            PuzzleCatalogImportEvent(
              phase: PuzzleCatalogImportPhase.copyingPackage,
              message:
                  'Paket wird kopiert: '
                  '${_formatPercent(copiedBytes, totalBytes)}',
              progress: copiedBytes / totalBytes,
            ),
          );
        },
      );
      final stagedHeader = await reader.inspect(stagedPackage);
      final stagedErrors = stagedHeader.manifest.validate(
        expectedModelFingerprint: catalogModelFingerprint,
      );
      if (stagedErrors.isNotEmpty) {
        throw FormatException(stagedErrors.join('\n'));
      }
      if (stagedHeader.manifest.catalogId != manifest.catalogId) {
        throw const FormatException(
          'Paket wurde während des Kopierens verändert',
        );
      }
      manifest = stagedHeader.manifest;

      yield const PuzzleCatalogImportEvent(
        phase: PuzzleCatalogImportPhase.extracting,
        message: 'ObjectBox-Datenbank wird streamend extrahiert und geprüft',
        progress: 0,
      );

      var lastExtractPercent = -1;
      await reader.extractDatabase(
        packageFile: stagedPackage,
        header: stagedHeader,
        targetFile: stagingDatabase,
        onProgress: (copiedBytes, totalBytes) {
          final percent = _percent(copiedBytes, totalBytes);
          if (percent == lastExtractPercent) {
            return;
          }
          lastExtractPercent = percent;

          onProgress?.call(
            PuzzleCatalogImportEvent(
              phase: PuzzleCatalogImportPhase.extracting,
              message: 'ObjectBox-Datenbank wird extrahiert: $percent %',
              progress: copiedBytes / totalBytes,
            ),
          );
        },
      );

      yield const PuzzleCatalogImportEvent(
        phase: PuzzleCatalogImportPhase.extracting,
        message: 'ObjectBox-Datenbank vollständig extrahiert und gehasht',
        progress: 1,
      );

      await layout
          .catalogManifest(stagingDirectory)
          .writeAsString(
            const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
            flush: true,
          );

      if (await stagedPackage.exists()) {
        await stagedPackage.delete();
      }

      final manager = catalogStoreManager;
      final validator = manager ?? PuzzleCatalogStoreManager();

      yield const PuzzleCatalogImportEvent(
        phase: PuzzleCatalogImportPhase.verifyingObjectBox,
        message: 'ObjectBox-Schema und Katalogmetadaten werden geprüft',
      );

      await validator.validateCandidate(
        objectBoxDirectory: stagingObjectBox,
        expectedCatalogId: manifest.catalogId,
        expectedModelFingerprint: manifest.database.catalogModelFingerprint,
        expectedPuzzleCount: manifest.puzzleCount,
        maxDbSizeKb: manifest.database.requiredMaxDbSizeKb,
      );

      final previousReference = await layout.readActiveCatalog();
      final targetDirectory = layout.installedCatalog(manifest.catalogId);

      if (await targetDirectory.exists()) {
        throw FileSystemException(
          'Ein Katalog mit dieser catalogId ist bereits installiert',
          targetDirectory.path,
        );
      }

      yield const PuzzleCatalogImportEvent(
        phase: PuzzleCatalogImportPhase.activating,
        message: 'Katalog wird atomar aktiviert',
      );

      await manager?.close();
      await stagingDirectory.rename(targetDirectory.path);

      try {
        await layout.writeActiveCatalog(
          ActiveCatalogReference(
            catalogId: manifest.catalogId,
            activatedAtUtc: DateTime.now().toUtc().toIso8601String(),
          ),
        );

        if (manager != null) {
          yield const PuzzleCatalogImportEvent(
            phase: PuzzleCatalogImportPhase.openingCatalog,
            message: 'PuzzleCatalogStore wird geöffnet',
          );

          await manager.open(
            objectBoxDirectory: layout.catalogObjectBox(targetDirectory),
            catalogId: manifest.catalogId,
            maxDbSizeKb: manifest.database.requiredMaxDbSizeKb,
          );
        }
      } catch (_) {
        await _restorePreviousCatalog(
          layout: layout,
          previousReference: previousReference,
          manager: manager,
        );
        if (await targetDirectory.exists()) {
          await targetDirectory.delete(recursive: true);
        }
        rethrow;
      }

      final result = PuzzleDatabaseImportResult(
        targetDirectory: targetDirectory,
        message:
            '${manifest.displayName} importiert: ${manifest.puzzleCount} Puzzles',
        manifest: manifest,
      );

      yield PuzzleCatalogImportEvent(
        phase: PuzzleCatalogImportPhase.completed,
        message: result.message,
        progress: 1,
        result: result,
      );
    } catch (_) {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<BPuzzlesManifest?> openActiveCatalog() async {
    final manager = catalogStoreManager;
    if (manager == null) {
      throw StateError(
        'openActiveCatalog benötigt einen PuzzleCatalogStoreManager',
      );
    }

    final layout = await getStorageLayout();
    await layout.ensureBaseDirectories();
    final reference = await layout.readActiveCatalog();
    if (reference == null) {
      return null;
    }

    final directory = layout.installedCatalog(reference.catalogId);
    final manifestFile = layout.catalogManifest(directory);
    if (!await manifestFile.exists()) {
      throw FileSystemException(
        'Manifest des aktiven Katalogs fehlt',
        manifestFile.path,
      );
    }

    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Manifest ist kein JSON-Objekt');
    }
    final manifest = BPuzzlesManifest.fromJson(
      decoded.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      ),
    );
    final errors = manifest.validate(
      expectedModelFingerprint: catalogModelFingerprint,
    );
    if (errors.isNotEmpty) {
      throw FormatException(errors.join('\n'));
    }

    await manager.open(
      objectBoxDirectory: layout.catalogObjectBox(directory),
      catalogId: manifest.catalogId,
      maxDbSizeKb: manifest.database.requiredMaxDbSizeKb,
    );
    return manifest;
  }

  Future<void> _copyFileStreaming({
    required File source,
    required File target,
    void Function(int copiedBytes, int totalBytes)? onProgress,
  }) async {
    final temporary = File('${target.path}.partial');
    if (await temporary.exists()) {
      await temporary.delete();
    }

    final totalBytes = await source.length();
    var copiedBytes = 0;
    var lastReportedPercent = -1;
    final sink = temporary.openWrite();

    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        copiedBytes += chunk.length;

        final percent = _percent(copiedBytes, totalBytes);
        if (percent != lastReportedPercent) {
          lastReportedPercent = percent;
          onProgress?.call(copiedBytes, totalBytes);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (copiedBytes != totalBytes) {
      await _deleteIfExists(temporary);
      throw FileSystemException(
        'Paket wurde nicht vollständig kopiert',
        source.path,
      );
    }

    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  String _formatPercent(int copiedBytes, int totalBytes) {
    return '${_percent(copiedBytes, totalBytes)} %';
  }

  int _percent(int copiedBytes, int totalBytes) {
    if (totalBytes <= 0) {
      return 0;
    }

    return ((copiedBytes * 100) ~/ totalBytes).clamp(0, 100).toInt();
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _restorePreviousCatalog({
    required PuzzleStorageLayout layout,
    required ActiveCatalogReference? previousReference,
    required PuzzleCatalogStoreManager? manager,
  }) async {
    await manager?.close();

    if (previousReference == null) {
      await layout.clearActiveCatalog();
      return;
    }

    await layout.writeActiveCatalog(previousReference);

    if (manager == null) {
      return;
    }

    final oldDirectory = layout.installedCatalog(previousReference.catalogId);
    final oldManifestFile = layout.catalogManifest(oldDirectory);
    if (!await oldManifestFile.exists()) {
      return;
    }

    final decoded = jsonDecode(await oldManifestFile.readAsString());
    if (decoded is! Map) {
      return;
    }

    final oldManifest = BPuzzlesManifest.fromJson(
      decoded.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      ),
    );

    await manager.open(
      objectBoxDirectory: layout.catalogObjectBox(oldDirectory),
      catalogId: oldManifest.catalogId,
      maxDbSizeKb: oldManifest.database.requiredMaxDbSizeKb,
    );
  }

  String _newStagingName(String catalogId) {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(1 << 32);
    return '$catalogId-$now-${random.toRadixString(16)}';
  }
}
