import 'package:puzzle_catalog_builder/src/lichess_row.dart';
import 'package:test/test.dart';

void main() {
  test('applies the Lichess setup move and keeps the remaining solution', () {
    final row = LichessPuzzleRow.fromFields(const <String>[
      '00sHx',
      'q3k1nr/1pp1nQpp/3p4/1P2p3/4P3/B1PP1b2/B5PP/5K2 b k - 0 17',
      'e8d7 a2e6 d7d8 f7f8',
      '1760',
      '80',
      '83',
      '72',
      'mate mateIn2 middlegame short',
      'https://lichess.org/yyznGmXs/black#34',
      'Italian_Game Italian_Game_Classical_Variation',
    ]);

    final result = row.transform(ratingBucketSize: 50, randomSeed: 123);
    final puzzle = result.entity;

    expect(puzzle.setupMoveUci, 'e8d7');
    expect(
      puzzle.puzzleFen,
      'q5nr/1ppknQpp/3p4/1P2p3/4P3/B1PP1b2/B5PP/5K2 w - - 1 18',
    );
    expect(puzzle.solutionMovesUci, 'a2e6 d7d8 f7f8');
    expect(puzzle.solutionPlyCount, 3);
    expect(puzzle.playerColor, 0);
    expect(puzzle.ratingBucket, 1750);
    expect(result.unknownThemes, isEmpty);
  });
}
