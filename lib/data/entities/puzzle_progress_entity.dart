import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleProgressEntity {
  @Id()
  int id = 0;

  @Index()
  late String lichessPuzzleId;

  late bool solved;
  late bool failed;
  late int attempts;
  late int bestTimeMs;
  late int lastPlayedAtMs;
}
