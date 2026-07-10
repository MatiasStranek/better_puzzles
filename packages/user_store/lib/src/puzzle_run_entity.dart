import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleRunEntity {
  PuzzleRunEntity({
    this.id = 0,
    required this.catalogId,
    required this.mode,
    required this.startedAtMs,
    this.endedAtMs = 0,
    this.score = 0,
    this.streak = 0,
    this.mistakes = 0,
    required this.minRating,
    required this.maxRating,
    required this.randomMode,
  });

  @Id()
  int id;

  @Index()
  String catalogId;

  String mode;

  @Index()
  int startedAtMs;

  int endedAtMs;
  int score;
  int streak;
  int mistakes;
  int minRating;
  int maxRating;
  bool randomMode;
}
