import '../../domain/puzzle_range.dart';
import '../../domain/puzzle_record.dart';
import '../../domain/puzzle_selection.dart';

abstract class PuzzleCatalogRepository {
  Future<PuzzleRecord?> nextPuzzle({
    required PuzzleRange range,
    required bool random,
  });

  Future<PuzzleRecord?> selectPuzzle(PuzzleSelection selection);

  void resetCursors();
}
