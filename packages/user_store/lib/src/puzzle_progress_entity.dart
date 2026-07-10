import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleProgressEntity {
  PuzzleProgressEntity({
    this.id = 0,
    required this.lichessPuzzleId,
    this.solved = false,
    this.failed = false,
    this.attempts = 0,
    this.solvedCount = 0,
    this.failedCount = 0,
    this.bestTimeMs = 0,
    this.firstSolvedAtMs = 0,
    this.lastPlayedAtMs = 0,
  });

  @Id()
  int id;

  /// Stable cross-catalog reference. There is intentionally no ObjectBox
  /// relation to PuzzleEntity because catalogs are replaceable.
  @Unique()
  String lichessPuzzleId;

  bool solved;
  bool failed;
  int attempts;
  int solvedCount;
  int failedCount;
  int bestTimeMs;
  int firstSolvedAtMs;
  int lastPlayedAtMs;
}
