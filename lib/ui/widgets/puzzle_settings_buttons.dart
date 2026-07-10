import 'package:flutter/material.dart';

import '../../controllers/puzzle_app_controller.dart';
import '../../domain/puzzle_range.dart';

class PuzzleSettingsButtons extends StatelessWidget {
  const PuzzleSettingsButtons({
    super.key,
    required this.controller,
  });

  final PuzzleAppController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SettingsButton(
            label: 'Range',
            onTap: () => _showRangeSheet(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SettingsButton(
            label: controller.randomMode ? 'Random: Ein' : 'Random: Aus',
            onTap: () => controller.setRandomMode(!controller.randomMode),
          ),
        ),
      ],
    );
  }

  Future<void> _showRangeSheet(BuildContext context) async {
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withAlpha(30)),
          backgroundColor: Colors.white.withAlpha(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
