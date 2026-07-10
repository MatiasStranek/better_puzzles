class ThemeMask {
  const ThemeMask({
    required this.low,
    required this.high,
    required this.unknownThemes,
  });

  final int low;
  final int high;
  final List<String> unknownThemes;
}

abstract final class ThemeDictionaryV1 {
  static const int version = 1;
  static const int maskBits = 126;

  /// Stable order: never reorder or remove entries. Additions require a new
  /// dictionary version so existing masks remain meaningful.
  static const List<String> themes = <String>[
    'advancedPawn',
    'advantage',
    'anastasiaMate',
    'arabianMate',
    'attackingF2F7',
    'attraction',
    'backRankMate',
    'balestraMate',
    'blindSwineMate',
    'bishopEndgame',
    'bodenMate',
    'castling',
    'capturingDefender',
    'clearance',
    'collinearMove',
    'cornerMate',
    'crushing',
    'defensiveMove',
    'deflection',
    'discoveredAttack',
    'discoveredCheck',
    'doubleBishopMate',
    'doubleCheck',
    'dovetailMate',
    'endgame',
    'enPassant',
    'epauletteMate',
    'equality',
    'exposedKing',
    'fork',
    'hangingPiece',
    'hookMate',
    'interference',
    'intermezzo',
    'killBoxMate',
    'kingsideAttack',
    'knightEndgame',
    'long',
    'master',
    'masterVsMaster',
    'mate',
    'mateIn1',
    'mateIn2',
    'mateIn3',
    'mateIn4',
    'mateIn5',
    'middlegame',
    'morphysMate',
    'oneMove',
    'opening',
    'operaMate',
    'pawnEndgame',
    'pillsburysMate',
    'pin',
    'promotion',
    'queenEndgame',
    'queenRookEndgame',
    'queensideAttack',
    'quietMove',
    'rookEndgame',
    'sacrifice',
    'short',
    'skewer',
    'smotheredMate',
    'superGM',
    'swallowstailMate',
    'trappedPiece',
    'triangleMate',
    'underPromotion',
    'veryLong',
    'vukovicMate',
    'xRayAttack',
    'zugzwang',
  ];

  static final Map<String, int> _indices = <String, int>{
    for (var index = 0; index < themes.length; index++) themes[index]: index,
  };

  static String get canonicalText => themes.join('\n');

  static ThemeMask encodeText(String originalThemes) {
    final values = originalThemes
        .trim()
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty);
    return encode(values);
  }

  static ThemeMask encode(Iterable<String> values) {
    var low = 0;
    var high = 0;
    final unknown = <String>[];

    for (final value in values) {
      final bit = _indices[value];
      if (bit == null) {
        unknown.add(value);
        continue;
      }

      if (bit < 63) {
        low |= 1 << bit;
      } else {
        high |= 1 << (bit - 63);
      }
    }

    return ThemeMask(
      low: low,
      high: high,
      unknownThemes: List<String>.unmodifiable(unknown),
    );
  }

  static bool containsAll({
    required int storedLow,
    required int storedHigh,
    required int requiredLow,
    required int requiredHigh,
  }) {
    return (storedLow & requiredLow) == requiredLow &&
        (storedHigh & requiredHigh) == requiredHigh;
  }
}
