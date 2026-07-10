import 'dart:io';

import 'package:puzzle_catalog_builder/src/arguments.dart';
import 'package:puzzle_catalog_builder/src/catalog_builder.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = CatalogBuildArguments.parse(arguments);
    if (options.showHelp) {
      stdout.writeln(CatalogBuildArguments.usage);
      return;
    }

    final result = await CatalogBuilder(options).build();
    stdout
      ..writeln()
      ..writeln('Fertig:')
      ..writeln('  Paket: ${result.packageFile.path}')
      ..writeln('  Catalog ID: ${result.catalogId}')
      ..writeln('  Puzzles: ${result.puzzleCount}')
      ..writeln('  Rating: ${result.minRating}–${result.maxRating}');
  } on FormatException catch (error) {
    stderr
      ..writeln('Eingabefehler: ${error.message}')
      ..writeln()
      ..writeln(CatalogBuildArguments.usage);
    exitCode = 64;
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln('Builder fehlgeschlagen: $error')
      ..writeln(stackTrace);
    exitCode = 1;
  }
}
