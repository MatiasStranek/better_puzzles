import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleSettingsEntity {
  @Id(assignable: true)
  int id = 1;

  late int minRating;
  late int maxRating;
  late bool randomMode;
  late String selectedMode;
}
