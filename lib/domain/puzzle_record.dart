class PuzzleRecord {
  const PuzzleRecord({
    required this.lichessPuzzleId,
    required this.puzzleFen,
    required this.setupMoveUci,
    required this.solutionMovesUci,
    required this.rating,
    required this.ratingDeviation,
    required this.popularity,
    required this.nbPlays,
    required this.themes,
    required this.playerColor,
  });

  final String lichessPuzzleId;
  final String puzzleFen;
  final String setupMoveUci;
  final String solutionMovesUci;
  final int rating;
  final int ratingDeviation;
  final int popularity;
  final int nbPlays;
  final String themes;

  /// 0 = Weiß löst, 1 = Schwarz löst.
  final int playerColor;

  List<String> get solutionMoves =>
      solutionMovesUci.split(' ').where((move) => move.isNotEmpty).toList();
}
