import 'puzzle_selection.dart';

class PuzzleModePlan {
  const PuzzleModePlan._();

  static const int stormInitialSeconds = 3 * 60;
  static const int stormMistakePenaltySeconds = 10;

  /// Lichess Puzzle Streak pool distribution (149 puzzles).
  static const List<PuzzleRatingBand> streakBands = <PuzzleRatingBand>[
    PuzzleRatingBand(upperRating: 1050, count: 3),
    PuzzleRatingBand(upperRating: 1150, count: 4),
    PuzzleRatingBand(upperRating: 1300, count: 5),
    PuzzleRatingBand(upperRating: 1450, count: 6),
    PuzzleRatingBand(upperRating: 1600, count: 7),
    PuzzleRatingBand(upperRating: 1750, count: 8),
    PuzzleRatingBand(upperRating: 1900, count: 10),
    PuzzleRatingBand(upperRating: 2050, count: 13),
    PuzzleRatingBand(upperRating: 2199, count: 15),
    PuzzleRatingBand(upperRating: 2349, count: 17),
    PuzzleRatingBand(upperRating: 2499, count: 19),
    PuzzleRatingBand(upperRating: 2649, count: 21),
    PuzzleRatingBand(upperRating: 2799, count: 21),
  ];

  /// Lichess Puzzle Storm pool distribution (137 puzzles).
  static const List<PuzzleRatingBand> stormBands = <PuzzleRatingBand>[
    PuzzleRatingBand(upperRating: 1050, count: 7),
    PuzzleRatingBand(upperRating: 1150, count: 7),
    PuzzleRatingBand(upperRating: 1300, count: 8),
    PuzzleRatingBand(upperRating: 1450, count: 9),
    PuzzleRatingBand(upperRating: 1600, count: 10),
    PuzzleRatingBand(upperRating: 1750, count: 11),
    PuzzleRatingBand(upperRating: 1900, count: 13),
    PuzzleRatingBand(upperRating: 2050, count: 15),
    PuzzleRatingBand(upperRating: 2199, count: 17),
    PuzzleRatingBand(upperRating: 2349, count: 19),
    PuzzleRatingBand(upperRating: 2499, count: 21),
  ];

  static List<PuzzleSelection> buildStreakSelections() {
    return _buildSelections(
      bands: streakBands,
      maxDeviationForRating: (rating) => rating > 2300 ? 110 : 85,
      playerColor: null,
    );
  }

  static List<PuzzleSelection> buildStormSelections({
    required int playerColor,
  }) {
    return _buildSelections(
      bands: stormBands,
      maxDeviationForRating: (_) => 85,
      playerColor: playerColor,
    );
  }

  static int stormBonusSecondsForCombo(int combo) {
    if (combo >= 30 && combo % 10 == 0) {
      return 10;
    }
    return switch (combo) {
      5 => 3,
      12 => 5,
      20 => 7,
      30 => 10,
      _ => 0,
    };
  }

  static List<PuzzleSelection> _buildSelections({
    required List<PuzzleRatingBand> bands,
    required int Function(int rating) maxDeviationForRating,
    required int? playerColor,
  }) {
    final selections = <PuzzleSelection>[];
    var lower = 400;

    for (final band in bands) {
      final span = band.upperRating - lower + 1;
      for (var index = 0; index < band.count; index++) {
        final fraction = (index + 1) / (band.count + 1);
        final target = lower + (span * fraction).round();
        selections.add(
          PuzzleSelection(
            minRating: lower,
            maxRating: band.upperRating,
            targetRating: target,
            random: true,
            maxRatingDeviation: maxDeviationForRating(target),
            minPopularity: 50,
            minPlays: 20,
            playerColor: playerColor,
          ),
        );
      }
      lower = band.upperRating + 1;
    }

    return selections;
  }
}

class PuzzleRatingBand {
  const PuzzleRatingBand({required this.upperRating, required this.count});

  final int upperRating;
  final int count;
}
