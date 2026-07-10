import 'package:puzzle_catalog_builder/src/fen_position.dart';
import 'package:test/test.dart';

void main() {
  test('applies a normal setup move and updates FEN clocks', () {
    final position = FenPosition.parse(
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/'
      'RNBQKBNR w KQkq - 0 2',
    );

    position.applyUci('g1f3');

    expect(
      position.toFen(),
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/'
      'RNBQKB1R b KQkq - 1 2',
    );
  });

  test('applies castling', () {
    final position = FenPosition.parse('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');

    position.applyUci('e1g1');

    expect(position.toFen(), 'r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1');
  });

  test('applies en passant', () {
    final position = FenPosition.parse('8/8/8/3pP3/8/8/8/4K2k w - d6 0 20');

    position.applyUci('e5d6');

    expect(position.toFen(), '8/8/3P4/8/8/8/8/4K2k b - - 0 20');
  });

  test('applies promotion', () {
    final position = FenPosition.parse('8/P7/8/8/8/8/8/4K2k w - - 0 1');

    position.applyUci('a7a8q');

    expect(position.toFen(), 'Q7/8/8/8/8/8/8/4K2k b - - 0 1');
  });
}
