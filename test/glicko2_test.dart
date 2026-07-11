import 'package:better_puzzles/domain/glicko2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = Glicko2Calculator();
  const initial = Glicko2Rating.initial;
  final fixedNow = DateTime.utc(2026, 7, 11);

  test('a win against an equal puzzle raises the local puzzle rating', () {
    final update = calculator.updateSingle(
      player: initial,
      opponentRating: 1500,
      opponentDeviation: 80,
      win: true,
      now: fixedNow,
    );

    expect(update.after.rating, closeTo(1736.8459, 0.001));
    expect(update.after.deviation, closeTo(291.3753, 0.001));
    expect(update.ratingChange, 237);
    expect(update.after.numberOfResults, 1);
  });

  test('a loss against an equal puzzle lowers the local puzzle rating', () {
    final update = calculator.updateSingle(
      player: initial,
      opponentRating: 1500,
      opponentDeviation: 80,
      win: false,
      now: fixedNow,
    );

    expect(update.after.rating, closeTo(1263.1541, 0.001));
    expect(update.after.deviation, closeTo(291.3753, 0.001));
    expect(update.ratingChange, -237);
  });

  test('display rating remains inside the configured Lichess bounds', () {
    expect(
      const Glicko2Rating(
        rating: 100,
        deviation: 50,
        volatility: 0.09,
      ).displayRating,
      400,
    );
    expect(
      const Glicko2Rating(
        rating: 5000,
        deviation: 50,
        volatility: 0.09,
      ).displayRating,
      4000,
    );
  });
}
