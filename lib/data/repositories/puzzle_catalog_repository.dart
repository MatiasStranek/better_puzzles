import '../../domain/puzzle_range.dart';
import '../../domain/puzzle_record.dart';
import '../../domain/puzzle_selection.dart';

abstract class PuzzleCatalogRepository {
  Future<PuzzleRecord?> nextPuzzle({
    required PuzzleRange range,
    required bool random,
  });

  Future<PuzzleRecord?> selectPuzzle(PuzzleSelection selection);

  /// Resets sequential cursors while keeping reusable catalog caches warm.
  void resetCursors();

  /// Drops all repository-local caches, e.g. before disposing or swapping a
  /// catalog. Existing callers normally only need [resetCursors].
  void clearCaches();
}
