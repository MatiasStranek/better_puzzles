import 'dart:math';

import 'package:objectbox/objectbox.dart';
import 'package:puzzle_catalog_store/objectbox.g.dart' as catalog_obx;
import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';

import '../../domain/puzzle_range.dart';
import '../../domain/puzzle_record.dart';
import '../../domain/puzzle_selection.dart';
import '../stores/puzzle_catalog_store_manager.dart';
import 'puzzle_catalog_repository.dart';

class ObjectBoxPuzzleCatalogRepository implements PuzzleCatalogRepository {
  ObjectBoxPuzzleCatalogRepository({required this.storeManager, Random? random})
    : _random = random ?? Random();

  final PuzzleCatalogStoreManager storeManager;
  final Random _random;

  int? _lastAscendingRating;
  int? _lastAscendingId;
  PuzzleRange? _lastAscendingRange;

  @override
  Future<PuzzleRecord?> nextPuzzle({
    required PuzzleRange range,
    required bool random,
  }) async {
    if (!storeManager.isOpen) {
      return null;
    }

    final entity = random
        ? await _findRandom(
            PuzzleSelection(
              minRating: range.minRating,
              maxRating: range.maxRating,
              random: true,
            ),
          )
        : await _findAscending(range);

    return entity == null ? null : _toRecord(entity);
  }

  @override
  Future<PuzzleRecord?> selectPuzzle(PuzzleSelection selection) async {
    if (!storeManager.isOpen) {
      return null;
    }

    final entity = selection.random || selection.targetRating != null
        ? await _findRandom(selection)
        : await _findAscending(
            PuzzleRange(
              minRating: selection.minRating,
              maxRating: selection.maxRating,
            ),
          );

    return entity == null ? null : _toRecord(entity);
  }

  @override
  void resetCursors() {
    _lastAscendingRating = null;
    _lastAscendingId = null;
    _lastAscendingRange = null;
  }

  Future<PuzzleEntity?> _findRandom(PuzzleSelection selection) async {
    final attempts = <PuzzleSelection>[
      selection,
      if (selection.minPopularity != null || selection.minPlays != null)
        selection.copyWith(clearMinPopularity: true, clearMinPlays: true),
      if (selection.maxRatingDeviation != null)
        selection.copyWith(
          clearMinPopularity: true,
          clearMinPlays: true,
          clearMaxRatingDeviation: true,
        ),
    ];

    for (final attempt in attempts) {
      final result = await _findRandomWithFilters(attempt);
      if (result != null) {
        return result;
      }
    }

    return null;
  }

  Future<PuzzleEntity?> _findRandomWithFilters(
    PuzzleSelection selection,
  ) async {
    final candidates = _ratingCandidates(selection);

    for (final rating in candidates) {
      final result = await _findAtExactRating(
        selection: selection,
        rating: rating,
      );
      if (result != null) {
        return result;
      }
    }

    return null;
  }

  Iterable<int> _ratingCandidates(PuzzleSelection selection) sync* {
    final min = selection.minRating;
    final max = selection.maxRating;
    final target =
        (selection.targetRating ?? (min + _random.nextInt(max - min + 1)))
            .clamp(min, max)
            .toInt();
    final yielded = <int>{};

    void addCandidate(int value, List<int> output) {
      if (value >= min && value <= max && yielded.add(value)) {
        output.add(value);
      }
    }

    final firstWave = <int>[];
    addCandidate(target, firstWave);
    for (var offset = 1; offset <= 40; offset++) {
      if (_random.nextBool()) {
        addCandidate(target + offset, firstWave);
        addCandidate(target - offset, firstWave);
      } else {
        addCandidate(target - offset, firstWave);
        addCandidate(target + offset, firstWave);
      }
    }
    yield* firstWave;

    final randomWave = <int>[];
    for (var index = 0; index < 32; index++) {
      addCandidate(min + _random.nextInt(max - min + 1), randomWave);
    }
    yield* randomWave;

    for (var rating = min; rating <= max; rating++) {
      if (yielded.add(rating)) {
        yield rating;
      }
    }
  }

