import 'package:flutter/material.dart';

import '../../../controllers/puzzle_app_controller.dart';
import '../layouts/mobile_puzzle_board_layout.dart';

class MobilePuzzlePage extends StatelessWidget {
  const MobilePuzzlePage({
    super.key,
    required this.controller,
  });

  final PuzzleAppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF050505), Color(0xFF111111)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: MobilePuzzleBoardLayout(controller: controller),
            ),
          );
        },
      ),
    );
  }
}
