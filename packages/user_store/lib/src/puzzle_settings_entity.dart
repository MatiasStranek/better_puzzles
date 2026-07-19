import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleSettingsEntity {
  PuzzleSettingsEntity({
    this.id = singletonId,
    this.minRating = 600,
    this.maxRating = 1600,
    this.tasksMinRating = 600,
    this.tasksMaxRating = 1600,
    this.streakMinRating = 400,
    this.streakMaxRating = 2799,
    this.stormMinRating = 400,
    this.stormMaxRating = 2499,
    this.tasksCustomRange = false,
    this.streakCustomRange = false,
    this.stormCustomRange = false,
    this.ignoreSolvedPuzzles = false,
    this.randomMode = false,
    this.selectedMode = 'tasks',
    this.ratedTasks = true,
    this.puzzleDifficulty = 'normal',
    this.puzzleRating = 1500,
    this.puzzleDeviation = 500,
    this.puzzleVolatility = 0.09,
    this.puzzleRatingGames = 0,
    this.puzzleRatingUpdatedAtMs = 0,
    this.streakBest = 0,
    this.stormBest = 0,
    this.stormBestCombo = 0,
  });

  static const int singletonId = 1;

  @Id(assignable: true)
  int id;

  int minRating;
  int maxRating;
  int tasksMinRating;
  int tasksMaxRating;
  int streakMinRating;
  int streakMaxRating;
  int stormMinRating;
  int stormMaxRating;
  bool tasksCustomRange;
  bool streakCustomRange;
  bool stormCustomRange;
  bool ignoreSolvedPuzzles;
  bool randomMode;
  String selectedMode;

  bool ratedTasks;
  String puzzleDifficulty;
  double puzzleRating;
  double puzzleDeviation;
  double puzzleVolatility;
  int puzzleRatingGames;
  int puzzleRatingUpdatedAtMs;
  int streakBest;
  int stormBest;
  int stormBestCombo;
}
