import 'dart:convert';

import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';

import 'fen_position.dart';

class LichessPuzzleRow {
  const LichessPuzzleRow({
    required this.puzzleId,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.ratingDeviation,
    required this.popularity,
    required this.nbPlays,
    required this.themes,
    required this.gameUrl,
    required this.openingTags,
  });

  final String puzzleId;
  final String fen;
  final String moves;
  final int rating;
  final int ratingDeviation;
  final int popularity;
  final int nbPlays;
  final String themes;
  final String gameUrl;
  final String openingTags;

  static const List<String> expectedHeader = <String>[
    'PuzzleId',
    'FEN',
    'Moves',
    'Rating',
    'RatingDeviation',
    'Popularity',
    'NbPlays',
    'Themes',
    'GameUrl',
    'OpeningTags',
  ];

  factory LichessPuzzleRow.fromFields(List<String> fields) {
    if (fields.length != expectedHeader.length) {
      throw FormatException(
        'Erwartet ${expectedHeader.length} CSV-Felder, '
        'erhalten ${fields.length}',
      );
    }

    int parseIntAt(int index, String name) {
      final result = int.tryParse(fields[index]);
      if (result == null) {
        throw FormatException('$name ist keine Ganzzahl: ${fields[index]}');
      }
      return result;
    }

    if (fields[0].isEmpty) {
      throw const FormatException('PuzzleId fehlt');
    }

    return LichessPuzzleRow(
      puzzleId: fields[0],
      fen: fields[1],
      moves: fields[2],
      rating: parseIntAt(3, 'Rating'),
      ratingDeviation: parseIntAt(4, 'RatingDeviation'),
      popularity: parseIntAt(5, 'Popularity'),
      nbPlays: parseIntAt(6, 'NbPlays'),
      themes: fields[7],
      gameUrl: fields[8],
      openingTags: fields[9],
    );
  }

  PuzzleTransformResult transform({
    required int ratingBucketSize,
    required int randomSeed,
  }) {
    final moveList = moves
        .trim()
        .split(RegExp(r'\s+'))
        .where((move) => move.isNotEmpty)
        .toList(growable: false);

    if (moveList.length < 2) {
      throw const FormatException(
        'Moves muss Setup-Zug und mindestens einen Lösungszug enthalten',
      );
    }

    final position = FenPosition.parse(fen);
    final setupMove = moveList.first;
    position.applyUci(setupMove);
    final puzzleFen = position.toFen();
    final playerColor =
        position.activeColor == FenActiveColor.white ? 0 : 1;

    // Validate the complete remaining sequence against side-to-move and board
    // state. This intentionally does not run a chess engine evaluation.
    for (final move in moveList.skip(1)) {
      position.applyUci(move);
    }

    final themeMask = ThemeDictionaryV1.encodeText(themes);
    final bucket = (rating ~/ ratingBucketSize) * ratingBucketSize;

    return PuzzleTransformResult(
      entity: PuzzleEntity(
        lichessPuzzleId: puzzleId,
        sourceFen: fen,
        setupMoveUci: setupMove,
        puzzleFen: puzzleFen,
        movesUci: moveList.join(' '),
        solutionMovesUci: moveList.skip(1).join(' '),
        solutionPlyCount: moveList.length - 1,
        playerColor: playerColor,
        rating: rating,
        ratingBucket: bucket,
        ratingDeviation: ratingDeviation,
        popularity: popularity,
        nbPlays: nbPlays,
        themes: themes,
        openingTags: openingTags,
        themeMaskLow: themeMask.low,
        themeMaskHigh: themeMask.high,
        randomKey: stableRandomKey(puzzleId, randomSeed),
        gameUrl: gameUrl,
      ),
      unknownThemes: themeMask.unknownThemes,
    );
  }
}

class PuzzleTransformResult {
  const PuzzleTransformResult({
    required this.entity,
    required this.unknownThemes,
  });

  final PuzzleEntity entity;
  final List<String> unknownThemes;
}

int stableRandomKey(String puzzleId, int seed) {
  // FNV-1a offset basis as signed 64-bit two's-complement value.
  // The unsigned value 14695981039346656037 is outside Dart's int range.
  const int offsetBasis = -3750763034362895579;
  const int prime = 1099511628211;
  const int mask64 = 0xFFFFFFFFFFFFFFFF;
  const int mask63 = 0x7FFFFFFFFFFFFFFF;

  var hash = (offsetBasis ^ seed) & mask64;
  for (final byte in utf8.encode(puzzleId)) {
    hash ^= byte;
    hash = (hash * prime) & mask64;
  }
  return hash & mask63;
}
