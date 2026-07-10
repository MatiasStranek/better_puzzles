import 'package:flutter/material.dart';

import '../../../widgets/puzzle_piece_visual.dart';

class MobilePuzzlePiece extends StatelessWidget {
  const MobilePuzzlePiece({
    super.key,
    required this.pieceCode,
  });

  final String pieceCode;

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/pieces/$pieceCode.svg';

    return PuzzlePieceVisual(
      assetPath: assetPath,
      keyValue: 'mobile-puzzle-$pieceCode-$assetPath',
    );
  }
}
