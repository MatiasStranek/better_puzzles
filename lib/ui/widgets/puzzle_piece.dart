import 'package:flutter/material.dart';

import 'puzzle_piece_visual.dart';

class PuzzlePiece extends StatelessWidget {
  const PuzzlePiece({
    super.key,
    required this.piece,
  });

  final String piece;

  @override
  Widget build(BuildContext context) {
    final pieceCode = _pieceCode(piece);

    if (pieceCode == null) {
      return const SizedBox.shrink();
    }

    final assetPath = 'assets/pieces/$pieceCode.svg';

    return PuzzlePieceVisual(
      assetPath: assetPath,
      keyValue: 'puzzle-$pieceCode-$assetPath',
    );
  }

  String? _pieceCode(String fenPiece) {
    return switch (fenPiece) {
      'K' => 'wK',
      'Q' => 'wQ',
      'R' => 'wR',
      'B' => 'wB',
      'N' => 'wN',
      'P' => 'wP',
      'k' => 'bK',
      'q' => 'bQ',
      'r' => 'bR',
      'b' => 'bB',
      'n' => 'bN',
      'p' => 'bP',
      _ => null,
    };
  }
}
