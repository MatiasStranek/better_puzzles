import 'package:objectbox/objectbox.dart';

@Entity()
class CatalogMetaEntity {
  CatalogMetaEntity({
    this.id = singletonId,
    required this.catalogId,
    required this.catalogSchemaVersion,
    required this.displayName,
    required this.createdAtUtcMs,
    required this.sourceName,
    required this.sourceFile,
    required this.sourceDate,
    required this.sourceSha256,
    required this.catalogModelFingerprint,
    required this.puzzleCount,
    required this.minRating,
    required this.maxRating,
    required this.ratingBucketSize,
    required this.themeDictionaryVersion,
    required this.themeDictionarySha256,
  });

  static const int singletonId = 1;

  @Id(assignable: true)
  int id;

  @Unique()
  String catalogId;

  int catalogSchemaVersion;
  String displayName;
  int createdAtUtcMs;

  String sourceName;
  String sourceFile;
  String sourceDate;
  String sourceSha256;

  String catalogModelFingerprint;

  int puzzleCount;
  int minRating;
  int maxRating;
  int ratingBucketSize;

  int themeDictionaryVersion;
  String themeDictionarySha256;
}
