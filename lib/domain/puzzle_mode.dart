enum PuzzleMode {
  tasks,
  streak,
  storm;

  String get label {
    return switch (this) {
      PuzzleMode.tasks => 'Aufgaben',
      PuzzleMode.streak => 'Puzzle Streak',
      PuzzleMode.storm => 'Puzzle Storm',
    };
  }

  String get shortLabel {
    return switch (this) {
      PuzzleMode.tasks => 'Aufgaben',
      PuzzleMode.streak => 'Streak',
      PuzzleMode.storm => 'Storm',
    };
  }

  String get storageName {
    return switch (this) {
      PuzzleMode.tasks => 'tasks',
      PuzzleMode.streak => 'streak',
      PuzzleMode.storm => 'storm',
    };
  }

  static PuzzleMode fromStorageName(String value) {
    return switch (value) {
      'streak' => PuzzleMode.streak,
      'storm' => PuzzleMode.storm,
      _ => PuzzleMode.tasks,
    };
  }
}