  Future<PuzzleEntity?> _findAtExactRating({
    required PuzzleSelection selection,
    required int rating,
  }) async {
    final pivot = _nextPositive63BitInt();
    final afterPivot =
        _conditionForSelection(selection, rating) &
        catalog_obx.PuzzleEntity_.randomKey.greaterThan(pivot);

    var query = storeManager.puzzleBox
        .query(afterPivot)
        .order(catalog_obx.PuzzleEntity_.randomKey)
        .build();
    query.limit = 12;

    try {
      final values = await query.findAsync();
      final result = _firstNotExcluded(values, selection.excludePuzzleIds);
      if (result != null) {
        return result;
      }
    } finally {
      query.close();
    }

    final beforePivot =
        _conditionForSelection(selection, rating) &
        catalog_obx.PuzzleEntity_.randomKey.lessThan(pivot + 1);
    query = storeManager.puzzleBox
        .query(beforePivot)
        .order(catalog_obx.PuzzleEntity_.randomKey)
        .build();
    query.limit = 12;

    try {
      final values = await query.findAsync();
      return _firstNotExcluded(values, selection.excludePuzzleIds);
    } finally {
      query.close();
    }
  }

  Condition<PuzzleEntity> _conditionForSelection(
    PuzzleSelection selection,
    int rating,
  ) {
    Condition<PuzzleEntity> condition = catalog_obx.PuzzleEntity_.rating.equals(
      rating,
    );

    final maxDeviation = selection.maxRatingDeviation;
    if (maxDeviation != null) {
      condition =
          condition &
          catalog_obx.PuzzleEntity_.ratingDeviation.lessThan(maxDeviation + 1);
    }

    final minPopularity = selection.minPopularity;
    if (minPopularity != null) {
      condition =
          condition &
          catalog_obx.PuzzleEntity_.popularity.greaterThan(minPopularity - 1);
    }

    final minPlays = selection.minPlays;
    if (minPlays != null) {
      condition =
          condition &
          catalog_obx.PuzzleEntity_.nbPlays.greaterThan(minPlays - 1);
    }

    final playerColor = selection.playerColor;
    if (playerColor != null) {
      condition =
          condition & catalog_obx.PuzzleEntity_.playerColor.equals(playerColor);
    }

    return condition;
  }

  PuzzleEntity? _firstNotExcluded(
    List<PuzzleEntity> values,
    Set<String> excluded,
  ) {
    for (final value in values) {
      if (!excluded.contains(value.lichessPuzzleId)) {
        return value;
      }
    }
    return null;
  }

  Future<PuzzleEntity?> _findAscending(PuzzleRange range) async {
    if (_lastAscendingRange != range) {
      _lastAscendingRange = range;
      _lastAscendingRating = null;
      _lastAscendingId = null;
    }

    var rating = _lastAscendingRating ?? range.minRating;
    var afterId = _lastAscendingId ?? 0;

    while (rating <= range.maxRating) {
      var condition = catalog_obx.PuzzleEntity_.rating.equals(rating);
      if (afterId > 0) {
        condition =
            condition & catalog_obx.PuzzleEntity_.id.greaterThan(afterId);
      }

      final query = storeManager.puzzleBox
          .query(condition)
          .order(catalog_obx.PuzzleEntity_.id)
          .build();

      try {
        final result = await query.findFirstAsync();
        if (result != null) {
          _lastAscendingRating = rating;
          _lastAscendingId = result.id;
          return result;
        }
      } finally {
        query.close();
      }

      rating++;
      afterId = 0;
    }

    _lastAscendingRating = null;
    _lastAscendingId = null;

    if (range.minRating > range.maxRating) {
      return null;
    }

    final query = storeManager.puzzleBox
        .query(catalog_obx.PuzzleEntity_.rating.equals(range.minRating))
        .order(catalog_obx.PuzzleEntity_.id)
        .build();
    try {
      final result = await query.findFirstAsync();
      if (result != null) {
        _lastAscendingRating = range.minRating;
        _lastAscendingId = result.id;
      }
      return result;
    } finally {
      query.close();
    }
  }

  int _nextPositive63BitInt() {
    final high = _random.nextInt(1 << 21);
    final middle = _random.nextInt(1 << 21);
    final low = _random.nextInt(1 << 21);
    final value = (high << 42) | (middle << 21) | low;
    const maxSafePivot = 0x7FFFFFFFFFFFFFFE;
    return value > maxSafePivot ? maxSafePivot : value;
  }

  PuzzleRecord _toRecord(PuzzleEntity entity) {
    return PuzzleRecord(
      lichessPuzzleId: entity.lichessPuzzleId,
      puzzleFen: entity.puzzleFen,
      setupMoveUci: entity.setupMoveUci,
      solutionMovesUci: entity.solutionMovesUci,
      rating: entity.rating,
      ratingDeviation: entity.ratingDeviation,
      popularity: entity.popularity,
      nbPlays: entity.nbPlays,
      themes: entity.themes,
      playerColor: entity.playerColor,
    );
  }
}
