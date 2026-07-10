class BPuzzlesManifest {
  const BPuzzlesManifest({
    required this.format,
    required this.formatVersion,
    required this.catalogSchemaVersion,
    required this.catalogId,
    required this.displayName,
    required this.createdAtUtc,
    required this.source,
    required this.generator,
    required this.database,
    required this.statistics,
    required this.ratingBuckets,
    required this.themes,
  });

  static const String supportedFormat = 'better_puzzles.catalog';
  static const int supportedFormatVersion = 1;
  static const int supportedCatalogSchemaVersion = 1;

  final String format;
  final int formatVersion;
  final int catalogSchemaVersion;
  final String catalogId;
  final String displayName;
  final String createdAtUtc;
  final BPuzzlesSourceInfo source;
  final BPuzzlesGeneratorInfo generator;
  final BPuzzlesDatabaseInfo database;
  final BPuzzlesStatistics statistics;
  final BPuzzlesRatingBuckets ratingBuckets;
  final BPuzzlesThemeInfo themes;

  int get puzzleCount => statistics.puzzleCount;
  int get minRating => statistics.minRating;
  int get maxRating => statistics.maxRating;

  List<String> validate({
    String? expectedModelFingerprint,
    int maxSupportedCatalogSchemaVersion = supportedCatalogSchemaVersion,
  }) {
    final errors = <String>[];

    if (format != supportedFormat) {
      errors.add('Unbekanntes Format: $format');
    }
    if (formatVersion != supportedFormatVersion) {
      errors.add(
        'Nicht unterstützte Formatversion: $formatVersion '
        '(erwartet $supportedFormatVersion)',
      );
    }
    if (catalogSchemaVersion < 1 ||
        catalogSchemaVersion > maxSupportedCatalogSchemaVersion) {
      errors.add(
        'Nicht unterstützte Katalog-Schemaversion: '
        '$catalogSchemaVersion',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._-]{3,120}$').hasMatch(catalogId)) {
      errors.add('Ungültige catalogId: $catalogId');
    }
    if (displayName.trim().isEmpty) {
      errors.add('displayName fehlt');
    }
    if (DateTime.tryParse(createdAtUtc) == null) {
      errors.add('createdAtUtc ist kein gültiger ISO-8601-Zeitpunkt');
    }
    if (database.engine != 'objectbox') {
      errors.add('Nicht unterstützte Datenbank: ${database.engine}');
    }
    if (database.entry != 'objectbox/data.mdb') {
      errors.add('Unerwarteter Datenbankpfad: ${database.entry}');
    }
    if (!RegExp(
      r'^[0-9a-f]{64}$',
    ).hasMatch(database.catalogModelFingerprint.toLowerCase())) {
      errors.add('database.catalogModelFingerprint ist ungültig');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(database.sha256.toLowerCase())) {
      errors.add('database.sha256 ist ungültig');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(source.sha256.toLowerCase())) {
      errors.add('source.sha256 ist ungültig');
    }
    if (!RegExp(
      r'^[0-9a-f]{64}$',
    ).hasMatch(themes.dictionarySha256.toLowerCase())) {
      errors.add('themes.dictionarySha256 ist ungültig');
    }
    if (database.sizeBytes <= 0) {
      errors.add('database.sizeBytes muss größer als 0 sein');
    }
    if (database.requiredMaxDbSizeKb <= 0) {
      errors.add('database.requiredMaxDbSizeKb muss größer als 0 sein');
    } else if (database.requiredMaxDbSizeKb * 1024 < database.sizeBytes) {
      errors.add('requiredMaxDbSizeKb ist kleiner als die Datenbankdatei');
    }
    if (statistics.puzzleCount <= 0) {
      errors.add('puzzleCount muss größer als 0 sein');
    }
    if (statistics.minRating > statistics.maxRating) {
      errors.add('minRating ist größer als maxRating');
    }
    if (statistics.whiteToMoveCount + statistics.blackToMoveCount !=
        statistics.puzzleCount) {
      errors.add('Farbstatistik stimmt nicht mit puzzleCount überein');
    }
    if (ratingBuckets.size <= 0) {
      errors.add('ratingBuckets.size muss größer als 0 sein');
    }
    if (themes.maskBits != 126) {
      errors.add('Diese App erwartet 126 Theme-Bits');
    }
    if (expectedModelFingerprint != null &&
        expectedModelFingerprint.isNotEmpty &&
        expectedModelFingerprint != 'UNGENERATED' &&
        database.catalogModelFingerprint != expectedModelFingerprint) {
      errors.add(
        'ObjectBox-Modell nicht kompatibel: '
        '${database.catalogModelFingerprint}',
      );
    }

    return errors;
  }

  factory BPuzzlesManifest.fromJson(Map<String, Object?> json) {
    return BPuzzlesManifest(
      format: _string(json, 'format'),
      formatVersion: _integer(json, 'formatVersion'),
      catalogSchemaVersion: _integer(
        json,
        'catalogSchemaVersion',
        fallbackKey: 'schemaVersion',
      ),
      catalogId: _string(json, 'catalogId'),
      displayName: _string(json, 'displayName'),
      createdAtUtc: _string(json, 'createdAtUtc', fallbackKey: 'createdAt'),
      source: BPuzzlesSourceInfo.fromJson(_map(json, 'source')),
      generator: BPuzzlesGeneratorInfo.fromJson(_map(json, 'generator')),
      database: BPuzzlesDatabaseInfo.fromJson(_map(json, 'database')),
      statistics: BPuzzlesStatistics.fromJson(_map(json, 'statistics')),
      ratingBuckets: BPuzzlesRatingBuckets.fromJson(
        _map(json, 'ratingBuckets'),
      ),
      themes: BPuzzlesThemeInfo.fromJson(_map(json, 'themes')),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'format': format,
      'formatVersion': formatVersion,
      'catalogSchemaVersion': catalogSchemaVersion,
      'catalogId': catalogId,
      'displayName': displayName,
      'createdAtUtc': createdAtUtc,
      'source': source.toJson(),
      'generator': generator.toJson(),
      'database': database.toJson(),
      'statistics': statistics.toJson(),
      'ratingBuckets': ratingBuckets.toJson(),
      'themes': themes.toJson(),
    };
  }

  BPuzzlesManifest copyWith({
    BPuzzlesDatabaseInfo? database,
    BPuzzlesStatistics? statistics,
  }) {
    return BPuzzlesManifest(
      format: format,
      formatVersion: formatVersion,
      catalogSchemaVersion: catalogSchemaVersion,
      catalogId: catalogId,
      displayName: displayName,
      createdAtUtc: createdAtUtc,
      source: source,
      generator: generator,
      database: database ?? this.database,
      statistics: statistics ?? this.statistics,
      ratingBuckets: ratingBuckets,
      themes: themes,
    );
  }
}

