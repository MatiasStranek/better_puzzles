import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../controllers/puzzle_app_controller.dart';
import '../widgets/mobile_puzzle_action_bar.dart';
import '../widgets/mobile_puzzle_move_strip.dart';
import '../widgets/mobile_puzzle_side_menu.dart';
import '../widgets/mobile_puzzle_stats_panel.dart';
import '../widgets/mobile_puzzle_status_header.dart';
import '../widgets/chess_board/mobile_puzzle_board_view.dart';

class MobilePuzzleBoardLayout extends StatefulWidget {
  const MobilePuzzleBoardLayout({
    super.key,
    required this.controller,
  });

  final PuzzleAppController controller;

  @override
  State<MobilePuzzleBoardLayout> createState() =>
      _MobilePuzzleBoardLayoutState();
}

class _MobilePuzzleBoardLayoutState extends State<MobilePuzzleBoardLayout> {
  static const double _screenPadding = 16;
  static const double _statusHeaderHeight = 48;
  static const double _moveStripTop = 48;
  static const double _moveStripHeight = 54;
  static const double _statsPanelHeight = 70;
  static const double _actionBarHeight = 64;
  static const double _edgeSwipeWidth = 36;
  static const double _sideMenuWidthFactor = 0.72;
  static const double _swipeOpenThreshold = 54;
  static const double _swipeCloseThreshold = -54;

  bool _isSideMenuOpen = false;
  double _openSwipeDelta = 0;
  double _closeSwipeDelta = 0;

  void _openSideMenu() {
    if (_isSideMenuOpen) {
      return;
    }

    setState(() {
      _isSideMenuOpen = true;
    });
  }

  void _closeSideMenu() {
    if (!_isSideMenuOpen) {
      return;
    }

    setState(() {
      _isSideMenuOpen = false;
    });
  }

  void _toggleSideMenu() {
    setState(() {
      _isSideMenuOpen = !_isSideMenuOpen;
    });
  }

  void _handleOpenSwipeUpdate(DragUpdateDetails details) {
    _openSwipeDelta += details.delta.dx;

    if (_openSwipeDelta >= _swipeOpenThreshold) {
      _openSwipeDelta = 0;
      _openSideMenu();
    }
  }

  void _handleOpenSwipeEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dx > 500) {
      _openSideMenu();
    }

    _openSwipeDelta = 0;
  }

  void _handleCloseSwipeUpdate(DragUpdateDetails details) {
    _closeSwipeDelta += details.delta.dx;

    if (_closeSwipeDelta <= _swipeCloseThreshold) {
      _closeSwipeDelta = 0;
      _closeSideMenu();
    }
  }

  void _handleCloseSwipeEnd(DragEndDetails details) {
    if (details.velocity.pixelsPerSecond.dx < -500) {
      _closeSideMenu();
    }

    _closeSwipeDelta = 0;
  }

  Widget _buildClosedEdgeSwipeAreas({
    required double screenHeight,
    required double boardTop,
    required double boardBottom,
  }) {
    if (_isSideMenuOpen) {
      return const SizedBox.shrink();
    }

    final topStart = _moveStripTop + _moveStripHeight;
    final topHeight = math.max<double>(0.0, boardTop - topStart);
    final safeBottom = math.max<double>(0.0, screenHeight - _actionBarHeight);
    final bottomTop = math.min<double>(boardBottom, safeBottom);
    final bottomHeight = math.max<double>(0.0, safeBottom - bottomTop);

    return Stack(
      children: [
        if (topHeight > 0)
          Positioned(
            left: 0,
            top: topStart,
            width: _edgeSwipeWidth,
            height: topHeight,
            child: _EdgeSwipeDetector(
              onHorizontalDragUpdate: _handleOpenSwipeUpdate,
              onHorizontalDragEnd: _handleOpenSwipeEnd,
            ),
          ),
        if (bottomHeight > 0)
          Positioned(
            left: 0,
            top: bottomTop,
            width: _edgeSwipeWidth,
            height: bottomHeight,
            child: _EdgeSwipeDetector(
              onHorizontalDragUpdate: _handleOpenSwipeUpdate,
              onHorizontalDragEnd: _handleOpenSwipeEnd,
            ),
          ),
      ],
    );
  }

  double _topBetweenMoveStripAndBoard({
    required double boardTop,
    required double contentHeight,
  }) {
    const moveStripBottom = _moveStripTop + _moveStripHeight;
    final availableGap = boardTop - moveStripBottom - contentHeight;

    return moveStripBottom + math.max<double>(0.0, availableGap / 2.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - (_screenPadding * 2);
        final double boardSize = math.min<double>(
          constraints.maxWidth,
          availableHeight,
        );

        final boardTop = (constraints.maxHeight - boardSize) / 2.0;
        final boardBottom = boardTop + boardSize;
        final canShowActionBar = constraints.maxHeight >= _actionBarHeight;
        final sideMenuWidth = constraints.maxWidth * _sideMenuWidthFactor;
        final statsTop = _topBetweenMoveStripAndBoard(
          boardTop: boardTop,
          contentHeight: _statsPanelHeight,
        );

        return Stack(
          children: [
            Center(
              child: SizedBox.square(
                dimension: boardSize,
                child: MobilePuzzleBoardView(
                  playerIsWhite: widget.controller.playerIsWhite,
                  pieceCodeAt: widget.controller.pieceCodeAt,
                  highlights: widget.controller.highlights,
                  canHumanMovePiece: widget.controller.canHumanMovePiece,
                  canMoveTo: widget.controller.canMoveTo,
                  onSquareTap: widget.controller.tapSquare,
                  onMove: widget.controller.movePiece,
                  onPieceDragStarted: widget.controller.onPieceDragStarted,
                  onPieceDragEnded: widget.controller.onPieceDragEnded,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _statusHeaderHeight,
              child: MobilePuzzleStatusHeader(
                height: _statusHeaderHeight,
                statusText: widget.controller.statusText,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _moveStripTop,
              height: _moveStripHeight,
              child: MobilePuzzleMoveStrip(
                height: _moveStripHeight,
                text: widget.controller.moveStripText,
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: statsTop,
              height: _statsPanelHeight,
              child: MobilePuzzleStatsPanel(controller: widget.controller),
            ),
            if (canShowActionBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _actionBarHeight,
                child: MobilePuzzleActionBar(
                  height: _actionBarHeight,
                  controller: widget.controller,
                  onMenuPressed: _toggleSideMenu,
                  isSideMenuOpen: _isSideMenuOpen,
                ),
              ),
            _buildClosedEdgeSwipeAreas(
              screenHeight: constraints.maxHeight,
              boardTop: boardTop,
              boardBottom: boardBottom,
            ),
            if (_isSideMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeSideMenu,
                  onHorizontalDragUpdate: _handleCloseSwipeUpdate,
                  onHorizontalDragEnd: _handleCloseSwipeEnd,
                  child: ColoredBox(color: Colors.black.withAlpha(145)),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
              left: _isSideMenuOpen ? 0 : -sideMenuWidth,
              top: 0,
              bottom: 0,
              width: sideMenuWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _handleCloseSwipeUpdate,
                onHorizontalDragEnd: _handleCloseSwipeEnd,
                child: MobilePuzzleSideMenu(
                  width: sideMenuWidth,
                  controller: widget.controller,
                  onClose: _closeSideMenu,
                  isEnabled: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EdgeSwipeDetector extends StatelessWidget {
  const _EdgeSwipeDetector({
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
  });

  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      onHorizontalDragEnd: onHorizontalDragEnd,
      child: const SizedBox.expand(),
    );
  }
}
