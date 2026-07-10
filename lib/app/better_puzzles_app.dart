import 'package:flutter/material.dart';

import '../controllers/puzzle_app_controller.dart';
import '../ui/app_home_router.dart';
import '../ui/shared/puzzle_palette.dart';

class BetterPuzzlesApp extends StatefulWidget {
  const BetterPuzzlesApp({super.key});

  @override
  State<BetterPuzzlesApp> createState() => _BetterPuzzlesAppState();
}

class _BetterPuzzlesAppState extends State<BetterPuzzlesApp> {
  late final PuzzleAppController controller = PuzzleAppController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better Puzzles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: PuzzlePalette.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PuzzlePalette.accent,
          brightness: Brightness.dark,
        ),
      ),
      home: AppHomeRouter(controller: controller),
    );
  }
}
