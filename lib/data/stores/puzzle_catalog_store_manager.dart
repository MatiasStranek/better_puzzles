import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:puzzle_catalog_store/objectbox.g.dart' as catalog_obx;
import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';

class CatalogStoreValidation {
  const CatalogStoreValidation({
    required this.catalogId,
    required this.puzzleCount,
    required this.minRating,
    required this.maxRating,
  });

  final String catalogId;
  final int puzzleCount;
  final int minRating;
  final int maxRating;
}

class PuzzleCatalogStoreManager {
  Store? _store;
  String? _catalogId;

  Store? get storeOrNull => _store;
  bool get isOpen => _store != null && !_store!.isClosed();
  String? get catalogId => _catalogId;

  Store get store {
    final value = _store;
    if (value == null || value.isClosed()) {
      throw StateError('PuzzleCatalogStore ist nicht geöffnet');
    }
    return value;
  }

  Box<PuzzleEntity> get puzzleBox => store.box<PuzzleEntity>();
  Box<CatalogMetaEntity> get metaBox => store.box<CatalogMetaEntity>();

  Future<void> open({
    required Directory objectBoxDirectory,
    required String catalogId,
    required int maxDbSizeKb,
  }) async {
    await close();
    await objectBoxDirectory.create(recursive: true);

    _store = catalog_obx.openStore(
      directory: objectBoxDirectory.path,
      maxDBSizeInKB: maxDbSizeKb,
    );
    _catalogId = catalogId;
  }

  Future<CatalogStoreValidation> validateCandidate({
    required Directory objectBoxDirectory,
    required String expectedCatalogId,
    required String expectedModelFingerprint,
    required int expectedPuzzleCount,
    required int maxDbSizeKb,
  }) async {
    final candidate = catalog_obx.openStore(
      directory: objectBoxDirectory.path,
      maxDBSizeInKB: maxDbSizeKb,
    );

    try {
      final meta = candidate
          .box<CatalogMetaEntity>()
          .get(CatalogMetaEntity.singletonId);
      if (meta == null) {
        throw StateError('CatalogMetaEntity fehlt');
      }
      if (meta.catalogId != expectedCatalogId) {
        throw StateError(
          'catalogId in ObjectBox stimmt nicht: ${meta.catalogId}',
        );
      }
      if (meta.catalogModelFingerprint != expectedModelFingerprint) {
        throw StateError(
          'ObjectBox-Modellfingerprint stimmt nicht',
        );
      }

      final count = candidate.box<PuzzleEntity>().count();
      if (count != expectedPuzzleCount ||
          meta.puzzleCount != expectedPuzzleCount) {
        throw StateError(
          'Puzzle-Anzahl stimmt nicht: DB=$count, '
          'Meta=${meta.puzzleCount}, Manifest=$expectedPuzzleCount',
        );
      }

      return CatalogStoreValidation(
        catalogId: meta.catalogId,
        puzzleCount: count,
        minRating: meta.minRating,
        maxRating: meta.maxRating,
      );
    } finally {
      candidate.close();
    }
  }

  Future<void> close() async {
    final value = _store;
    _store = null;
    _catalogId = null;

    if (value != null && !value.isClosed()) {
      value.close();
    }
  }
}
