import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleEntity {
  @Id()
  int id = 0;

  @Unique()
  late String lichessPuzzleId;

  @Index()
  late int rating;

  @Index()
  late int ratingBucket;

  late int ratingDeviation;
  late int popularity;
  late int nbPlays;

  late String sourceFen;
  late String puzzleFen;
  late String movesUci;
  late String setupMoveUci;
  late String solutionMovesUci;
  late int solutionPlyCount;

  /// 0 = Weiß löst, 1 = Schwarz löst.
  @Index()
  late int playerColor;

  late String themes;
  late String openingTags;

  @Index()
  late int themeMaskLow;

  @Index()
  late int themeMaskHigh;

  @Index()
  late int randomKey;
}
