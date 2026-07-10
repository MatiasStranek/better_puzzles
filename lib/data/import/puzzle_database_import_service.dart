import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PuzzleDatabaseImportResult {
  const PuzzleDatabaseImportResult({
    required this.targetDirectory,
    required this.message,
  });

  final Directory targetDirectory;
  final String message;
}

class PuzzleDatabaseImportService {
  const PuzzleDatabaseImportService();

  Future<Directory> getAppDatabaseRoot() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'better_puzzles_databases'));
  }

  Future<Directory> getCatalogDirectory() async {
    final root = await getAppDatabaseRoot();
    return Directory(p.join(root.path, 'catalog'));
  }

  Future<Directory> getUserDataDirectory() async {
    final root = await getAppDatabaseRoot();
    return Directory(p.join(root.path, 'user_data'));
  }

  Future<PuzzleDatabaseImportResult> prepareEmptyCatalogFolder() async {
    final catalog = await getCatalogDirectory();

    if (!await catalog.exists()) {
      await catalog.create(recursive: true);
    }

    return PuzzleDatabaseImportResult(
      targetDirectory: catalog,
      message: 'Katalog-Ordner vorbereitet: ${catalog.path}',
    );
  }
}
