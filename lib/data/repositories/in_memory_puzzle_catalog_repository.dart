import '../../domain/puzzle_range.dart';
import '../../domain/puzzle_record.dart';
import 'puzzle_catalog_repository.dart';

class InMemoryPuzzleCatalogRepository implements PuzzleCatalogRepository {
  InMemoryPuzzleCatalogRepository();

  int _cursor = 0;

  final List<PuzzleRecord> _demoPuzzles = const <PuzzleRecord>[
    PuzzleRecord(
      lichessPuzzleId: 'demo-001',
      puzzleFen:
          'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
      setupMoveUci: 'b8c6',
      solutionMovesUci: 'f1b5',
      rating: 800,
      themes: 'opening development',
      playerColor: 0,
    ),
    PuzzleRecord(
      lichessPuzzleId: 'demo-002',
      puzzleFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      setupMoveUci: 'e7e5',
      solutionMovesUci: 'g1f3',
      rating: 950,
      themes: 'opening short',
      playerColor: 0,
    ),
    PuzzleRecord(
      lichessPuzzleId: 'demo-003',
      puzzleFen: 'rnbqkb1r/pppppppp/5n2/8/8/5N2/PPPPPPPP/RNBQKB1R w KQkq - 2 2',
      setupMoveUci: 'g8f6',
      solutionMovesUci: 'd2d4',
      rating: 1100,
      themes: 'opening quietMove',
      playerColor: 0,
    ),
  ];

  @override
  Future<PuzzleRecord?> nextPuzzle({
    required PuzzleRange range,
    required bool random,
  }) async {
    final candidates = _demoPuzzles
        .where(
          (puzzle) =>
              puzzle.rating >= range.minRating &&
              puzzle.rating <= range.maxRating,
        )
        .toList();

    if (candidates.isEmpty) {
      return null;
    }

    if (random) {
      _cursor = (_cursor + 2) % candidates.length;
      return candidates[_cursor];
    }

    final puzzle = candidates[_cursor % candidates.length];
    _cursor++;
    return puzzle;
  }
}
