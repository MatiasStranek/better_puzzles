import 'package:flutter_test/flutter_test.dart';
import 'package:better_puzzles/domain/fen_position.dart';

void main() {
  group('FenPosition legal move validation', () {
    test('rejects impossible rook and bishop moves', () {
      final position = FenPosition.parse(
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
      expect(position.isLegalUci('a1a4'), isFalse);
      expect(position.isLegalUci('c1h6'), isFalse);
      expect(position.isLegalUci('e2e4'), isTrue);
      expect(position.isLegalUci('g1f3'), isTrue);
    });

    test('rejects moves that expose own king', () {
      final position = FenPosition.parse('4r1k1/8/8/8/8/8/4R3/4K3 w - - 0 1');
      expect(position.isLegalUci('e2d2'), isFalse);
      expect(position.isLegalUci('e2e8'), isTrue);
    });

    test('returns only legal targets', () {
      final position = FenPosition.parse(
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
      expect(position.legalTargetsFrom('e2').toSet(), {'e3', 'e4'});
    });
  });
}
