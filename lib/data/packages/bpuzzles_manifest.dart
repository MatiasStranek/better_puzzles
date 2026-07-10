class BPuzzlesManifest {
  const BPuzzlesManifest({
    required this.format,
    required this.formatVersion,
    required this.schemaVersion,
    required this.source,
    required this.puzzleCount,
    required this.createdAt,
    required this.minRating,
    required this.maxRating,
  });

  final String format;
  final int formatVersion;
  final int schemaVersion;
  final String source;
  final int puzzleCount;
  final String createdAt;
  final int minRating;
  final int maxRating;

  bool get isCompatible {
    return format == 'better_puzzles_database' &&
        formatVersion == 1 &&
        schemaVersion == 1;
  }

  factory BPuzzlesManifest.fromJson(Map<String, Object?> json) {
    return BPuzzlesManifest(
      format: json['format']?.toString() ?? '',
      formatVersion: (json['formatVersion'] as num?)?.toInt() ?? 0,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? '',
      puzzleCount: (json['puzzleCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      minRating: (json['minRating'] as num?)?.toInt() ?? 0,
      maxRating: (json['maxRating'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'format': format,
      'formatVersion': formatVersion,
      'schemaVersion': schemaVersion,
      'source': source,
      'puzzleCount': puzzleCount,
      'createdAt': createdAt,
      'minRating': minRating,
      'maxRating': maxRating,
    };
  }
}
