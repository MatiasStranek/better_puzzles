import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/puzzle_app_controller.dart';
import '../data/stores/better_puzzles_stores.dart';
import '../ui/app_home_router.dart';
import '../ui/shared/puzzle_palette.dart';

class BetterPuzzlesApp extends StatefulWidget {
  const BetterPuzzlesApp({super.key});

  @override
  State<BetterPuzzlesApp> createState() => _BetterPuzzlesAppState();
}

class _BetterPuzzlesAppState extends State<BetterPuzzlesApp> {
  late final PuzzleAppController controller;
  BetterPuzzlesStores? _stores;

  @override
  void initState() {
    super.initState();
    controller = PuzzleAppController();
    unawaited(_openStores());
  }

  Future<void> _openStores() async {
    try {
      final stores = await BetterPuzzlesStores.open();

      if (!mounted) {
        await stores.close();
        return;
      }

      _stores = stores;
      await controller.attachStores(stores);
    } on Object catch (error) {
      if (mounted) {
        controller.setDatabaseInitializationError(error);
      }
    }
  }

  @override
  void dispose() {
    final stores = _stores;
    _stores = null;

    if (stores != null) {
      unawaited(stores.close());
    }

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
