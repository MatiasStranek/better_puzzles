import 'package:user_store/objectbox.g.dart' as user_obx;
import 'package:user_store/user_store.dart';

import '../../domain/glicko2.dart';
import '../../domain/puzzle_difficulty.dart';
import '../../domain/puzzle_mode.dart';
import '../../domain/puzzle_range.dart';
import '../stores/user_store_manager.dart';

class PuzzleUserRepository {
  PuzzleUserRepository(this._storeManager);

  final UserStoreManager _storeManager;

  PuzzleSettingsSnapshot loadSettings() {
    final entity =
        _storeManager.settingsBox.get(PuzzleSettingsEntity.singletonId) ??
        PuzzleSettingsEntity();

    final hasRatingState =
        entity.puzzleRating > 0 &&
        entity.puzzleDeviation > 0 &&
        entity.puzzleVolatility > 0;
    final rating = hasRatingState
        ? Glicko2Rating(
            rating: entity.puzzleRating,
            deviation: entity.puzzleDeviation,
            volatility: entity.puzzleVolatility,
            numberOfResults: entity.puzzleRatingGames,
            lastRatingAtMs: entity.puzzleRatingUpdatedAtMs,
          )
        : Glicko2Rating.initial;

    return PuzzleSettingsSnapshot(
      range: PuzzleRange(
        minRating: entity.minRating,
        maxRating: entity.maxRating,
      ),
      tasksRange: PuzzleRange(
        minRating: entity.tasksMinRating,
        maxRating: entity.tasksMaxRating,
      ),
      streakRange: PuzzleRange(
        minRating: entity.streakMinRating,
        maxRating: entity.streakMaxRating,
      ),
      stormRange: PuzzleRange(
        minRating: entity.stormMinRating,
        maxRating: entity.stormMaxRating,
      ),
      tasksCustomRange: entity.tasksCustomRange,
      streakCustomRange: entity.streakCustomRange,
      stormCustomRange: entity.stormCustomRange,
      ignoreSolvedPuzzles: entity.ignoreSolvedPuzzles,
      randomMode: entity.randomMode,
      mode: PuzzleMode.fromStorageName(entity.selectedMode),
      ratedTasks: hasRatingState ? entity.ratedTasks : true,
      difficulty: hasRatingState
          ? PuzzleDifficulty.fromStorageName(entity.puzzleDifficulty)
          : PuzzleDifficulty.normal,
      rating: rating,
      streakBest: entity.streakBest,
      stormBest: entity.stormBest,
      stormBestCombo: entity.stormBestCombo,
    );
  }

  void saveSettings(PuzzleSettingsSnapshot settings) {
    _storeManager.settingsBox.put(
      PuzzleSettingsEntity(
        minRating: settings.range.minRating,
        maxRating: settings.range.maxRating,
        tasksMinRating: settings.tasksRange.minRating,
        tasksMaxRating: settings.tasksRange.maxRating,
        streakMinRating: settings.streakRange.minRating,
        streakMaxRating: settings.streakRange.maxRating,
        stormMinRating: settings.stormRange.minRating,
        stormMaxRating: settings.stormRange.maxRating,
        tasksCustomRange: settings.tasksCustomRange,
        streakCustomRange: settings.streakCustomRange,
        stormCustomRange: settings.stormCustomRange,
        ignoreSolvedPuzzles: settings.ignoreSolvedPuzzles,
        randomMode: settings.randomMode,
        selectedMode: settings.mode.storageName,
        ratedTasks: settings.ratedTasks,
        puzzleDifficulty: settings.difficulty.storageName,
        puzzleRating: settings.rating.rating,
        puzzleDeviation: settings.rating.deviation,
        puzzleVolatility: settings.rating.volatility,
        puzzleRatingGames: settings.rating.numberOfResults,
        puzzleRatingUpdatedAtMs: settings.rating.lastRatingAtMs,
        streakBest: settings.streakBest,
        stormBest: settings.stormBest,
        stormBestCombo: settings.stormBestCombo,
      ),
    );
  }

