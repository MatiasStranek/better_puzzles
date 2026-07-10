import 'dart:io';

class CatalogBuildArguments {
  const CatalogBuildArguments({
    required this.inputPath,
    required this.outputPath,
    required this.zstdExecutable,
    required this.sourceDate,
    required this.batchSize,
    required this.maxDbSizeKb,
    required this.ratingBucketSize,
    required this.randomSeed,
    required this.strict,
    required this.overwrite,
    required this.keepWork,
    required this.modelJsonPath,
    required this.workDirectoryPath,
    required this.errorLogPath,
    required this.limit,
    required this.showHelp,
    required this.commandText,
  });

  final String inputPath;
  final String outputPath;
  final String zstdExecutable;
  final String sourceDate;
  final int batchSize;
  final int maxDbSizeKb;
  final int ratingBucketSize;
  final int randomSeed;
  final bool strict;
  final bool overwrite;
  final bool keepWork;
  final String modelJsonPath;
  final String workDirectoryPath;
  final String errorLogPath;
  final int? limit;
  final bool showHelp;
  final String commandText;

  static CatalogBuildArguments parse(List<String> args) {
    if (args.contains('--help') || args.contains('-h')) {
      return CatalogBuildArguments(
        inputPath: '',
        outputPath: '',
        zstdExecutable: 'zstd',
        sourceDate: '',
        batchSize: 10000,
        maxDbSizeKb: 8 * 1024 * 1024,
        ratingBucketSize: 50,
        randomSeed: 0x42505A31,
        strict: false,
        overwrite: false,
        keepWork: false,
        modelJsonPath: '',
        workDirectoryPath: '',
        errorLogPath: '',
        limit: null,
        showHelp: true,
        commandText: args.join(' '),
      );
    }

    final values = <String, String>{};
    final flags = <String>{};

    for (var index = 0; index < args.length; index++) {
      final current = args[index];
      if (!current.startsWith('--')) {
        throw FormatException('Unerwartetes Argument: $current');
      }

      if (_flagNames.contains(current)) {
        flags.add(current);
        continue;
      }

      if (!_valueNames.contains(current)) {
        throw FormatException('Unbekannte Option: $current');
      }
      if (index + 1 >= args.length) {
        throw FormatException('Wert für $current fehlt');
      }
      values[current] = args[++index];
    }

    final input = values['--input'];
    final output = values['--output'];
    if (input == null || input.isEmpty) {
      throw const FormatException('--input fehlt');
    }
    if (output == null || output.isEmpty) {
      throw const FormatException('--output fehlt');
    }
    if (!output.toLowerCase().endsWith('.bpuzzles')) {
      throw const FormatException('--output muss auf .bpuzzles enden');
    }

    final sourceDate = values['--source-date'] ?? _todayUtc();
    if (DateTime.tryParse(sourceDate) == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(sourceDate)) {
      throw FormatException('--source-date muss YYYY-MM-DD sein: $sourceDate');
    }

    final outputFile = File(output).absolute;
    final defaultWork =
        '${outputFile.path.substring(0, outputFile.path.length - 9)}.work';

    return CatalogBuildArguments(
      inputPath: File(input).absolute.path,
      outputPath: outputFile.path,
      zstdExecutable: values['--zstd'] ?? 'zstd',
      sourceDate: sourceDate,
      batchSize: _positiveInt(values, '--batch-size', 10000),
      maxDbSizeKb: _positiveInt(values, '--max-db-size-kb', 8 * 1024 * 1024),
      ratingBucketSize: _positiveInt(values, '--rating-bucket-size', 50),
      randomSeed: _integer(values, '--random-seed', 0x42505A31),
      strict: flags.contains('--strict'),
      overwrite: flags.contains('--overwrite'),
      keepWork: flags.contains('--keep-work'),
      modelJsonPath: File(
        values['--model-json'] ??
            '../../packages/puzzle_catalog_store/lib/objectbox-model.json',
      ).absolute.path,
      workDirectoryPath: Directory(
        values['--work-dir'] ?? defaultWork,
      ).absolute.path,
      errorLogPath: File(
        values['--error-log'] ?? '${outputFile.path}.errors.tsv',
      ).absolute.path,
      limit: values.containsKey('--limit')
          ? _positiveInt(values, '--limit', 0)
          : null,
      showHelp: false,
      commandText: args.join(' '),
    );
  }

  static const Set<String> _flagNames = <String>{
    '--strict',
    '--overwrite',
    '--keep-work',
  };

  static const Set<String> _valueNames = <String>{
    '--input',
    '--output',
    '--zstd',
    '--source-date',
    '--batch-size',
    '--max-db-size-kb',
    '--rating-bucket-size',
    '--random-seed',
    '--model-json',
    '--work-dir',
    '--error-log',
    '--limit',
  };

  static int _positiveInt(
    Map<String, String> values,
    String key,
    int defaultValue,
  ) {
    final value = _integer(values, key, defaultValue);
    if (value <= 0) {
      throw FormatException('$key muss größer als 0 sein');
    }
    return value;
  }

  static int _integer(
    Map<String, String> values,
    String key,
    int defaultValue,
  ) {
    final raw = values[key];
    if (raw == null) {
      return defaultValue;
    }
    final value = int.tryParse(raw);
    if (value == null) {
      throw FormatException('$key ist keine Ganzzahl: $raw');
    }
    return value;
  }

  static String _todayUtc() {
    final now = DateTime.now().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  static const String usage = r'''
Better Puzzles - Lichess-Katalog-Builder

Aufruf aus tools\puzzle_catalog_builder:

  dart run bin\build_catalog.dart ^
    --input "D:\lichess\lichess_db_puzzle.csv.zst" ^
    --output "D:\lichess\lichess_puzzles_2026_07.bpuzzles" ^
    --source-date 2026-07-01

Pflicht:
  --input PATH                 lichess_db_puzzle.csv.zst
  --output PATH                Ziel mit Endung .bpuzzles

Optionen:
  --zstd PATH                  zstd-Programm, Standard: zstd
  --source-date YYYY-MM-DD     Stand der Quelldatei
  --batch-size N               ObjectBox-Batch, Standard: 10000
  --max-db-size-kb N           ObjectBox-Limit, Standard: 8388608
  --rating-bucket-size N       Standard: 50
  --random-seed N              Seed für deterministische randomKey-Werte
  --limit N                    Nur N Puzzles bauen (Testlauf)
  --strict                     Bei erster fehlerhafter Zeile abbrechen
  --overwrite                  Vorhandene Ausgabe/Arbeitsdaten ersetzen
  --keep-work                  ObjectBox-Arbeitsordner behalten
  --model-json PATH            ObjectBox-Metamodell
  --work-dir PATH              Arbeitsordner
  --error-log PATH             TSV für verworfene Zeilen
  --help                       Diese Hilfe
''';
}
