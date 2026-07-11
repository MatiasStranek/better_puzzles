import 'package:bpuzzles_format/bpuzzles_format.dart';
import 'package:flutter/material.dart';

import '../data/import/puzzle_database_import_service.dart';
import '../data/repositories/in_memory_puzzle_catalog_repository.dart';
import '../data/repositories/objectbox_puzzle_catalog_repository.dart';
import '../data/repositories/puzzle_catalog_repository.dart';
import '../data/stores/better_puzzles_stores.dart';
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
  }) : _repository = repository ?? InMemoryPuzzleCatalogRepository(),
       _importService = importService ?? const PuzzleDatabaseImportService() {
    loadNextPuzzle();
  }

  PuzzleCatalogRepository _repository;
  PuzzleDatabaseImportService _importService;
  BetterPuzzlesStores? _stores;

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

  bool _databaseBusy = false;
  String _databaseActivity = '';
  double? _databaseImportProgress;
  String? _databaseInitializationError;

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
  bool get databaseReady => _stores != null;
  bool get databaseBusy => _databaseBusy;
  String get databaseActivity => _databaseActivity;
  double? get databaseImportProgress => _databaseImportProgress;
  String? get databaseInitializationError => _databaseInitializationError;

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

  Future<void> attachStores(BetterPuzzlesStores stores) async {
    _stores = stores;
    _importService = stores.importService;
    _databaseInitializationError = null;

    final manifest = stores.activeManifest;
    if (manifest == null || !stores.catalogStore.isOpen) {
      _databaseStatus = const PuzzleDatabaseStatus.missing();
      notifyListeners();
      return;
    }

    _repository = ObjectBoxPuzzleCatalogRepository(
      storeManager: stores.catalogStore,
    );
    _databaseStatus = _statusFromManifest(
      manifest,
      label: '${manifest.displayName} ist aktiv',
    );
    await loadNextPuzzle();
  }

  void setDatabaseInitializationError(Object error) {
    _databaseInitializationError = error.toString();
    _databaseStatus = PuzzleDatabaseStatus(
      isAvailable: false,
      label: 'Datenbank konnte nicht geöffnet werden',
      sourceName: error.toString(),
    );
    notifyListeners();
  }

  Future<PuzzleCatalogPackageInspection> inspectPuzzleCatalog(
    String packagePath,
  ) {
    return _importService.inspectPackage(packagePath);
  }

  Future<PuzzleDatabaseImportResult> importPuzzleCatalog(
    String packagePath,
  ) async {
    final stores = _stores;
    if (stores == null) {
      throw StateError('Die App-Speicher sind noch nicht initialisiert');
    }
    if (_databaseBusy) {
      throw StateError('Es läuft bereits ein Datenbankimport');
    }

    _databaseBusy = true;
    _databaseActivity = 'Import wird vorbereitet';
    _databaseImportProgress = 0;
    notifyListeners();

    PuzzleDatabaseImportResult? completed;

    try {
      await for (final event in _importService.importPackage(
        packagePath,
        onProgress: _applyImportEvent,
      )) {
        _applyImportEvent(event);
        completed = event.result ?? completed;
      }

      final result = completed;
      final manifest = result?.manifest;
      if (result == null || manifest == null) {
        throw StateError('Der Import wurde nicht vollständig abgeschlossen');
      }
      if (!stores.catalogStore.isOpen) {
        throw StateError('Der importierte PuzzleCatalogStore ist nicht offen');
      }

      _repository = ObjectBoxPuzzleCatalogRepository(
        storeManager: stores.catalogStore,
      );
      _databaseStatus = _statusFromManifest(
        manifest,
        label: '${manifest.displayName} ist aktiv',
      );
      await loadNextPuzzle();
      return result;
    } on Object {
      _databaseActivity = 'Import fehlgeschlagen';
      rethrow;
    } finally {
      _databaseBusy = false;
      _databaseImportProgress = null;
      notifyListeners();
    }
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

    final repository = _repository;
    final puzzle = await repository.nextPuzzle(
      range: _range,
      random: _randomMode,
    );

    if (!identical(repository, _repository)) {
      return;
    }

    _currentPuzzle = puzzle;

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

  bool canMoveTo({required String from, required String to}) {
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

  void _applyImportEvent(PuzzleCatalogImportEvent event) {
    _databaseActivity = event.message;
    _databaseImportProgress = _overallImportProgress(event);
    notifyListeners();
  }

  double _overallImportProgress(PuzzleCatalogImportEvent event) {
    final phaseProgress = (event.progress ?? 0).clamp(0.0, 1.0).toDouble();

    return switch (event.phase) {
      PuzzleCatalogImportPhase.inspecting => 0.01,
      PuzzleCatalogImportPhase.preparingStaging => 0.03,
      PuzzleCatalogImportPhase.copyingPackage => 0.03 + (phaseProgress * 0.42),
      PuzzleCatalogImportPhase.extracting => 0.45 + (phaseProgress * 0.42),
      PuzzleCatalogImportPhase.verifyingObjectBox => 0.90,
      PuzzleCatalogImportPhase.activating => 0.95,
      PuzzleCatalogImportPhase.openingCatalog => 0.98,
      PuzzleCatalogImportPhase.completed => 1.0,
    };
  }

  PuzzleDatabaseStatus _statusFromManifest(
    BPuzzlesManifest manifest, {
    required String label,
  }) {
    return PuzzleDatabaseStatus(
      isAvailable: true,
      label: label,
      puzzleCount: manifest.puzzleCount,
      sourceName: manifest.source.name,
      importedAtMs: DateTime.now().millisecondsSinceEpoch,
      catalogId: manifest.catalogId,
      minRating: manifest.minRating,
      maxRating: manifest.maxRating,
    );
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
