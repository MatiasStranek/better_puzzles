import '../../domain/puzzle_range.dart';
import '../../domain/puzzle_record.dart';

abstract class PuzzleCatalogRepository {
  Future<PuzzleRecord?> nextPuzzle({
    required PuzzleRange range,
    required bool random,
  });
}
