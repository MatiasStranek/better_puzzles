import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:user_store/objectbox.g.dart' as user_obx;
import 'package:user_store/user_store.dart';

class UserStoreManager {
  Store? _store;

  bool get isOpen => _store != null && !_store!.isClosed();

  Store get store {
    final value = _store;
    if (value == null || value.isClosed()) {
      throw StateError('UserStore ist nicht geöffnet');
    }
    return value;
  }

  Box<PuzzleProgressEntity> get progressBox =>
      store.box<PuzzleProgressEntity>();
  Box<PuzzleRunEntity> get runBox => store.box<PuzzleRunEntity>();
  Box<PuzzleSettingsEntity> get settingsBox =>
      store.box<PuzzleSettingsEntity>();

  Future<void> open(Directory objectBoxDirectory) async {
    if (isOpen) {
      return;
    }

    await objectBoxDirectory.create(recursive: true);
    _store = user_obx.openStore(directory: objectBoxDirectory.path);

    final metaBox = store.box<UserStoreMetaEntity>();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final existing = metaBox.get(UserStoreMetaEntity.singletonId);

    if (existing == null) {
      metaBox.put(
        UserStoreMetaEntity(createdAtUtcMs: now, lastOpenedAtUtcMs: now),
      );
    } else {
      existing
        ..schemaVersion = 2
        ..lastOpenedAtUtcMs = now;
      metaBox.put(existing);
    }

    final settings = store.box<PuzzleSettingsEntity>().get(
      PuzzleSettingsEntity.singletonId,
    );
    if (settings == null) {
      store.box<PuzzleSettingsEntity>().put(PuzzleSettingsEntity());
    }
  }

  Future<void> close() async {
    final value = _store;
    _store = null;
    if (value != null && !value.isClosed()) {
      value.close();
    }
  }
}
