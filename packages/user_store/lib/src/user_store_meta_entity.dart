import 'package:objectbox/objectbox.dart';

@Entity()
class UserStoreMetaEntity {
  UserStoreMetaEntity({
    this.id = singletonId,
    this.schemaVersion = 2,
    required this.createdAtUtcMs,
    required this.lastOpenedAtUtcMs,
  });

  static const int singletonId = 1;

  @Id(assignable: true)
  int id;

  int schemaVersion;
  int createdAtUtcMs;
  int lastOpenedAtUtcMs;
}
