import 'package:flutter/material.dart';

import '../../../controllers/puzzle_app_controller.dart';
import 'mobile_puzzle_more_sheet.dart';

class MobilePuzzleActionBar extends StatelessWidget {
  const MobilePuzzleActionBar({
    super.key,
    required this.height,
    required this.controller,
    required this.onMenuPressed,
    required this.isSideMenuOpen,
  });

  final double height;
  final PuzzleAppController controller;
  final VoidCallback onMenuPressed;
  final bool isSideMenuOpen;

  Future<void> _showMoreSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(160),
      builder: (context) {
        return MobilePuzzleMoreSheet(controller: controller);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSkip = controller.canSkipPuzzle && !controller.loadingPuzzle;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(28), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionBarButton(
              icon: isSideMenuOpen ? Icons.keyboard_arrow_left : Icons.menu,
              tooltip: isSideMenuOpen ? 'Menü schließen' : 'Menü öffnen',
              isEnabled: true,
              onPressed: onMenuPressed,
            ),
          ),
          Expanded(
            child: _ActionBarButton(
              icon: Icons.sync,
              tooltip: 'Brett drehen',
              isEnabled: true,
              onPressed: controller.flipBoard,
            ),
          ),
          const Expanded(
            child: _ActionBarButton(
              icon: Icons.keyboard_double_arrow_left,
              tooltip: 'Zurück kommt später',
              isEnabled: false,
            ),
          ),
          Expanded(
            child: _ActionBarButton(
              icon: Icons.skip_next_rounded,
              tooltip: canSkip
                  ? 'Puzzle überspringen'
                  : 'In diesem Modus nicht verfügbar',
              isEnabled: canSkip,
              onPressed: controller.skipCurrentPuzzle,
            ),
          ),
          Expanded(
            child: _ActionBarButton(
              icon: Icons.more_horiz,
              tooltip: 'Weitere Aktionen',
              isEnabled: true,
              onPressed: () => _showMoreSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBarButton extends StatelessWidget {
  const _ActionBarButton({
    required this.icon,
    required this.tooltip,
    required this.isEnabled,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isEnabled;
  final VoidCallback? onPressed;

  static const Color _activeColor = Color(0xFF5C9DFF);

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? _activeColor : Colors.white.withAlpha(76);

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: isEnabled ? onPressed : null,
        radius: 28,
        child: Center(child: Icon(icon, size: 32, color: color)),
      ),
    );
  }
}
