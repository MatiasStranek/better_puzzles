import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../models/board_highlights.dart';
import 'mobile_puzzle_board_square.dart';

class MobilePuzzleBoardView extends StatefulWidget {
  const MobilePuzzleBoardView({
    super.key,
    required this.playerIsWhite,
    required this.pieceCodeAt,
    required this.highlights,
    required this.canHumanMovePiece,
    required this.canMoveTo,
    required this.onSquareTap,
    required this.onMove,
    required this.onPieceDragStarted,
    required this.onPieceDragEnded,
  });

  final bool playerIsWhite;
  final String? Function(String square) pieceCodeAt;
  final BoardHighlights highlights;

  final bool Function(String square) canHumanMovePiece;
  final bool Function({required String from, required String to}) canMoveTo;
  final Future<void> Function(String square) onSquareTap;

  final Future<bool> Function({
    required String from,
    required String to,
    String? promotion,
  })
  onMove;

  final ValueChanged<String> onPieceDragStarted;
  final VoidCallback onPieceDragEnded;

  @override
  State<MobilePuzzleBoardView> createState() => _MobilePuzzleBoardViewState();
}

class _MobilePuzzleBoardViewState extends State<MobilePuzzleBoardView> {
  static const List<String> _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const double _dragHoverCircleRadiusInSquares = 1.0;

  String? _hoveredDragTargetSquare;

  String _squareForIndex(int index) {
    final row = index ~/ 8;
    final column = index % 8;

    final fileIndex = widget.playerIsWhite ? column : 7 - column;
    final rank = widget.playerIsWhite ? 8 - row : row + 1;

    return '${_files[fileIndex]}$rank';
  }

  bool _isLightSquare(String square) {
    final file = square.substring(0, 1);
    final rank = int.parse(square.substring(1, 2));
    final fileIndex = _files.indexOf(file);

    return (fileIndex + rank).isOdd;
  }

  Offset _squareCenter(String square, double squareSize) {
    final file = square.substring(0, 1);
    final rank = int.parse(square.substring(1, 2));
    final fileIndex = _files.indexOf(file);

    final column = widget.playerIsWhite ? fileIndex : 7 - fileIndex;
    final row = widget.playerIsWhite ? 8 - rank : rank - 1;

    return Offset((column + 0.5) * squareSize, (row + 0.5) * squareSize);
  }

  void _setHoveredDragTargetSquare(String? square) {
    if (_hoveredDragTargetSquare == square) {
      return;
    }

    setState(() {
      _hoveredDragTargetSquare = square;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.biggest.shortestSide;
        final squareSize = boardSize / 8.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(70),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: _buildBoardTextureLayer()),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _MobileBoardCoordinatePainter(
                        playerIsWhite: widget.playerIsWhite,
                      ),
                    ),
                  ),
                ),
                GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 64,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                  ),
                  itemBuilder: (context, index) {
                    final square = _squareForIndex(index);
                    final pieceCode = widget.pieceCodeAt(square);

                    return MobilePuzzleBoardSquare(
                      square: square,
                      isLightSquare: _isLightSquare(square),
                      pieceCode: pieceCode,
                      highlights: widget.highlights,
                      canDrag: widget.canHumanMovePiece(square),
                      canMoveTo: widget.canMoveTo,
                      onSquareTap: widget.onSquareTap,
                      onMove: widget.onMove,
                      onPieceDragStarted: widget.onPieceDragStarted,
                      onPieceDragEnded: widget.onPieceDragEnded,
                      onDragTargetHoverChanged: _setHoveredDragTargetSquare,
                    );
                  },
                ),
                if (_hoveredDragTargetSquare != null)
                  _MobileDragHoverCircle(
                    center: _squareCenter(
                      _hoveredDragTargetSquare!,
                      squareSize,
                    ),
                    radius: squareSize * _dragHoverCircleRadiusInSquares,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardTextureLayer() {
    return Image.asset(
      'assets/board/maple.jpg',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }
}

class _MobileBoardCoordinatePainter extends CustomPainter {
  const _MobileBoardCoordinatePainter({
    required this.playerIsWhite,
  });

  final bool playerIsWhite;

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = math.min(size.width, size.height);
    final squareSize = boardSize / 8.0;
    final fontSize = (squareSize * 0.15).clamp(7.0, 12.0).toDouble();
    final inset = (squareSize * 0.05).clamp(2.5, 5.0).toDouble();

    for (var row = 0; row < 8; row++) {
      final rank = playerIsWhite ? 8 - row : row + 1;
      final squareIsLight = _isDisplayedSquareLight(row: row, col: 7);
      final color = _coordinateColorForSquare(squareIsLight);
      final painter = _textPainter(
        text: '$rank',
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w900,
      )..layout();

      painter.paint(
        canvas,
        Offset(
          boardSize - painter.width - inset,
          row * squareSize + inset * 0.45,
        ),
      );
    }

    for (var col = 0; col < 8; col++) {
      final fileIndex = playerIsWhite ? col : 7 - col;
      final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
      final squareIsLight = _isDisplayedSquareLight(row: 7, col: col);
      final color = _coordinateColorForSquare(squareIsLight);
      final painter = _textPainter(
        text: file,
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w900,
      )..layout();

      painter.paint(
        canvas,
        Offset(
          col * squareSize + inset,
          boardSize - painter.height - inset * 0.35,
        ),
      );
    }
  }

  bool _isDisplayedSquareLight({
    required int row,
    required int col,
  }) {
    return (row + col).isEven;
  }

  Color _coordinateColorForSquare(bool squareIsLight) {
    if (squareIsLight) {
      return Colors.black.withAlpha(150);
    }

    return Colors.white.withAlpha(215);
  }

  TextPainter _textPainter({
    required String text,
    required double fontSize,
    required Color color,
    required FontWeight fontWeight,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 2),
            Shadow(color: Colors.white24, blurRadius: 1),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
  }

  @override
  bool shouldRepaint(covariant _MobileBoardCoordinatePainter oldDelegate) {
    return oldDelegate.playerIsWhite != playerIsWhite;
  }
}

class _MobileDragHoverCircle extends StatelessWidget {
  const _MobileDragHoverCircle({
    required this.center,
    required this.radius,
  });

  final Offset center;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.lightBlueAccent.withAlpha(34),
            border: Border.all(
              color: Colors.lightBlueAccent.withAlpha(125),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
