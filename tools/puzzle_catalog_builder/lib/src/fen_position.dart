enum FenActiveColor {
  white,
  black,
}

class FenPosition {
  FenPosition._({
    required this._board,
    required this.activeColor,
    required this.castlingRights,
    required this.enPassantSquare,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  final List<String?> _board;
  FenActiveColor activeColor;
  String castlingRights;
  String enPassantSquare;
  int halfmoveClock;
  int fullmoveNumber;

  factory FenPosition.parse(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length != 6) {
      throw FormatException(
        'FEN muss 6 Felder enthalten, erhalten ${parts.length}',
      );
    }

    final board = List<String?>.filled(64, null);
    final ranks = parts[0].split('/');
    if (ranks.length != 8) {
      throw const FormatException('FEN-Brett muss 8 Reihen enthalten');
    }

    for (var rankOffset = 0; rankOffset < 8; rankOffset++) {
      final rank = 8 - rankOffset;
      var file = 0;

      for (final rune in ranks[rankOffset].runes) {
        final value = String.fromCharCode(rune);
        final empty = int.tryParse(value);

        if (empty != null) {
          if (empty < 1 || empty > 8) {
            throw FormatException('Ungültige Leerfeldzahl: $value');
          }
          file += empty;
          continue;
        }

        if (!RegExp(r'^[prnbqkPRNBQK]$').hasMatch(value)) {
          throw FormatException('Ungültige FEN-Figur: $value');
        }
        if (file >= 8) {
          throw const FormatException('Zu viele Felder in FEN-Reihe');
        }

        board[_index(file, rank)] = value;
        file++;
      }

      if (file != 8) {
        throw FormatException(
          'FEN-Reihe $rank enthält $file statt 8 Felder',
        );
      }
    }

    final activeColor = switch (parts[1]) {
      'w' => FenActiveColor.white,
      'b' => FenActiveColor.black,
      _ => throw FormatException('Ungültige aktive Farbe: ${parts[1]}'),
    };

    final castling = parts[2];
    if (castling != '-' &&
        !RegExp(r'^(K?Q?k?q?)$').hasMatch(castling)) {
      throw FormatException('Ungültige Rochaderechte: $castling');
    }

    final enPassant = parts[3];
    if (enPassant != '-' &&
        !RegExp(r'^[a-h][36]$').hasMatch(enPassant)) {
      throw FormatException('Ungültiges En-passant-Feld: $enPassant');
    }

    final halfmove = int.tryParse(parts[4]);
    final fullmove = int.tryParse(parts[5]);
    if (halfmove == null || halfmove < 0) {
      throw FormatException('Ungültige Halbzugzahl: ${parts[4]}');
    }
    if (fullmove == null || fullmove < 1) {
      throw FormatException('Ungültige Zugnummer: ${parts[5]}');
    }

    return FenPosition._(
      board: board,
      activeColor: activeColor,
      castlingRights: castling,
      enPassantSquare: enPassant,
      halfmoveClock: halfmove,
      fullmoveNumber: fullmove,
    );
  }

  void applyUci(String uci) {
    if (!RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(uci)) {
      throw FormatException('Ungültiger UCI-Zug: $uci');
    }

    final fromSquare = uci.substring(0, 2);
    final toSquare = uci.substring(2, 4);
    final promotion = uci.length == 5 ? uci.substring(4, 5) : null;
    final from = _squareIndex(fromSquare);
    final to = _squareIndex(toSquare);
    final piece = _board[from];

    if (piece == null) {
      throw FormatException(
        'Auf $fromSquare steht keine Figur für $uci',
      );
    }

    final movingWhite = _isWhite(piece);
    if ((activeColor == FenActiveColor.white) != movingWhite) {
      throw FormatException(
        'Falsche Farbe am Zug für $uci in ${toFen()}',
      );
    }

    final targetPiece = _board[to];
    if (targetPiece != null && _isWhite(targetPiece) == movingWhite) {
      throw FormatException(
        'Eigene Figur auf Zielfeld $toSquare bei $uci',
      );
    }

    final lowerPiece = piece.toLowerCase();
    final fromFile = _fileOf(from);
    final fromRank = _rankOf(from);
    final toFile = _fileOf(to);
    final toRank = _rankOf(to);
    var isCapture = targetPiece != null;

    _updateCastlingRightsForMove(
      piece: piece,
      fromSquare: fromSquare,
      capturedPiece: targetPiece,
      toSquare: toSquare,
    );

    if (lowerPiece == 'p' &&
        targetPiece == null &&
        fromFile != toFile &&
        toSquare == enPassantSquare) {
      final capturedRank = movingWhite ? toRank - 1 : toRank + 1;
      final capturedIndex = _index(toFile, capturedRank);
      final capturedPawn = _board[capturedIndex];
      final expectedPawn = movingWhite ? 'p' : 'P';

      if (capturedPawn != expectedPawn) {
        throw FormatException(
          'Ungültiges En passant bei $uci',
        );
      }

      _board[capturedIndex] = null;
      isCapture = true;
    }

    if (lowerPiece == 'k' && (fromFile - toFile).abs() == 2) {
      _moveCastlingRook(
        movingWhite: movingWhite,
        fromSquare: fromSquare,
        toSquare: toSquare,
      );
    }

    _board[from] = null;

    String placedPiece = piece;
    if (promotion != null) {
      if (lowerPiece != 'p' || (toRank != 1 && toRank != 8)) {
        throw FormatException('Ungültige Promotion bei $uci');
      }
      placedPiece = movingWhite
          ? promotion.toUpperCase()
          : promotion.toLowerCase();
    } else if (lowerPiece == 'p' && (toRank == 1 || toRank == 8)) {
      throw FormatException('Promotion fehlt bei $uci');
    }

    _board[to] = placedPiece;

    if (lowerPiece == 'p' && (fromRank - toRank).abs() == 2) {
      final middleRank = (fromRank + toRank) ~/ 2;
      enPassantSquare = _squareName(fromFile, middleRank);
    } else {
      enPassantSquare = '-';
    }

    if (lowerPiece == 'p' || isCapture) {
      halfmoveClock = 0;
    } else {
      halfmoveClock++;
    }

    if (activeColor == FenActiveColor.black) {
      fullmoveNumber++;
    }
    activeColor = activeColor == FenActiveColor.white
        ? FenActiveColor.black
        : FenActiveColor.white;
  }

  String toFen() {
    final rankTexts = <String>[];

    for (var rank = 8; rank >= 1; rank--) {
      final buffer = StringBuffer();
      var empty = 0;

      for (var file = 0; file < 8; file++) {
        final piece = _board[_index(file, rank)];
        if (piece == null) {
          empty++;
          continue;
        }

        if (empty > 0) {
          buffer.write(empty);
          empty = 0;
        }
        buffer.write(piece);
      }

      if (empty > 0) {
        buffer.write(empty);
      }
      rankTexts.add(buffer.toString());
    }

    final color = activeColor == FenActiveColor.white ? 'w' : 'b';
    final castling = castlingRights.isEmpty ? '-' : castlingRights;

    return '${rankTexts.join('/')} $color $castling '
        '$enPassantSquare $halfmoveClock $fullmoveNumber';
  }

  void _updateCastlingRightsForMove({
    required String piece,
    required String fromSquare,
    required String? capturedPiece,
    required String toSquare,
  }) {
    final lowerPiece = piece.toLowerCase();

    if (lowerPiece == 'k') {
      if (_isWhite(piece)) {
        _removeCastlingRight('K');
        _removeCastlingRight('Q');
      } else {
        _removeCastlingRight('k');
        _removeCastlingRight('q');
      }
    }

    if (lowerPiece == 'r') {
      _removeRookRightForSquare(fromSquare);
    }

    if (capturedPiece != null &&
        capturedPiece.toLowerCase() == 'r') {
      _removeRookRightForSquare(toSquare);
    }
  }

  void _removeRookRightForSquare(String square) {
    final right = switch (square) {
      'a1' => 'Q',
      'h1' => 'K',
      'a8' => 'q',
      'h8' => 'k',
      _ => null,
    };

    if (right != null) {
      _removeCastlingRight(right);
    }
  }

  void _removeCastlingRight(String value) {
    if (castlingRights == '-') {
      return;
    }
    castlingRights = castlingRights.replaceAll(value, '');
    if (castlingRights.isEmpty) {
      castlingRights = '-';
    }
  }

  void _moveCastlingRook({
    required bool movingWhite,
    required String fromSquare,
    required String toSquare,
  }) {
    final expectedFrom = movingWhite ? 'e1' : 'e8';
    if (fromSquare != expectedFrom) {
      throw FormatException('Ungültiger Rochade-Königszug');
    }

    final (rookFrom, rookTo) = switch (toSquare) {
      'g1' => ('h1', 'f1'),
      'c1' => ('a1', 'd1'),
      'g8' => ('h8', 'f8'),
      'c8' => ('a8', 'd8'),
      _ => throw FormatException(
          'Ungültiges Rochade-Zielfeld: $toSquare',
        ),
    };

    final rookIndex = _squareIndex(rookFrom);
    final rook = _board[rookIndex];
    final expectedRook = movingWhite ? 'R' : 'r';
    if (rook != expectedRook) {
      throw FormatException('Rochadeturm fehlt auf $rookFrom');
    }

    final rookTarget = _squareIndex(rookTo);
    if (_board[rookTarget] != null) {
      throw FormatException('Rochade-Zielfeld $rookTo ist belegt');
    }

    _board[rookIndex] = null;
    _board[rookTarget] = rook;
  }

  static bool _isWhite(String piece) {
    return piece == piece.toUpperCase();
  }

  static int _squareIndex(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square.substring(1, 2));
    return _index(file, rank);
  }

  static int _index(int file, int rank) {
    if (file < 0 || file > 7 || rank < 1 || rank > 8) {
      throw RangeError('Ungültiges Feld: file=$file, rank=$rank');
    }
    return (rank - 1) * 8 + file;
  }

  static int _fileOf(int index) => index % 8;
  static int _rankOf(int index) => (index ~/ 8) + 1;

  static String _squareName(int file, int rank) {
    return '${String.fromCharCode('a'.codeUnitAt(0) + file)}$rank';
  }
}
