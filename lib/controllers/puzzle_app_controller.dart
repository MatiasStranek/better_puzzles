import 'package:flutter/material.dart';

import '../data/import/puzzle_database_import_service.dart';
import '../data/repositories/in_memory_puzzle_catalog_repository.dart';
import '../data/repositories/puzzle_catalog_repository.dart';
import '../domain/puzzle_database_status.dart';
import '../domain/puzzle_mode.dart';
import '../domain/puzzle_range.dart';
import '../domain/puzzle_record.dart';
import '../models/board_highlights.dart';
import '../utils/fen_piece_map.dart';

class PuzzleAppController extends ChangeNotifier {
  PuzzleAppController({
    PuzzleCatalogRepository? repository,
    PuzzleDatabaseImportService? importService,
  })  : _repository = repository ?? InMemoryPuzzleCatalogRepository(),
        _importService = importService ?? const PuzzleDatabaseImportService() {
    loadNextPuzzle();
  }

  final PuzzleCatalogRepository _repository;
  final PuzzleDatabaseImportService _importService;

  PuzzleMode _mode = PuzzleMode.tasks;
  PuzzleRange _range = const PuzzleRange(minRating: 600, maxRating: 1600);
  bool _randomMode = false;
  PuzzleDatabaseStatus _databaseStatus = const PuzzleDatabaseStatus.missing();
  PuzzleRecord? _currentPuzzle;
  String? _selectedSquare;
  String? _lastFrom;
  String? _lastTo;
  bool _playerIsWhite = true;
  int _score = 0;
  int _mistakes = 0;
  int _streak = 0;

  PuzzleMode get mode => _mode;
  PuzzleRange get range => _range;
  bool get randomMode => _randomMode;
  PuzzleDatabaseStatus get databaseStatus => _databaseStatus;
  PuzzleRecord? get currentPuzzle => _currentPuzzle;
  String? get selectedSquare => _selectedSquare;
  bool get playerIsWhite => _playerIsWhite;
  int get score => _score;
  int get mistakes => _mistakes;
  int get streak => _streak;

  String get boardFen {
    return _currentPuzzle?.puzzleFen ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  }

  Map<String, String> get piecesBySquare => FenPieceMap.fromFen(boardFen);

  String? pieceCodeAt(String square) {
    final fenPiece = piecesBySquare[square];

    if (fenPiece == null) {
      return null;
    }

    return switch (fenPiece) {
      'K' => 'wK',
      'Q' => 'wQ',
      'R' => 'wR',
      'B' => 'wB',
      'N' => 'wN',
      'P' => 'wP',
      'k' => 'bK',
      'q' => 'bQ',
      'r' => 'bR',
      'b' => 'bB',
      'n' => 'bN',
      'p' => 'bP',
      _ => null,
    };
  }

  BoardHighlights get highlights {
    return BoardHighlights(
      selectedSquare: _selectedSquare,
      lastFrom: _lastFrom,
      lastTo: _lastTo,
      legalTargets: _selectedSquare == null ? const [] : _demoLegalTargets(),
    );
  }

  String get activeTitle {
    return switch (_mode) {
      PuzzleMode.tasks => 'Aufgaben',
      PuzzleMode.streak => 'Puzzle Streak',
      PuzzleMode.storm => 'Puzzle Storm',
    };
  }

  String get statusText {
    final puzzle = _currentPuzzle;

    if (puzzle == null) {
      return 'Keine Aufgabe geladen';
    }

    return '${_mode.label} · ${puzzle.rating} Elo';
  }

  String get moveStripText {
    final puzzle = _currentPuzzle;

    if (puzzle == null) {
      return 'Datenbank vorbereiten';
    }

    return 'Puzzle ${puzzle.lichessPuzzleId} · ${puzzle.themes}';
  }

  void setMode(PuzzleMode mode) {
    if (_mode == mode) {
      return;
    }

    _mode = mode;
    _score = 0;
    _mistakes = 0;
    _streak = 0;
    loadNextPuzzle();
  }

  void setRange(PuzzleRange range) {
    _range = range;
    loadNextPuzzle();
  }

  void setRandomMode(bool enabled) {
    if (_randomMode == enabled) {
      return;
    }

    _randomMode = enabled;
    loadNextPuzzle();
  }

  void flipBoard() {
    _playerIsWhite = !_playerIsWhite;
    notifyListeners();
  }

  Future<void> prepareDatabaseFolder() async {
    final result = await _importService.prepareEmptyCatalogFolder();

    _databaseStatus = PuzzleDatabaseStatus(
      isAvailable: false,
      label: result.message,
      sourceName: 'Noch kein .bpuzzles Paket',
    );

    notifyListeners();
  }

  Future<void> loadNextPuzzle() async {
    _selectedSquare = null;
    _lastFrom = null;
    _lastTo = null;

    _currentPuzzle = await _repository.nextPuzzle(
      range: _range,
      random: _randomMode,
    );

    final playerColor = _currentPuzzle?.playerColor;
    if (playerColor != null) {
      _playerIsWhite = playerColor == 0;
    }

    notifyListeners();
  }

  Future<void> tapSquare(String square) async {
    final selected = _selectedSquare;
    final pieces = piecesBySquare;

    if (selected == null) {
      if (pieces.containsKey(square)) {
        _selectedSquare = square;
        notifyListeners();
      }

      return;
    }

    if (selected == square) {
      _selectedSquare = null;
      notifyListeners();
      return;
    }

    await movePiece(from: selected, to: square);
  }

  bool canHumanMovePiece(String square) {
    return piecesBySquare.containsKey(square);
  }

  bool canMoveTo({
    required String from,
    required String to,
  }) {
    return from != to;
  }

  Future<bool> movePiece({
    required String from,
    required String to,
    String? promotion,
  }) async {
    if (!canMoveTo(from: from, to: to)) {
      _selectedSquare = null;
      notifyListeners();
      return false;
    }

    // UI-Shell: später prüft PuzzleSolver hier gegen solutionMovesUci.
    _selectedSquare = null;
    _lastFrom = from;
    _lastTo = to;
    _score++;
    _streak++;

    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 140));
    await loadNextPuzzle();

    return true;
  }

  void onPieceDragStarted(String square) {
    _selectedSquare = square;
    notifyListeners();
  }

  void onPieceDragEnded() {
    _selectedSquare = null;
    notifyListeners();
  }

  void registerMistake() {
    _mistakes++;
    _streak = 0;
    notifyListeners();
  }

  void resetRun() {
    _score = 0;
    _mistakes = 0;
    _streak = 0;
    loadNextPuzzle();
  }

  List<String> _demoLegalTargets() {
    const files = <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final selected = _selectedSquare;

    if (selected == null || selected.length != 2) {
      return const [];
    }

    final file = selected.substring(0, 1);
    final rank = int.tryParse(selected.substring(1, 2));

    if (rank == null) {
      return const [];
    }

    final fileIndex = files.indexOf(file);
    if (fileIndex < 0) {
      return const [];
    }

    final targets = <String>[];

    for (final df in const [-1, 0, 1]) {
      for (final dr in const [-1, 0, 1]) {
        if (df == 0 && dr == 0) {
          continue;
        }

        final nextFile = fileIndex + df;
        final nextRank = rank + dr;

        if (nextFile >= 0 && nextFile < 8 && nextRank >= 1 && nextRank <= 8) {
          targets.add('${files[nextFile]}$nextRank');
        }
      }
    }

    return targets;
  }
}
