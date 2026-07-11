import 'package:flutter/material.dart';

import '../../../controllers/puzzle_app_controller.dart';
import '../../../domain/puzzle_mode.dart';

class MobilePuzzleStatsPanel extends StatelessWidget {
  const MobilePuzzleStatsPanel({super.key, required this.controller});

  final PuzzleAppController controller;

  @override
  Widget build(BuildContext context) {
    final timerIsUrgent =
        controller.mode == PuzzleMode.storm &&
        controller.stormStarted &&
        controller.stormRemainingSeconds <= 15;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111111).withAlpha(210),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _Metric(
            label: controller.primaryMetricLabel,
            value: controller.primaryMetricValue,
            valueColor: timerIsUrgent ? const Color(0xFFFF6B6B) : null,
          ),
          _Metric(
            label: controller.secondaryMetricLabel,
            value: controller.secondaryMetricValue,
          ),
          _Metric(
            label: controller.tertiaryMetricLabel,
            value: controller.tertiaryMetricValue,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withAlpha(120),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
