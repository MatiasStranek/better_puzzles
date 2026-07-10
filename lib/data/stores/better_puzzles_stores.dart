import 'package:bpuzzles_format/bpuzzles_format.dart';

import '../import/puzzle_database_import_service.dart';
import '../storage/puzzle_storage_layout.dart';
import 'puzzle_catalog_store_manager.dart';
import 'user_store_manager.dart';

class BetterPuzzlesStores {
  BetterPuzzlesStores._({
    required this.layout,
    required this.userStore,
    required this.catalogStore,
    required this.importService,
    required this.activeManifest,
  });

  final PuzzleStorageLayout layout;
  final UserStoreManager userStore;
  final PuzzleCatalogStoreManager catalogStore;
  final PuzzleDatabaseImportService importService;
  final BPuzzlesManifest? activeManifest;

  static Future<BetterPuzzlesStores> open() async {
    final layout = await PuzzleStorageLayout.fromApplicationSupport();
    await layout.ensureBaseDirectories();

    final userStore = UserStoreManager();
    await userStore.open(layout.userObjectBox);

    final catalogStore = PuzzleCatalogStoreManager();
    final importService = PuzzleDatabaseImportService(
      catalogStoreManager: catalogStore,
    );

    BPuzzlesManifest? activeManifest;
    try {
      activeManifest = await importService.openActiveCatalog();
    } on Object {
      // UserStore stays usable even when a catalog is missing or incompatible.
      activeManifest = null;
    }

    return BetterPuzzlesStores._(
      layout: layout,
      userStore: userStore,
      catalogStore: catalogStore,
      importService: importService,
      activeManifest: activeManifest,
    );
  }

  Future<void> close() async {
    await catalogStore.close();
    await userStore.close();
  }
}
