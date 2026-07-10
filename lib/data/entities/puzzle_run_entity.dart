import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleRunEntity {
  @Id()
  int id = 0;

  late String mode;
  late int startedAtMs;
  late int endedAtMs;

  late int score;
  late int streak;
  late int mistakes;
  late int minRating;
  late int maxRating;
}
