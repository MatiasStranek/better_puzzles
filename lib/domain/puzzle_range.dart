class PuzzleRange {
  const PuzzleRange({
    required this.minRating,
    required this.maxRating,
  });

  final int minRating;
  final int maxRating;

  PuzzleRange copyWith({
    int? minRating,
    int? maxRating,
  }) {
    final nextMin = minRating ?? this.minRating;
    final nextMax = maxRating ?? this.maxRating;

    if (nextMin <= nextMax) {
      return PuzzleRange(minRating: nextMin, maxRating: nextMax);
    }

    return PuzzleRange(minRating: nextMax, maxRating: nextMin);
  }

  String get label => '$minRating–$maxRating';
}
