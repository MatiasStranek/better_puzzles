class PuzzleSelection {
  const PuzzleSelection({
    required this.minRating,
    required this.maxRating,
    this.targetRating,
    this.random = true,
    this.maxRatingDeviation,
    this.minPopularity,
    this.minPlays,
    this.playerColor,
    this.excludePuzzleIds = const <String>{},
  }) : assert(minRating <= maxRating);

  final int minRating;
  final int maxRating;
  final int? targetRating;
  final bool random;
  final int? maxRatingDeviation;
  final int? minPopularity;
  final int? minPlays;

  /// 0 = Weiß löst, 1 = Schwarz löst.
  final int? playerColor;
  final Set<String> excludePuzzleIds;

  PuzzleSelection copyWith({
    int? minRating,
    int? maxRating,
    int? targetRating,
    bool clearTargetRating = false,
    bool? random,
    int? maxRatingDeviation,
    bool clearMaxRatingDeviation = false,
    int? minPopularity,
    bool clearMinPopularity = false,
    int? minPlays,
    bool clearMinPlays = false,
    int? playerColor,
    bool clearPlayerColor = false,
    Set<String>? excludePuzzleIds,
  }) {
    return PuzzleSelection(
      minRating: minRating ?? this.minRating,
      maxRating: maxRating ?? this.maxRating,
      targetRating: clearTargetRating
          ? null
          : targetRating ?? this.targetRating,
      random: random ?? this.random,
      maxRatingDeviation: clearMaxRatingDeviation
          ? null
          : maxRatingDeviation ?? this.maxRatingDeviation,
      minPopularity: clearMinPopularity
          ? null
          : minPopularity ?? this.minPopularity,
      minPlays: clearMinPlays ? null : minPlays ?? this.minPlays,
      playerColor: clearPlayerColor ? null : playerColor ?? this.playerColor,
      excludePuzzleIds: excludePuzzleIds ?? this.excludePuzzleIds,
    );
  }
}
