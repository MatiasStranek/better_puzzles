import 'package:flutter/material.dart';

import '../../../controllers/puzzle_app_controller.dart';
import '../../../domain/puzzle_mode.dart';
import '../../../domain/puzzle_range.dart';
import '../../shared/puzzle_database_import_dialog.dart';

class MobilePuzzleSideMenu extends StatelessWidget {
  const MobilePuzzleSideMenu({
    super.key,
    required this.width,
    required this.controller,
    required this.onClose,
    this.isEnabled = true,
  });

  final double width;
  final PuzzleAppController controller;
  final VoidCallback onClose;
  final bool isEnabled;

  void _setMode(PuzzleMode mode) {
    if (!isEnabled) return;
    controller.setMode(mode);
    onClose();
  }

  Future<void> _showRangeDialog(BuildContext context) async {
    if (!isEnabled) return;
    var min = controller.range.minRating;
    var max = controller.range.maxRating;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(160),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                    onChanged: (value) => setModalState(() {
                      min = value.round();
                      if (min > max) max = min;
                    }),
                  ),
                  _RangeValue(label: 'Max', value: max),
                  Slider(
                    value: max.toDouble(),
                    min: 400,
                    max: 3000,
                    divisions: 26,
                    label: '$max',
                    onChanged: (value) => setModalState(() {
                      max = value.round();
                      if (max < min) min = max;
                    }),
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
        ),
      ),
    );
  }

  List<Widget> _modeControls(BuildContext context) {
    switch (controller.mode) {
      case PuzzleMode.tasks:
        return [
          _SideMenuButton(
            icon: controller.ratedTasks
                ? Icons.verified_rounded
                : Icons.tune_rounded,
            label: 'Aufgabenwertung',
            value: controller.ratedTasks
                ? 'Gewertet · ${controller.localRatingLabel}'
                : 'Freies Training',
            onTap: () => controller.setRatedTasks(!controller.ratedTasks),
            isEnabled: isEnabled,
            isHighlighted: controller.ratedTasks,
          ),
          if (controller.ratedTasks)
            _SideMenuButton(
              icon: Icons.trending_up_rounded,
              label: 'Schwierigkeit',
              value: controller.difficulty.detailLabel,
              onTap: controller.cycleDifficulty,
              isEnabled: isEnabled,
            )
          else ...[
            _SideMenuButton(
              icon: Icons.speed,
              label: 'Range',
              value: controller.range.label,
              onTap: () => _showRangeDialog(context),
              isEnabled: isEnabled,
            ),
            _SideMenuButton(
              icon: Icons.shuffle,
              label: 'Random',
              value: controller.randomMode
                  ? 'Zufällig pro Puzzle'
                  : 'Aufsteigend',
              onTap: () => controller.setRandomMode(!controller.randomMode),
              isEnabled: isEnabled,
            ),
          ],
        ];
      case PuzzleMode.streak:
        return [
          _SideMenuButton(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            value: '${controller.streak} · Best ${controller.streakBest}',
            onTap: null,
            isEnabled: isEnabled,
            isHighlighted: true,
          ),
          _SideMenuButton(
            icon: Icons.info_outline_rounded,
            label: 'Regel',
            value: 'Ein Fehler beendet den Lauf',
            onTap: null,
            isEnabled: isEnabled,
          ),
        ];
      case PuzzleMode.storm:
        return [
          _SideMenuButton(
            icon: Icons.timer_rounded,
            label: 'Zeit',
            value: controller.stormTimeText,
            onTap: null,
            isEnabled: isEnabled,
            isHighlighted: true,
          ),
          _SideMenuButton(
            icon: Icons.bolt_rounded,
            label: 'Storm',
            value:
                '${controller.score} gelöst · Combo ${controller.combo} · ${controller.mistakes} Fehler',
            onTap: null,
            isEnabled: isEnabled,
          ),
          _SideMenuButton(
            icon: Icons.emoji_events_rounded,
            label: 'Bestwerte',
            value:
                'Score ${controller.stormBest} · Combo ${controller.stormBestCombo}',
            onTap: null,
            isEnabled: isEnabled,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = controller.currentPuzzle;

    return SizedBox(
      width: width,
      height: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF171717),
          image: DecorationImage(
            image: AssetImage('assets/background/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withAlpha(80),
          child: IgnorePointer(
            ignoring: !isEnabled,
            child: Opacity(
              opacity: isEnabled ? 1 : 0.65,
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
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._modeControls(context),
                            _SideMenuButton(
                              icon: Icons.analytics_rounded,
                              label: controller.primaryMetricLabel,
                              value:
                                  '${controller.primaryMetricValue} · ${controller.secondaryMetricLabel} ${controller.secondaryMetricValue} · ${controller.tertiaryMetricLabel} ${controller.tertiaryMetricValue}',
                              onTap: null,
                              isEnabled: isEnabled,
                            ),
                            _SideMenuButton(
                              icon: Icons.storage_rounded,
                              label: 'Datenbank',
                              value: controller.databaseBusy
                                  ? controller.databaseActivity
                                  : controller.databaseStatus.countLabel,
                              onTap: () async {
                                await showPuzzleDatabaseImportDialog(
                                  context: context,
                                  controller: controller,
                                );
                              },
                              isEnabled: isEnabled,
                            ),
                            if (puzzle != null) ...[
                              _SideMenuButton(
                                icon: Icons.extension_rounded,
                                label: 'Aktuelles Puzzle',
                                value:
                                    '${puzzle.lichessPuzzleId} · ${puzzle.rating} · ${controller.lastQueryDurationMs}ms',
                                onTap: null,
                                isEnabled: isEnabled,
                              ),
                              _SideMenuButton(
                                icon: Icons.sell_rounded,
                                label: 'Themes',
                                value: puzzle.themes,
                                onTap: null,
                                isEnabled: isEnabled,
                              ),
                            ],
                            if (controller.runEnded)
                              _SideMenuButton(
                                icon: Icons.restart_alt_rounded,
                                label: 'Neuer Lauf',
                                value: controller.feedbackText,
                                onTap: controller.resetRun,
                                isEnabled: isEnabled,
                                isHighlighted: true,
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
                      value: 'Training mit optionaler Wertung',
                      onTap: () => _setMode(PuzzleMode.tasks),
                      isEnabled: isEnabled,
                      isHighlighted: controller.mode == PuzzleMode.tasks,
                    ),
                    _SideMenuButton(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Puzzle Streak',
                      value: 'Ein Fehler beendet die Serie',
                      onTap: () => _setMode(PuzzleMode.streak),
                      isEnabled: isEnabled,
                      isHighlighted: controller.mode == PuzzleMode.streak,
                    ),
                    _SideMenuButton(
                      icon: Icons.flash_on_rounded,
                      label: 'Puzzle Storm',
                      value: '3 Minuten · Combo-Zeitboni',
                      onTap: () => _setMode(PuzzleMode.storm),
                      isEnabled: isEnabled,
                      isHighlighted: controller.mode == PuzzleMode.storm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeValue extends StatelessWidget {
  const _RangeValue({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 46, child: Icon(icon, size: 28, color: color)),
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
                      fontSize: 17,
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
