class FenPieceMap {
  const FenPieceMap._();

  static Map<String, String> fromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final placement = parts.isEmpty ? '' : parts.first;
    final result = <String, String>{};
    final ranks = placement.split('/');

    for (var rankOffset = 0;
        rankOffset < ranks.length && rankOffset < 8;
        rankOffset++) {
      final rankText = ranks[rankOffset];
      final rank = 8 - rankOffset;
      var fileIndex = 0;

      for (final rune in rankText.runes) {
        final char = String.fromCharCode(rune);
        final empty = int.tryParse(char);

        if (empty != null) {
          fileIndex += empty;
          continue;
        }

        if (fileIndex < 0 || fileIndex > 7) {
          continue;
        }

        final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
        result['$file$rank'] = char;
        fileIndex++;
      }
    }

    return result;
  }
}
