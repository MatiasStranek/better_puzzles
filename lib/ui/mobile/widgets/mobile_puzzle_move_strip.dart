import 'package:flutter/material.dart';

class MobilePuzzleMoveStrip extends StatelessWidget {
  const MobilePuzzleMoveStrip({
    super.key,
    required this.height,
    required this.text,
  });

  final double height;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF151515).withAlpha(220),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(210),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
