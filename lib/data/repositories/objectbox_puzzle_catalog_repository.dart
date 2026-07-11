import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:objectbox/objectbox.dart';
import 'package:puzzle_catalog_store/objectbox.g.dart' as catalog_obx;
import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';

import '../../domain/puzzle_range.dart';
import '../../domain/puzzle_record.dart';
import '../../domain/puzzle_selection.dart';
import '../stores/puzzle_catalog_store_manager.dart';
import 'puzzle_catalog_repository.dart';

/// Read-only repository for the large puzzle catalog.
///
/// Performance notes:
/// - Random selection is intentionally based on an exact indexed rating.
/// - Matching ObjectBox IDs are cached per rating/filter combination.
/// - No query orders the complete catalog by [PuzzleEntity.randomKey].
/// - Entity reads use ObjectBox's worker-isolate APIs.
///
/// This keeps the existing catalog format compatible while avoiding the large
/// range scans that are especially costly on Android storage.
class ObjectBoxPuzzleCatalogRepository implements PuzzleCatalogRepository {
  ObjectBoxPuzzleCatalogRepository({
    required this.storeManager,
    Random? random,
    int maxCachedRatingQueries = 384,
  }) : _random = random ?? Random(),
       _maxCachedRatingQueries = maxCachedRatingQueries;

  final PuzzleCatalogStoreManager storeManager;
  final Random _random;
  final int _maxCachedRatingQueries;

  final LinkedHashMap<_CandidateCacheKey, List<int>> _candidateIdCache =
      LinkedHashMap<_CandidateCacheKey, List<int>>();

  int? _lastAscendingRating;
  int? _lastAscendingId;
  PuzzleRange? _lastAscendingRange;
  Future<void> _ascendingBarrier = Future<void>.value();
  int _ascendingEpoch = 0;

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
    _ascendingEpoch++;
    _lastAscendingRating = null;
    _lastAscendingId = null;
    _lastAscendingRange = null;

