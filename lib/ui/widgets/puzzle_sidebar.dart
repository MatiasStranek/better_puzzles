import 'package:flutter/material.dart';

import '../../controllers/puzzle_app_controller.dart';
import '../../domain/puzzle_mode.dart';
import '../../domain/puzzle_range.dart';

class PuzzleSidebar extends StatelessWidget {
  const PuzzleSidebar({
    super.key,
    required this.controller,
    required this.isMobile,
  });

  final PuzzleAppController controller;
  final bool isMobile;

  Future<void> _showRangeDialog(BuildContext context) async {
    var min = controller.range.minRating;
    var max = controller.range.maxRating;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(160),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
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
                        'Rating Range',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _RangeValue(label: 'Min', value: min),
                      Slider(
                        value: min.toDouble(),
                        min: 400,
                        max: 3000,
                        divisions: 26,
                        label: '$min',
                        onChanged: (value) {
                          setModalState(() {
                            min = value.round();
                            if (min > max) {
                              max = min;
                            }
                          });
                        },
                      ),
                      _RangeValue(label: 'Max', value: max),
                      Slider(
                        value: max.toDouble(),
                        min: 400,
                        max: 3000,
                        divisions: 26,
                        label: '$max',
                        onChanged: (value) {
                          setModalState(() {
                            max = value.round();
                            if (max < min) {
                              min = max;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () {
                            controller.setRange(
                              PuzzleRange(minRating: min, maxRating: max),
                            );
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Übernehmen',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = controller.currentPuzzle;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF171717),
        image: DecorationImage(
          image: AssetImage('assets/background/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: Colors.black.withAlpha(80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              const Center(child: FlutterLogo(size: 72)),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Better Puzzles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SideMenuButton(
                        icon: Icons.speed,
                        label: 'Range',
                        value: controller.range.label,
                        onTap: () => _showRangeDialog(context),
                        isEnabled: true,
                        isHighlighted: true,
                      ),
                      _SideMenuButton(
                        icon: Icons.shuffle,
                        label: 'Random',
                        value: controller.randomMode
                            ? 'Zufällig pro Puzzle'
                            : 'Aufsteigend',
                        onTap: () {
                          controller.setRandomMode(!controller.randomMode);
                        },
                        isEnabled: true,
                      ),
                      _SideMenuButton(
                        icon: Icons.storage_rounded,
                        label: 'Datenbank',
                        value: controller.databaseStatus.countLabel,
                        onTap: () {
                          controller.prepareDatabaseFolder();
                        },
                        isEnabled: true,
                      ),
                      if (puzzle != null) ...[
                        _SideMenuButton(
                          icon: Icons.extension_rounded,
                          label: 'Aktuelles Puzzle',
                          value: '${puzzle.lichessPuzzleId} · ${puzzle.rating}',
                          onTap: null,
                          isEnabled: true,
                        ),
                        _SideMenuButton(
                          icon: Icons.sell_rounded,
                          label: 'Themes',
                          value: puzzle.themes,
                          onTap: null,
                          isEnabled: true,
                        ),
                      ],
                      _SideMenuButton(
                        icon: Icons.leaderboard_rounded,
                        label: 'Score',
                        value:
                            '${controller.score} · Streak ${controller.streak} · Fehler ${controller.mistakes}',
                        onTap: null,
                        isEnabled: true,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: Colors.white.withAlpha(55), height: 24),
              const SizedBox(height: 6),
              _SideMenuButton(
                icon: Icons.task_alt_rounded,
                label: 'Aufgaben',
                value: 'Normaler Puzzle-Modus',
                onTap: () => controller.setMode(PuzzleMode.tasks),
                isEnabled: true,
                isHighlighted: controller.mode == PuzzleMode.tasks,
              ),
              _SideMenuButton(
                icon: Icons.local_fire_department_rounded,
                label: 'Puzzle Streak',
                value: 'Serie ohne Zeitdruck',
                onTap: () => controller.setMode(PuzzleMode.streak),
                isEnabled: true,
                isHighlighted: controller.mode == PuzzleMode.streak,
              ),
              _SideMenuButton(
                icon: Icons.flash_on_rounded,
                label: 'Puzzle Storm',
                value: 'Zeitmodus',
                onTap: () => controller.setMode(PuzzleMode.storm),
                isEnabled: true,
                isHighlighted: controller.mode == PuzzleMode.storm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeValue extends StatelessWidget {
  const _RangeValue({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(150),
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SideMenuButton extends StatelessWidget {
  const _SideMenuButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.isEnabled,
    this.isHighlighted = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isEnabled;
  final bool isHighlighted;
  final VoidCallback? onTap;

  static const Color _accentColor = Color(0xFF5C9DFF);

  @override
  Widget build(BuildContext context) {
    final color = isEnabled
        ? isHighlighted
            ? _accentColor
            : Colors.white
        : Colors.white.withAlpha(76);

    final valueColor = isEnabled
        ? Colors.white.withAlpha(170)
        : Colors.white.withAlpha(76);

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
