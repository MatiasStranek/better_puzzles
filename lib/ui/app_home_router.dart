import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/puzzle_app_controller.dart';
import 'desktop/pages/desktop_puzzle_page.dart';
import 'mobile/pages/mobile_puzzle_page.dart';

class AppHomeRouter extends StatelessWidget {
  const AppHomeRouter({
    super.key,
    required this.controller,
  });

  final PuzzleAppController controller;

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final isMobilePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    if (isMobilePlatform) {
      return MobilePuzzlePage(controller: controller);
    }

    return DesktopPuzzlePage(controller: controller);
  }
}
