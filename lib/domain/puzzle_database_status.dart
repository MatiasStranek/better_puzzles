class PuzzleDatabaseStatus {
  const PuzzleDatabaseStatus({
    required this.isAvailable,
    required this.label,
    this.puzzleCount,
    this.sourceName,
    this.importedAtMs,
  });

  const PuzzleDatabaseStatus.missing()
      : isAvailable = false,
        label = 'Keine Puzzle-Datenbank importiert',
        puzzleCount = null,
        sourceName = null,
        importedAtMs = null;

  final bool isAvailable;
  final String label;
  final int? puzzleCount;
  final String? sourceName;
  final int? importedAtMs;

  String get countLabel {
    final count = puzzleCount;

    if (count == null) {
      return 'Noch keine Datenbank';
    }

    return '${_formatCount(count)} Puzzles';
  }

  String _formatCount(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }
}
