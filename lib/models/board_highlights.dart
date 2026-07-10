class BoardHighlights {
  const BoardHighlights({
    this.selectedSquare,
    this.lastFrom,
    this.lastTo,
    this.premoveSquares = const {},
    this.legalTargets = const [],
  });

  final String? selectedSquare;
  final String? lastFrom;
  final String? lastTo;

  /// Bleibt für UI-Kompatibilität leer. Premoves werden in Better Puzzles nicht benutzt.
  final Set<String> premoveSquares;

  final List<String> legalTargets;

  bool isSelected(String square) => selectedSquare == square;

  bool isLastMove(String square) => square == lastFrom || square == lastTo;

  bool isPremove(String square) => premoveSquares.contains(square);

  bool isLegalTarget(String square) => legalTargets.contains(square);
}
