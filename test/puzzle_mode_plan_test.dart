import 'package:better_puzzles/domain/puzzle_mode_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('streak plan follows the 149-puzzle Lichess distribution', () {
    final selections = PuzzleModePlan.buildStreakSelections();

    expect(selections, hasLength(149));
    expect(selections.first.maxRating, 1050);
    expect(selections.last.maxRating, 2799);
    expect(selections.every((selection) => selection.random), isTrue);
  });

  test('storm plan follows the 137-puzzle Lichess distribution', () {
    final selections = PuzzleModePlan.buildStormSelections(playerColor: 1);

    expect(selections, hasLength(137));
    expect(selections.first.maxRating, 1050);
    expect(selections.last.maxRating, 2499);
    expect(selections.every((selection) => selection.playerColor == 1), isTrue);
  });

  test('storm combo bonuses match Lichess thresholds', () {
    expect(PuzzleModePlan.stormBonusSecondsForCombo(4), 0);
    expect(PuzzleModePlan.stormBonusSecondsForCombo(5), 3);
    expect(PuzzleModePlan.stormBonusSecondsForCombo(12), 5);
    expect(PuzzleModePlan.stormBonusSecondsForCombo(20), 7);
    expect(PuzzleModePlan.stormBonusSecondsForCombo(30), 10);
    expect(PuzzleModePlan.stormBonusSecondsForCombo(40), 10);
    expect(PuzzleModePlan.stormBonusSecondsForCombo(41), 0);
  });
}