class BPuzzlesSourceInfo {
  const BPuzzlesSourceInfo({
    required this.name,
    required this.sourceFile,
    required this.sourceDate,
    required this.sha256,
    required this.license,
    this.url = 'https://database.lichess.org/',
  });

  final String name;
  final String sourceFile;
  final String sourceDate;
  final String sha256;
  final String license;
  final String url;

  factory BPuzzlesSourceInfo.fromJson(Map<String, Object?> json) {
    return BPuzzlesSourceInfo(
      name: _string(json, 'name'),
      sourceFile: _string(json, 'sourceFile'),
      sourceDate: _string(json, 'sourceDate'),
      sha256: _string(json, 'sha256'),
      license: _string(json, 'license'),
      url: _string(json, 'url', defaultValue: 'https://database.lichess.org/'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'sourceFile': sourceFile,
    'sourceDate': sourceDate,
    'sha256': sha256,
    'license': license,
    'url': url,
  };
}

class BPuzzlesGeneratorInfo {
  const BPuzzlesGeneratorInfo({
    required this.name,
    required this.version,
    required this.objectBoxVersion,
    required this.command,
  });

  final String name;
  final String version;
  final String objectBoxVersion;
  final String command;

  factory BPuzzlesGeneratorInfo.fromJson(Map<String, Object?> json) {
    return BPuzzlesGeneratorInfo(
      name: _string(json, 'name'),
      version: _string(json, 'version'),
      objectBoxVersion: _string(json, 'objectBoxVersion'),
      command: _string(json, 'command'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'version': version,
    'objectBoxVersion': objectBoxVersion,
    'command': command,
  };
}

class BPuzzlesDatabaseInfo {
  const BPuzzlesDatabaseInfo({
    required this.engine,
    required this.entry,
    required this.catalogModelFingerprint,
    required this.sha256,
    required this.sizeBytes,
    required this.requiredMaxDbSizeKb,
  });

  final String engine;
  final String entry;
  final String catalogModelFingerprint;
  final String sha256;
  final int sizeBytes;
  final int requiredMaxDbSizeKb;

  factory BPuzzlesDatabaseInfo.fromJson(Map<String, Object?> json) {
    return BPuzzlesDatabaseInfo(
      engine: _string(json, 'engine'),
      entry: _string(json, 'entry'),
      catalogModelFingerprint: _string(json, 'catalogModelFingerprint'),
      sha256: _string(json, 'sha256'),
      sizeBytes: _integer(json, 'sizeBytes'),
      requiredMaxDbSizeKb: _integer(json, 'requiredMaxDbSizeKb'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'engine': engine,
    'entry': entry,
    'catalogModelFingerprint': catalogModelFingerprint,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'requiredMaxDbSizeKb': requiredMaxDbSizeKb,
  };
}

class BPuzzlesStatistics {
  const BPuzzlesStatistics({
    required this.puzzleCount,
    required this.minRating,
    required this.maxRating,
    required this.whiteToMoveCount,
    required this.blackToMoveCount,
    required this.rejectedRowCount,
    required this.unknownThemeCount,
  });

  final int puzzleCount;
  final int minRating;
  final int maxRating;
  final int whiteToMoveCount;
  final int blackToMoveCount;
  final int rejectedRowCount;
  final int unknownThemeCount;

  factory BPuzzlesStatistics.fromJson(Map<String, Object?> json) {
    return BPuzzlesStatistics(
      puzzleCount: _integer(json, 'puzzleCount'),
      minRating: _integer(json, 'minRating'),
      maxRating: _integer(json, 'maxRating'),
      whiteToMoveCount: _integer(json, 'whiteToMoveCount'),
      blackToMoveCount: _integer(json, 'blackToMoveCount'),
      rejectedRowCount: _integer(json, 'rejectedRowCount'),
      unknownThemeCount: _integer(json, 'unknownThemeCount'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'puzzleCount': puzzleCount,
    'minRating': minRating,
    'maxRating': maxRating,
    'whiteToMoveCount': whiteToMoveCount,
    'blackToMoveCount': blackToMoveCount,
    'rejectedRowCount': rejectedRowCount,
    'unknownThemeCount': unknownThemeCount,
  };
}

class BPuzzlesRatingBuckets {
  const BPuzzlesRatingBuckets({
    required this.size,
    required this.minBucket,
    required this.maxBucket,
  });

  final int size;
  final int minBucket;
  final int maxBucket;

  factory BPuzzlesRatingBuckets.fromJson(Map<String, Object?> json) {
    return BPuzzlesRatingBuckets(
      size: _integer(json, 'size'),
      minBucket: _integer(json, 'minBucket'),
      maxBucket: _integer(json, 'maxBucket'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'size': size,
    'minBucket': minBucket,
    'maxBucket': maxBucket,
  };
}

class BPuzzlesThemeInfo {
  const BPuzzlesThemeInfo({
    required this.dictionaryVersion,
    required this.dictionarySha256,
    required this.maskBits,
    required this.dictionary,
  });

  final int dictionaryVersion;
  final String dictionarySha256;
  final int maskBits;
  final List<String> dictionary;

  factory BPuzzlesThemeInfo.fromJson(Map<String, Object?> json) {
    return BPuzzlesThemeInfo(
      dictionaryVersion: _integer(json, 'dictionaryVersion'),
      dictionarySha256: _string(json, 'dictionarySha256'),
      maskBits: _integer(json, 'maskBits'),
      dictionary: _stringList(json, 'dictionary'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'dictionaryVersion': dictionaryVersion,
    'dictionarySha256': dictionarySha256,
    'maskBits': maskBits,
    'dictionary': dictionary,
  };
}

Map<String, Object?> _map(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }
  return const <String, Object?>{};
}

String _string(
  Map<String, Object?> json,
  String key, {
  String? fallbackKey,
  String defaultValue = '',
}) {
  final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);
  return value?.toString() ?? defaultValue;
}

int _integer(Map<String, Object?> json, String key, {String? fallbackKey}) {
  final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const <String>[];
  }
  return value.map((Object? item) => item.toString()).toList(growable: false);
}
