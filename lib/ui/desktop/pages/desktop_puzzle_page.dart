import 'package:flutter/material.dart';

import '../../../controllers/puzzle_app_controller.dart';
import '../../widgets/puzzle_chess_board.dart';
import '../../widgets/puzzle_sidebar.dart';

class DesktopPuzzlePage extends StatelessWidget {
  const DesktopPuzzlePage({
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: const Alignment(-0.10, 0.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 720,
                            maxHeight: 720,
                          ),
                          child: PuzzleChessBoard(controller: controller),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 340,
                      child: PuzzleSidebar(
                        controller: controller,
                        isMobile: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
