import 'package:flutter/material.dart';

import '../../controllers/puzzle_app_controller.dart';
import '../../domain/puzzle_mode.dart';

class PuzzleModeButtons extends StatelessWidget {
  const PuzzleModeButtons({
    super.key,
    required this.controller,
  });

  final PuzzleAppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: PuzzleMode.values.map((mode) {
        final selected = controller.mode == mode;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: selected
                    ? const Color(0xFF5C9DFF)
                    : const Color(0xFF202020),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withAlpha(90),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: selected
                        ? Colors.white.withAlpha(70)
                        : Colors.white.withAlpha(22),
                  ),
                ),
              ),
              onPressed: () => controller.setMode(mode),
              child: Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
