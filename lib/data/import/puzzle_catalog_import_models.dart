import 'dart:io';

import 'package:bpuzzles_format/bpuzzles_format.dart';

enum PuzzleCatalogImportPhase {
  inspecting,
  preparingStaging,
  copyingPackage,
  extracting,
  verifyingObjectBox,
  activating,
  openingCatalog,
  completed,
}

class PuzzleCatalogPackageInspection {
  const PuzzleCatalogPackageInspection({
    required this.packageFile,
    required this.manifest,
    required this.packageSizeBytes,
    required this.requiredTemporaryBytes,
    required this.errors,
  });

  final File packageFile;
  final BPuzzlesManifest manifest;
  final int packageSizeBytes;

  /// Conservative staging estimate: copied package plus extracted data.mdb.
  final int requiredTemporaryBytes;
  final List<String> errors;

  bool get isCompatible => errors.isEmpty;
}

class PuzzleCatalogImportEvent {
  const PuzzleCatalogImportEvent({
    required this.phase,
    required this.message,
    this.progress,
    this.result,
  });

  final PuzzleCatalogImportPhase phase;
  final String message;

  /// 0.0 to 1.0 where meaningful.
  final double? progress;
  final PuzzleDatabaseImportResult? result;
}

class PuzzleDatabaseImportResult {
  const PuzzleDatabaseImportResult({
    required this.targetDirectory,
    required this.message,
    this.manifest,
  });

  final Directory targetDirectory;
  final String message;
  final BPuzzlesManifest? manifest;
}