  int countSolvedPuzzles() {
    final query = _storeManager.progressBox
        .query(user_obx.PuzzleProgressEntity_.solvedCount.greaterThan(0))
        .build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  Set<String> loadSolvedPuzzleIds() {
    final query = _storeManager.progressBox
        .query(user_obx.PuzzleProgressEntity_.solvedCount.greaterThan(0))
        .build();
    try {
      return query
          .property(user_obx.PuzzleProgressEntity_.lichessPuzzleId)
          .find()
          .toSet();
    } finally {
      query.close();
    }
  }

  PuzzleProgressEntity? loadPuzzleProgress(String lichessPuzzleId) {
    final query = _storeManager.progressBox
        .query(
          user_obx.PuzzleProgressEntity_.lichessPuzzleId.equals(
            lichessPuzzleId,
          ),
        )
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  PuzzleResultUpdate recordPuzzleResult({
    required String lichessPuzzleId,
    required bool solved,
    required int elapsedMs,
  }) {
    final query = _storeManager.progressBox
        .query(
          user_obx.PuzzleProgressEntity_.lichessPuzzleId.equals(
            lichessPuzzleId,
          ),
        )
        .build();

    PuzzleProgressEntity? progress;
    try {
      progress = query.findFirst();
    } finally {
      query.close();
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    progress ??= PuzzleProgressEntity(lichessPuzzleId: lichessPuzzleId);
    final wasSolved = progress.solvedCount > 0;
    progress.attempts++;
    progress.lastPlayedAtMs = now;

    if (solved) {
      progress.solved = true;
      progress.solvedCount++;
      if (progress.firstSolvedAtMs == 0) {
        progress.firstSolvedAtMs = now;
      }
      if (elapsedMs > 0 &&
          (progress.bestTimeMs == 0 || elapsedMs < progress.bestTimeMs)) {
        progress.bestTimeMs = elapsedMs;
      }
    } else {
      progress.failed = true;
      progress.failedCount++;
    }

    _storeManager.progressBox.put(progress);
    return PuzzleResultUpdate(
      solvedCount: progress.solvedCount,
      failedCount: progress.failedCount,
      newlySolved: solved && !wasSolved,
    );
  }

  int startRun({
    required String catalogId,
    required PuzzleMode mode,
    required PuzzleRange range,
    required bool randomMode,
    required int ratingBefore,
  }) {
    return _storeManager.runBox.put(
      PuzzleRunEntity(
        catalogId: catalogId,
        mode: mode.storageName,
        startedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        minRating: range.minRating,
        maxRating: range.maxRating,
        randomMode: randomMode,
        ratingBefore: ratingBefore,
      ),
    );
  }

  void finishRun({
    required int runId,
    required int score,
    required int streak,
    required int mistakes,
    required int bestCombo,
    required int highestRating,
    required int durationMs,
    required int ratingAfter,
    required int ratingChange,
    required bool completed,
  }) {
    final run = _storeManager.runBox.get(runId);
    if (run == null) {
      return;
    }

    run
      ..endedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch
      ..score = score
      ..streak = streak
      ..mistakes = mistakes
      ..bestCombo = bestCombo
      ..highestRating = highestRating
      ..durationMs = durationMs
      ..ratingAfter = ratingAfter
      ..ratingChange = ratingChange
      ..completed = completed;

    _storeManager.runBox.put(run);
  }
}

class PuzzleSettingsSnapshot {
  const PuzzleSettingsSnapshot({
    required this.range,
    required this.randomMode,
    required this.tasksRange,
    required this.streakRange,
    required this.stormRange,
    required this.tasksCustomRange,
    required this.streakCustomRange,
    required this.stormCustomRange,
    required this.ignoreSolvedPuzzles,
    required this.mode,
    required this.ratedTasks,
    required this.difficulty,
    required this.rating,
    required this.streakBest,
    required this.stormBest,
    required this.stormBestCombo,
  });

  final PuzzleRange range;
  final bool randomMode;
  final PuzzleRange tasksRange;
  final PuzzleRange streakRange;
  final PuzzleRange stormRange;
  final bool tasksCustomRange;
  final bool streakCustomRange;
  final bool stormCustomRange;
  final bool ignoreSolvedPuzzles;
  final PuzzleMode mode;
  final bool ratedTasks;
  final PuzzleDifficulty difficulty;
  final Glicko2Rating rating;
  final int streakBest;
  final int stormBest;
  final int stormBestCombo;
}

class PuzzleResultUpdate {
  const PuzzleResultUpdate({
    required this.solvedCount,
    required this.failedCount,
    required this.newlySolved,
  });

  final int solvedCount;
  final int failedCount;
  final bool newlySolved;
}
