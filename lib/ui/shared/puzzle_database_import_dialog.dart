import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../controllers/puzzle_app_controller.dart';
import '../../data/import/puzzle_catalog_import_models.dart';

Future<void> showPuzzleDatabaseImportDialog({
  required BuildContext context,
  required PuzzleAppController controller,
}) async {
  if (!controller.databaseReady) {
    await _showMessageDialog(
      context: context,
      title: 'App-Speicher noch nicht bereit',
      message: controller.databaseInitializationError ??
          'Die lokalen Datenbanken werden noch initialisiert. '
              'Bitte öffne den Datenbankdialog gleich noch einmal.',
    );
    return;
  }

  if (controller.databaseBusy) {
    await _showMessageDialog(
      context: context,
      title: 'Datenbankimport läuft',
      message: controller.databaseActivity,
    );
    return;
  }

  FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Better-Puzzles-Datenbank auswählen',
      type: FileType.custom,
      allowedExtensions: const <String>['bpuzzles'],
      allowMultiple: false,
      withData: false,
    );
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    await _showMessageDialog(
      context: context,
      title: 'Dateiauswahl fehlgeschlagen',
      message: error.toString(),
    );
    return;
  }

  if (picked == null || !context.mounted) {
    return;
  }

  final selected = picked.files.single;
  final packagePath = selected.path;
  if (packagePath == null || packagePath.isEmpty) {
    await _showMessageDialog(
      context: context,
      title: 'Datei nicht lesbar',
      message: 'Der Dateiauswahldialog hat keinen lokalen Dateipfad geliefert.',
    );
    return;
  }

  PuzzleCatalogPackageInspection inspection;
  try {
    inspection = await controller.inspectPuzzleCatalog(packagePath);
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    await _showMessageDialog(
      context: context,
      title: 'Ungültiges Datenbankpaket',
      message: error.toString(),
    );
    return;
  }

  if (!context.mounted) {
    return;
  }

  final alreadyActive = controller.databaseStatus.catalogId ==
      inspection.manifest.catalogId;
  final shouldImport = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return _PackageInspectionDialog(
        inspection: inspection,
        fileName: selected.name,
        alreadyActive: alreadyActive,
      );
    },
  );

  if (shouldImport != true || !context.mounted) {
    return;
  }

  final outcome = await showDialog<_ImportOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _ImportProgressDialog(
        controller: controller,
        packagePath: packagePath,
      );
    },
  );

  if (outcome == null || !context.mounted) {
    return;
  }

  if (outcome.error != null) {
    await _showMessageDialog(
      context: context,
      title: 'Import fehlgeschlagen',
      message: outcome.error.toString(),
    );
    return;
  }

  final result = outcome.result;
  await _showMessageDialog(
    context: context,
    title: 'Puzzle-Datenbank aktiv',
    message: result?.message ?? 'Der Puzzle-Katalog wurde importiert.',
  );
}

class _PackageInspectionDialog extends StatelessWidget {
  const _PackageInspectionDialog({
    required this.inspection,
    required this.fileName,
    required this.alreadyActive,
  });

  final PuzzleCatalogPackageInspection inspection;
  final String fileName;
  final bool alreadyActive;

  @override
  Widget build(BuildContext context) {
    final manifest = inspection.manifest;
    final canImport = inspection.isCompatible && !alreadyActive;

    return AlertDialog(
      title: const Text('Puzzle-Datenbank prüfen'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(label: 'Datei', value: fileName),
              _InfoRow(label: 'Katalog', value: manifest.displayName),
              _InfoRow(
                label: 'Puzzles',
                value: _formatCount(manifest.puzzleCount),
              ),
              _InfoRow(
                label: 'Rating',
                value: '${manifest.minRating}–${manifest.maxRating}',
              ),
              _InfoRow(
                label: 'Quelldatum',
                value: manifest.source.sourceDate,
              ),
              _InfoRow(
                label: 'Paketgröße',
                value: _formatBytes(inspection.packageSizeBytes),
              ),
              _InfoRow(
                label: 'Temporär benötigt',
                value: 'mindestens '
                    '${_formatBytes(inspection.requiredTemporaryBytes)}',
              ),
              const SizedBox(height: 14),
              Text(
                'Beim Import werden das Paket und die extrahierte '
                'ObjectBox-Datenbank vorübergehend gleichzeitig im '
                'App-Speicher gehalten. Die ausgewählte Quelldatei bleibt '
                'unverändert.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                const SizedBox(height: 10),
                Text(
                  'Android kann für die Dateiauswahl zusätzlich eine '
                  'temporäre Kopie anlegen. Plane deshalb deutlich mehr '
                  'freien Speicher als die Paketgröße ein.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ],
              if (inspection.errors.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Nicht kompatibel:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                for (final error in inspection.errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $error'),
                  ),
              ],
              if (alreadyActive) ...[
                const SizedBox(height: 14),
                const Text(
                  'Dieser Katalog ist bereits aktiv.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(canImport ? 'Abbrechen' : 'Schließen'),
        ),
        if (canImport)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.storage_rounded),
            label: const Text('Importieren'),
          ),
      ],
    );
  }
}

class _ImportProgressDialog extends StatefulWidget {
  const _ImportProgressDialog({
    required this.controller,
    required this.packagePath,
  });

  final PuzzleAppController controller;
  final String packagePath;

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(_runImport());
  }

  Future<void> _runImport() async {
    try {
      final result = await widget.controller.importPuzzleCatalog(
        widget.packagePath,
      );
      if (mounted) {
        Navigator.of(context).pop(_ImportOutcome.success(result));
      }
    } on Object catch (error) {
      if (mounted) {
        Navigator.of(context).pop(_ImportOutcome.failure(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Puzzle-Datenbank wird importiert'),
        content: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final progress = widget.controller.databaseImportProgress;
            final percent = progress == null ? null : (progress * 100).round();

            return SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text(widget.controller.databaseActivity),
                  if (percent != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$percent %',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Die App während des Imports geöffnet lassen. '
                    'Die Quelldatei wird nicht verändert.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImportOutcome {
  const _ImportOutcome._({this.result, this.error});

  factory _ImportOutcome.success(PuzzleDatabaseImportResult result) {
    return _ImportOutcome._(result: result);
  }

  factory _ImportOutcome.failure(Object error) {
    return _ImportOutcome._(error: error);
  }

  final PuzzleDatabaseImportResult? result;
  final Object? error;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

Future<void> _showMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: SelectableText(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

String _formatCount(int value) {
  final text = value.toString();
  final output = StringBuffer();

  for (var index = 0; index < text.length; index++) {
    final remaining = text.length - index;
    output.write(text[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      output.write('.');
    }
  }

  return output.toString();
}

String _formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final fractionDigits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
