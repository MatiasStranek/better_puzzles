import 'dart:math';

import 'package:puzzle_catalog_store/objectbox.g.dart' as catalog_obx;
import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';

import '../../domain/puzzle_range.dart';
import '../../domain/puzzle_record.dart';
import '../stores/puzzle_catalog_store_manager.dart';
import 'puzzle_catalog_repository.dart';

class ObjectBoxPuzzleCatalogRepository implements PuzzleCatalogRepository {
  ObjectBoxPuzzleCatalogRepository({
    required PuzzleCatalogStoreManager storeManager,
    Random? random,
  }) : _storeManager = storeManager,
       _random = random ?? Random();

  final PuzzleCatalogStoreManager _storeManager;
  final Random _random;

  int? _lastAscendingRating;
  int? _lastAscendingId;

  @override
  Future<PuzzleRecord?> nextPuzzle({
    required PuzzleRange range,
    required bool random,
  }) async {
    if (!_storeManager.isOpen) {
      return null;
    }

    final entity = random ? _findRandom(range) : _findAscending(range);

    return entity == null ? null : _toRecord(entity);
  }

  PuzzleEntity? _findRandom(PuzzleRange range) {
    final pivot = _nextPositive63BitInt();
    final base = catalog_obx.PuzzleEntity_.rating.between(
      range.minRating,
      range.maxRating,
    );

    var query = _storeManager.puzzleBox
        .query(base & catalog_obx.PuzzleEntity_.randomKey.greaterThan(pivot))
        .order(catalog_obx.PuzzleEntity_.randomKey)
        .build();

    try {
      final result = query.findFirst();
      if (result != null) {
        return result;
      }
    } finally {
      query.close();
    }

    query = _storeManager.puzzleBox
        .query(
          base &
              (catalog_obx.PuzzleEntity_.randomKey.lessThan(pivot) |
                  catalog_obx.PuzzleEntity_.randomKey.equals(pivot)),
        )
        .order(catalog_obx.PuzzleEntity_.randomKey)
        .build();

    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  PuzzleEntity? _findAscending(PuzzleRange range) {
    final base = catalog_obx.PuzzleEntity_.rating.between(
      range.minRating,
      range.maxRating,
    );

    final lastRating = _lastAscendingRating;
    final lastId = _lastAscendingId;

    final condition = lastRating == null || lastId == null
        ? base
        : base &
              (catalog_obx.PuzzleEntity_.rating.greaterThan(lastRating) |
                  (catalog_obx.PuzzleEntity_.rating.equals(lastRating) &
                      catalog_obx.PuzzleEntity_.id.greaterThan(lastId)));

    var query = _storeManager.puzzleBox
        .query(condition)
        .order(catalog_obx.PuzzleEntity_.rating)
        .order(catalog_obx.PuzzleEntity_.id)
        .build();

    PuzzleEntity? result;
    try {
      result = query.findFirst();
    } finally {
      query.close();
    }

    if (result == null && lastRating != null) {
      _lastAscendingRating = null;
      _lastAscendingId = null;
      query = _storeManager.puzzleBox
          .query(base)
          .order(catalog_obx.PuzzleEntity_.rating)
          .order(catalog_obx.PuzzleEntity_.id)
          .build();
      try {
        result = query.findFirst();
      } finally {
        query.close();
      }
    }

    if (result != null) {
      _lastAscendingRating = result.rating;
      _lastAscendingId = result.id;
    }
    return result;
  }

  int _nextPositive63BitInt() {
    final high = _random.nextInt(1 << 21);
    final middle = _random.nextInt(1 << 21);
    final low = _random.nextInt(1 << 21);
    return (high << 42) | (middle << 21) | low;
  }

  PuzzleRecord _toRecord(PuzzleEntity entity) {
    return PuzzleRecord(
      lichessPuzzleId: entity.lichessPuzzleId,
      puzzleFen: entity.puzzleFen,
      setupMoveUci: entity.setupMoveUci,
      solutionMovesUci: entity.solutionMovesUci,
      rating: entity.rating,
      themes: entity.themes,
      playerColor: entity.playerColor,
    );
  }
}
