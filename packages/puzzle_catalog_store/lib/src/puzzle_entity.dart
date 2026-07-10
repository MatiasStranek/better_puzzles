import 'package:objectbox/objectbox.dart';

@Entity()
class PuzzleEntity {
  PuzzleEntity({
    this.id = 0,
    required this.lichessPuzzleId,
    required this.sourceFen,
    required this.setupMoveUci,
    required this.puzzleFen,
    required this.movesUci,
    required this.solutionMovesUci,
    required this.solutionPlyCount,
    required this.playerColor,
    required this.rating,
    required this.ratingBucket,
    required this.ratingDeviation,
    required this.popularity,
    required this.nbPlays,
    required this.themes,
    required this.openingTags,
    required this.themeMaskLow,
    required this.themeMaskHigh,
    required this.randomKey,
    this.gameUrl = '',
  });

  @Id()
  int id;

  @Unique()
  String lichessPuzzleId;

  String sourceFen;
  String setupMoveUci;
  String puzzleFen;

  /// Complete original Lichess UCI sequence, including setupMoveUci.
  String movesUci;

  /// All moves after setupMoveUci. The user starts at index 0.
  String solutionMovesUci;
  int solutionPlyCount;

  /// 0 = White solves, 1 = Black solves.
  @Index()
  int playerColor;

  @Index()
  int rating;

  @Index()
  int ratingBucket;

  int ratingDeviation;

  @Index()
  int popularity;

  @Index()
  int nbPlays;

  String themes;
  String openingTags;
  String gameUrl;

  /// Two 63-bit masks. Bit 63 is intentionally unused so values always fit
  /// into ObjectBox's signed 64-bit integer representation.
  int themeMaskLow;
  int themeMaskHigh;

  /// Deterministic positive 63-bit hash used for pivot-based random queries.
  @Index()
  int randomKey;
}