    // Deliberately keep the rating-ID cache. It is tied to this repository and
    // therefore to one open catalog. Keeping it makes mode resets and repeated
    // Storm/Streak starts effectively warm operations.
  }

  @override
  void clearCaches() {
    resetCursors();
    _candidateIdCache.clear();
  }

  Future<PuzzleEntity?> _findRandom(PuzzleSelection selection) async {
    final strictResult = await _findRandomWithFilters(
      selection,
      nearRadiusLimit: 12,
      randomSampleLimit: 4,
      exhaustiveSmallRanges: false,
    );
    if (strictResult != null) {
      return strictResult;
    }

    final withoutPopularity = selection.copyWith(
      clearMinPopularity: true,
      clearMinPlays: true,
    );
    if (selection.minPopularity != null || selection.minPlays != null) {
      final result = await _findRandomWithFilters(
        withoutPopularity,
        nearRadiusLimit: 24,
        randomSampleLimit: 8,
        exhaustiveSmallRanges: false,
      );
      if (result != null) {
        return result;
      }
    }

    final broadSelection = selection.copyWith(
      clearMinPopularity: true,
      clearMinPlays: true,
      clearMaxRatingDeviation: true,
    );
    return _findRandomWithFilters(
      broadSelection,
      nearRadiusLimit: 96,
      randomSampleLimit: 32,
      exhaustiveSmallRanges: true,
    );
  }

  Future<PuzzleEntity?> _findRandomWithFilters(
    PuzzleSelection selection, {
    required int nearRadiusLimit,
    required int randomSampleLimit,
    required bool exhaustiveSmallRanges,
  }) async {
    for (final rating in _ratingCandidates(
      selection,
      nearRadiusLimit: nearRadiusLimit,
      randomSampleLimit: randomSampleLimit,
      exhaustiveSmallRanges: exhaustiveSmallRanges,
    )) {
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

  /// Produces a bounded, target-first rating search.
  ///
  /// Strict quality filters only inspect a small neighborhood. If that misses,
  /// the caller relaxes filters before doing a broader pass. This prevents a
  /// rare exact rating from triggering hundreds of expensive negative queries.
  Iterable<int> _ratingCandidates(
    PuzzleSelection selection, {
    required int nearRadiusLimit,
    required int randomSampleLimit,
    required bool exhaustiveSmallRanges,
  }) sync* {
    final minRating = selection.minRating;
    final maxRating = selection.maxRating;
    final span = maxRating - minRating + 1;
    final target =
        (selection.targetRating ??
                (minRating + _random.nextInt(maxRating - minRating + 1)))
            .clamp(minRating, maxRating)
            .toInt();
    final yielded = <int>{};

    bool add(int value) {
      return value >= minRating && value <= maxRating && yielded.add(value);
    }

    if (add(target)) {
      yield target;
    }

    final nearRadius = min(nearRadiusLimit, max(0, span - 1));
    for (var offset = 1; offset <= nearRadius; offset++) {
      if (_random.nextBool()) {
        if (add(target + offset)) yield target + offset;
        if (add(target - offset)) yield target - offset;
      } else {
        if (add(target - offset)) yield target - offset;
        if (add(target + offset)) yield target + offset;
      }
    }

    final randomSamples = min(randomSampleLimit, span);
    for (var index = 0; index < randomSamples; index++) {
      final rating = minRating + _random.nextInt(span);
      if (add(rating)) {
        yield rating;
      }
    }

    if (exhaustiveSmallRanges && span <= 320) {
      for (var rating = minRating; rating <= maxRating; rating++) {
        if (add(rating)) {
          yield rating;
        }
      }
      return;
    }

    if (!exhaustiveSmallRanges || span <= 320) {
      return;
    }

    const coarseSamples = 64;
    for (var index = 0; index < coarseSamples; index++) {
      final fraction = (index + 0.5) / coarseSamples;
      final rating = minRating + ((span - 1) * fraction).round();
      if (add(rating)) {
        yield rating;
      }
    }
  }

  Future<PuzzleEntity?> _findAtExactRating({
    required PuzzleSelection selection,
    required int rating,
  }) async {
    final ids = await _candidateIdsForRating(
      selection: selection,
      rating: rating,
    );
    if (ids.isEmpty) {
      return null;
    }

    final excluded = selection.excludePuzzleIds;
    final start = _random.nextInt(ids.length);

    // Usually the first ID is usable. The circular walk only matters when a
    // run has already consumed some puzzles from the cached rating list.
    for (var offset = 0; offset < ids.length; offset++) {
      final id = ids[(start + offset) % ids.length];
      final entity = await storeManager.puzzleBox.getAsync(id);
      if (entity != null && !excluded.contains(entity.lichessPuzzleId)) {
        return entity;
      }
    }

    return null;
  }

  Future<List<int>> _candidateIdsForRating({
    required PuzzleSelection selection,
    required int rating,
  }) async {
    final key = _CandidateCacheKey(
      rating: rating,
      maxRatingDeviation: selection.maxRatingDeviation,
      minPopularity: selection.minPopularity,
      minPlays: selection.minPlays,
      playerColor: selection.playerColor,
    );

    final cached = _candidateIdCache.remove(key);
    if (cached != null) {
      // Reinsert to maintain least-recently-used order.
      _candidateIdCache[key] = cached;
      return cached;
    }

    final query = storeManager.puzzleBox
        .query(_conditionForSelection(selection, rating))
        .build();

    try {
      final ids = await query.findIdsAsync();
      ids.sort();
      final immutable = List<int>.unmodifiable(ids);
      _cacheCandidateIds(key, immutable);
      return immutable;
    } finally {
      query.close();
    }
  }

  void _cacheCandidateIds(_CandidateCacheKey key, List<int> ids) {
    if (_maxCachedRatingQueries <= 0) {
      return;
    }

    _candidateIdCache[key] = ids;
    while (_candidateIdCache.length > _maxCachedRatingQueries) {
      _candidateIdCache.remove(_candidateIdCache.keys.first);
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

  Future<PuzzleEntity?> _findAscending(PuzzleRange range) {
    final completer = Completer<PuzzleEntity?>();
    final epoch = _ascendingEpoch;
    _ascendingBarrier = _ascendingBarrier.then((_) async {
      try {
        completer.complete(await _findAscendingUnlocked(range, epoch));
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<PuzzleEntity?> _findAscendingUnlocked(
    PuzzleRange range,
    int epoch,
  ) async {
    if (epoch != _ascendingEpoch) {
      return null;
    }
    if (_lastAscendingRange != range) {
      _lastAscendingRange = range;
      _lastAscendingRating = null;
      _lastAscendingId = null;
    }

    var rating = _lastAscendingRating ?? range.minRating;
    var afterId = _lastAscendingId ?? 0;

    while (rating <= range.maxRating) {
      if (epoch != _ascendingEpoch) {
        return null;
      }
      final ids = await _candidateIdsForRating(
        selection: PuzzleSelection(
          minRating: rating,
          maxRating: rating,
          random: false,
        ),
        rating: rating,
      );

      final index = _firstIndexGreaterThan(ids, afterId);
      if (index < ids.length) {
        final id = ids[index];
        final entity = await storeManager.puzzleBox.getAsync(id);
        if (epoch != _ascendingEpoch) {
          return null;
        }
        if (entity != null) {
          _lastAscendingRating = rating;
          _lastAscendingId = id;
          return entity;
        }
      }

      rating++;
      afterId = 0;
    }

    _lastAscendingRating = null;
    _lastAscendingId = null;

    if (range.minRating > range.maxRating) {
      return null;
    }

    // Wrap once to the first available exact rating in the configured range.
    for (
      var wrapRating = range.minRating;
      wrapRating <= range.maxRating;
      wrapRating++
    ) {
      if (epoch != _ascendingEpoch) {
        return null;
      }
      final ids = await _candidateIdsForRating(
        selection: PuzzleSelection(
          minRating: wrapRating,
          maxRating: wrapRating,
          random: false,
        ),
        rating: wrapRating,
      );
      if (ids.isEmpty) {
        continue;
      }

      final entity = await storeManager.puzzleBox.getAsync(ids.first);
      if (epoch != _ascendingEpoch) {
        return null;
      }
      if (entity != null) {
        _lastAscendingRating = wrapRating;
        _lastAscendingId = entity.id;
        return entity;
      }
    }
    return null;
  }

  int _firstIndexGreaterThan(List<int> sortedIds, int value) {
    var low = 0;
    var high = sortedIds.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (sortedIds[middle] <= value) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
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

class _CandidateCacheKey {
  const _CandidateCacheKey({
    required this.rating,
    required this.maxRatingDeviation,
    required this.minPopularity,
    required this.minPlays,
    required this.playerColor,
  });

  final int rating;
  final int? maxRatingDeviation;
  final int? minPopularity;
  final int? minPlays;
  final int? playerColor;

  @override
  bool operator ==(Object other) {
    return other is _CandidateCacheKey &&
        other.rating == rating &&
        other.maxRatingDeviation == maxRatingDeviation &&
        other.minPopularity == minPopularity &&
        other.minPlays == minPlays &&
        other.playerColor == playerColor;
  }

  @override
  int get hashCode => Object.hash(
    rating,
    maxRatingDeviation,
    minPopularity,
    minPlays,
    playerColor,
  );
}
