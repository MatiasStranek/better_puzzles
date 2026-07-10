import 'dart:io';

import 'package:bpuzzles_format/bpuzzles_format.dart';
import 'package:test/test.dart';

void main() {
  test('writes, inspects and extracts a package', () async {
    final temp = await Directory.systemTemp.createTemp('bpuzzles-format-');
    addTearDown(() => temp.delete(recursive: true));

    final database = File('${temp.path}/data.mdb');
    await database.writeAsBytes(
      List<int>.generate(4096, (index) => index % 251),
    );
    final hash = await sha256File(database);

    final manifest = BPuzzlesManifest(
      format: BPuzzlesManifest.supportedFormat,
      formatVersion: BPuzzlesManifest.supportedFormatVersion,
      catalogSchemaVersion: BPuzzlesManifest.supportedCatalogSchemaVersion,
      catalogId: 'test-catalog-1',
      displayName: 'Test Catalog',
      createdAtUtc: DateTime.utc(2026, 1, 1).toIso8601String(),
      source: const BPuzzlesSourceInfo(
        name: 'Test',
        sourceFile: 'test.csv.zst',
        sourceDate: '2026-01-01',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        license: 'CC0',
      ),
      generator: const BPuzzlesGeneratorInfo(
        name: 'test',
        version: '1',
        objectBoxVersion: '5.3.2',
        command: 'test',
      ),
      database: BPuzzlesDatabaseInfo(
        engine: 'objectbox',
        entry: 'objectbox/data.mdb',
        catalogModelFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        sha256: hash,
        sizeBytes: await database.length(),
        requiredMaxDbSizeKb: 1024,
      ),
      statistics: const BPuzzlesStatistics(
        puzzleCount: 1,
        minRating: 1000,
        maxRating: 1000,
        whiteToMoveCount: 1,
        blackToMoveCount: 0,
        rejectedRowCount: 0,
        unknownThemeCount: 0,
      ),
      ratingBuckets: const BPuzzlesRatingBuckets(
        size: 50,
        minBucket: 1000,
        maxBucket: 1000,
      ),
      themes: const BPuzzlesThemeInfo(
        dictionaryVersion: 1,
        dictionarySha256:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        maskBits: 126,
        dictionary: <String>['fork'],
      ),
    );

    expect(manifest.validate(), isEmpty);

    final package = File('${temp.path}/test.bpuzzles');
    await const BPuzzlesPackageWriter().write(
      databaseFile: database,
      outputFile: package,
      manifest: manifest,
    );

    final header = await const BPuzzlesPackageReader().inspect(package);
    expect(header.manifest.catalogId, 'test-catalog-1');

    final extracted = File('${temp.path}/out/data.mdb');
    await const BPuzzlesPackageReader().extractDatabase(
      packageFile: package,
      header: header,
      targetFile: extracted,
    );
    expect(await sha256File(extracted), hash);
  });
}
