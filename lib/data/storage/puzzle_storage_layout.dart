import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PuzzleStorageLayout {
  PuzzleStorageLayout._(this.root);

  final Directory root;

  Directory get catalogsRoot => Directory(p.join(root.path, 'catalogs'));
  Directory get installedCatalogs =>
      Directory(p.join(catalogsRoot.path, 'installed'));
  Directory get stagingCatalogs =>
      Directory(p.join(catalogsRoot.path, 'staging'));
  File get activeCatalogFile =>
      File(p.join(catalogsRoot.path, 'active_catalog.json'));

  Directory get userRoot => Directory(p.join(root.path, 'user'));
  Directory get userObjectBox => Directory(p.join(userRoot.path, 'objectbox'));

  static Future<PuzzleStorageLayout> fromApplicationSupport() async {
    final support = await getApplicationSupportDirectory();
    return PuzzleStorageLayout._(
      Directory(p.join(support.path, 'better_puzzles')),
    );
  }

  static PuzzleStorageLayout forRoot(Directory root) {
    return PuzzleStorageLayout._(root);
  }

  Directory installedCatalog(String catalogId) =>
      Directory(p.join(installedCatalogs.path, catalogId));

  Directory catalogObjectBox(Directory catalogDirectory) =>
      Directory(p.join(catalogDirectory.path, 'objectbox'));

  File catalogManifest(Directory catalogDirectory) =>
      File(p.join(catalogDirectory.path, 'manifest.json'));

  Future<void> ensureBaseDirectories() async {
    await installedCatalogs.create(recursive: true);
    await stagingCatalogs.create(recursive: true);
    await userObjectBox.create(recursive: true);
  }

  Future<ActiveCatalogReference?> readActiveCatalog() async {
    if (!await activeCatalogFile.exists()) {
      return null;
    }

    final decoded = jsonDecode(await activeCatalogFile.readAsString());
    if (decoded is! Map) {
      throw const FormatException('active_catalog.json ist kein JSON-Objekt');
    }

    final map = decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    return ActiveCatalogReference.fromJson(map);
  }

  Future<void> writeActiveCatalog(ActiveCatalogReference reference) async {
    await activeCatalogFile.parent.create(recursive: true);
    final temporary = File('${activeCatalogFile.path}.tmp');

    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(reference.toJson()),
      flush: true,
    );

    if (await activeCatalogFile.exists()) {
      await activeCatalogFile.delete();
    }
    await temporary.rename(activeCatalogFile.path);
  }

  Future<void> clearActiveCatalog() async {
    if (await activeCatalogFile.exists()) {
      await activeCatalogFile.delete();
    }
  }
}

class ActiveCatalogReference {
  const ActiveCatalogReference({
    required this.catalogId,
    required this.activatedAtUtc,
  });

  final String catalogId;
  final String activatedAtUtc;

  factory ActiveCatalogReference.fromJson(Map<String, Object?> json) {
    final catalogId = json['catalogId']?.toString() ?? '';
    final activatedAtUtc = json['activatedAtUtc']?.toString() ?? '';

    if (!RegExp(r'^[A-Za-z0-9._-]{3,120}$').hasMatch(catalogId)) {
      throw FormatException('Ungültige aktive catalogId: $catalogId');
    }
    if (DateTime.tryParse(activatedAtUtc) == null) {
      throw const FormatException('Ungültiger activatedAtUtc-Zeitpunkt');
    }

    return ActiveCatalogReference(
      catalogId: catalogId,
      activatedAtUtc: activatedAtUtc,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'catalogId': catalogId,
    'activatedAtUtc': activatedAtUtc,
  };
}
