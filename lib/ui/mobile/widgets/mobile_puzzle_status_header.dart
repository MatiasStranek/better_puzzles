import 'package:flutter/material.dart';

class MobilePuzzleStatusHeader extends StatelessWidget {
  const MobilePuzzleStatusHeader({
    super.key,
    required this.height,
    required this.statusText,
  });

  final double height;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111111).withAlpha(220),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(22)),
          ),
          child: Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
