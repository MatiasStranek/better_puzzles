import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleSettingsEntity {
  PuzzleSettingsEntity({
    this.id = singletonId,
    this.minRating = 600,
    this.maxRating = 1600,
    this.randomMode = false,
    this.selectedMode = 'tasks',
  });

  static const int singletonId = 1;

  @Id(assignable: true)
  int id;

  int minRating;
  int maxRating;
  bool randomMode;
  String selectedMode;
}
