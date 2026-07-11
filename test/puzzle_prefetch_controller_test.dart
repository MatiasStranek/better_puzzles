import 'package:better_puzzles/controllers/puzzle_app_controller.dart';
import 'package:better_puzzles/data/repositories/puzzle_catalog_repository.dart';
import 'package:better_puzzles/domain/puzzle_range.dart';
import 'package:better_puzzles/domain/puzzle_record.dart';
import 'package:better_puzzles/domain/puzzle_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'task mode serves a prepared next puzzle from the prefetch queue',
    () async {
      final repository = _DelayedPuzzleRepository();
      final controller = PuzzleAppController(repository: repository);
      addTearDown(controller.dispose);

      await _waitUntil(() => controller.currentPuzzle != null);
      await _waitUntil(() => controller.prefetchedPuzzleCount > 0);

      final firstId = controller.currentPuzzle!.lichessPuzzleId;
      await controller.loadNextPuzzle();

      expect(controller.currentPuzzle, isNotNull);
      expect(controller.currentPuzzle!.lichessPuzzleId, isNot(firstId));
      expect(controller.lastPuzzleWasPrefetched, isTrue);
    },
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out while waiting for asynchronous prefetch');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _DelayedPuzzleRepository implements PuzzleCatalogRepository {
  int _next = 0;

  @override
  Future<PuzzleRecord?> nextPuzzle({
    required PuzzleRange range,
    required bool random,
  }) {
    return selectPuzzle(
      PuzzleSelection(
        minRating: range.minRating,
        maxRating: range.maxRating,
        random: random,
      ),
    );
  }

  @override
  Future<PuzzleRecord?> selectPuzzle(PuzzleSelection selection) async {
    await Future<void>.delayed(const Duration(milliseconds: 8));
    for (var attempt = 0; attempt < 20; attempt++) {
      final index = _next++;
      final id = 'prefetch-$index';
      if (selection.excludePuzzleIds.contains(id)) {
        continue;
      }
      return PuzzleRecord(
        lichessPuzzleId: id,
        puzzleFen:
            'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
        setupMoveUci: 'b8c6',
        solutionMovesUci: 'f1b5',
        rating: 1500,
        ratingDeviation: 80,
        popularity: 100,
        nbPlays: 1000,
        themes: 'test',
        playerColor: 0,
      );
    }
    return null;
  }

  @override
  void resetCursors() {}

  @override
  void clearCaches() {
    resetCursors();
  }
}
