import 'package:better_puzzles/domain/fen_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies normal UCI moves and changes the active color', () {
    final position = FenPosition.parse('8/8/8/8/8/8/4P3/4K2k w - - 0 1');

    position.applyUci('e2e4');

    expect(position.pieceAt('e2'), isNull);
    expect(position.pieceAt('e4'), 'P');
    expect(position.activeColor, FenActiveColor.black);
  });

  test('applies castling rook movement', () {
    final position = FenPosition.parse('4k3/8/8/8/8/8/8/4K2R w K - 0 1');

    position.applyUci('e1g1');

    expect(position.pieceAt('g1'), 'K');
    expect(position.pieceAt('f1'), 'R');
    expect(position.castlingRights, '-');
  });
}
