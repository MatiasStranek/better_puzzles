enum PuzzleDifficulty {
  easiest(-600, 'Sehr leicht'),
  easier(-300, 'Leichter'),
  normal(0, 'Normal'),
  harder(300, 'Schwerer'),
  hardest(600, 'Sehr schwer');

  const PuzzleDifficulty(this.ratingDelta, this.label);

  final int ratingDelta;
  final String label;

  String get storageName => name;

  String get detailLabel {
    final delta = ratingDelta;
    if (delta == 0) {
      return '$label (±0)';
    }
    return '$label (${delta > 0 ? '+' : ''}$delta)';
  }

  PuzzleDifficulty get next {
    final values = PuzzleDifficulty.values;
    return values[(index + 1) % values.length];
  }

  static PuzzleDifficulty fromStorageName(String value) {
    return PuzzleDifficulty.values.firstWhere(
      (difficulty) => difficulty.storageName == value,
      orElse: () => PuzzleDifficulty.normal,
    );
  }
}
