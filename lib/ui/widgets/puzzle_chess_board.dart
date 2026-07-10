import 'package:flutter/material.dart';

import '../../controllers/puzzle_app_controller.dart';
import '../mobile/widgets/chess_board/mobile_puzzle_board_view.dart';

class PuzzleChessBoard extends StatelessWidget {
  const PuzzleChessBoard({
    super.key,
    required this.controller,
  });

  final PuzzleAppController controller;

  @override
  Widget build(BuildContext context) {
    return MobilePuzzleBoardView(
      playerIsWhite: controller.playerIsWhite,
      pieceCodeAt: controller.pieceCodeAt,
      highlights: controller.highlights,
      canHumanMovePiece: controller.canHumanMovePiece,
      canMoveTo: controller.canMoveTo,
      onSquareTap: controller.tapSquare,
      onMove: controller.movePiece,
      onPieceDragStarted: controller.onPieceDragStarted,
      onPieceDragEnded: controller.onPieceDragEnded,
    );
  }
}
