import 'package:flutter/material.dart';

import '../../../controllers/puzzle_app_controller.dart';
import '../../shared/puzzle_database_import_dialog.dart';

class MobilePuzzleMoreSheet extends StatelessWidget {
  const MobilePuzzleMoreSheet({super.key, required this.controller});

  final PuzzleAppController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withAlpha(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(150),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Weitere Aktionen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _SheetButton(
                icon: Icons.refresh,
                label: controller.runEnded
                    ? '${controller.mode.shortLabel} neu starten'
                    : 'Run zurücksetzen',
                onTap: () {
                  controller.resetRun();
                  Navigator.of(context).pop();
                },
              ),
              _SheetButton(
                icon: Icons.storage_rounded,
                label: 'Puzzle-Datenbank importieren',
                onTap: () async {
                  await showPuzzleDatabaseImportDialog(
                    context: context,
                    controller: controller,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              if (controller.canSkipPuzzle)
                _SheetButton(
                  icon: Icons.skip_next_rounded,
                  label: 'Puzzle überspringen',
                  onTap: () {
                    controller.skipCurrentPuzzle();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withAlpha(28)),
            backgroundColor: Colors.white.withAlpha(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
