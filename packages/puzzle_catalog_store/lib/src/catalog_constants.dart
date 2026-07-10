abstract final class PuzzleCatalogConstants {
  static const int schemaVersion = 1;
  static const int ratingBucketSize = 50;

  /// ObjectBox uses a memory-mapped file. This is a ceiling, not a
  /// pre-allocation. The builder can override it.
  static const int defaultMaxDbSizeKb = 8 * 1024 * 1024;

  static const int white = 0;
  static const int black = 1;
}
