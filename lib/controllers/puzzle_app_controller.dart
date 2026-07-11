import 'dart:async';

import 'package:bpuzzles_format/bpuzzles_format.dart';
import 'package:flutter/material.dart';

import '../data/import/puzzle_database_import_service.dart';
import '../data/repositories/in_memory_puzzle_catalog_repository.dart';
import '../data/repositories/objectbox_puzzle_catalog_repository.dart';
import '../data/repositories/puzzle_catalog_repository.dart';
import '../data/repositories/puzzle_user_repository.dart';
import '../data/stores/better_puzzles_stores.dart';
import '../domain/fen_position.dart';
import '../domain/glicko2.dart';
import '../domain/puzzle_database_status.dart';
import '../domain/puzzle_difficulty.dart';
import '../domain/puzzle_feedback.dart';
import '../domain/puzzle_mode.dart';
import '../domain/puzzle_mode_plan.dart';
import '../domain/puzzle_range.dart';
import '../domain/puzzle_record.dart';
import '../domain/puzzle_selection.dart';
import '../models/board_highlights.dart';
import '../utils/fen_piece_map.dart';

class PuzzleAppController extends ChangeNotifier {
  PuzzleAppController({
    PuzzleCatalogRepository? repository,
    PuzzleDatabaseImportService? importService,
    Glicko2Calculator ratingCalculator = const Glicko2Calculator(),
  }) : _repository = repository ?? InMemoryPuzzleCatalogRepository(),
       _importService = importService ?? const PuzzleDatabaseImportService(),
       _ratingCalculator = ratingCalculator {
    unawaited(_beginMode(resetCounters: true));
  }

  PuzzleCatalogRepository _repository;
  PuzzleDatabaseImportService _importService;
  final Glicko2Calculator _ratingCalculator;
  BetterPuzzlesStores? _stores;
  PuzzleUserRepository? _userRepository;

  PuzzleMode _mode = PuzzleMode.tasks;
  PuzzleRange _range = const PuzzleRange(minRating: 600, maxRating: 1600);
  bool _randomMode = false;
  bool _ratedTasks = true;
  PuzzleDifficulty _difficulty = PuzzleDifficulty.normal;
  Glicko2Rating _puzzleRating = Glicko2Rating.initial;
  int _lastRatingChange = 0;

  PuzzleDatabaseStatus _databaseStatus = const PuzzleDatabaseStatus.missing();
  PuzzleRecord? _currentPuzzle;
  FenPosition? _position;
  int _solutionIndex = 0;
  bool _currentPuzzleFailed = false;
  bool _currentResultRecorded = false;
  DateTime? _puzzleStartedAt;

  String? _selectedSquare;
  String? _lastFrom;
  String? _lastTo;
  bool _playerIsWhite = true;
  bool _solverIsWhite = true;

  int _score = 0;
  int _mistakes = 0;
  int _streak = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _highestSolvedRating = 0;
  int _streakBest = 0;
  int _stormBest = 0;
  int _stormBestCombo = 0;

  List<PuzzleSelection> _runSelections = const <PuzzleSelection>[];
  int _runSelectionIndex = 0;
  final Set<String> _runPuzzleIds = <String>{};
  bool _runEnded = false;
  int? _runId;
  DateTime? _runStartedAt;
  int _runRatingBefore = 1500;
  int _runGeneration = 0;

  Timer? _stormTimer;
  DateTime? _stormDeadline;
  Duration _stormRemaining = const Duration(
    seconds: PuzzleModePlan.stormInitialSeconds,
  );
  bool _stormStarted = false;
  int _lastStormModifierSeconds = 0;

  PuzzleFeedback _feedback = PuzzleFeedback.idle;
  String _feedbackText = '';
  bool _loadingPuzzle = false;
  int _lastQueryDurationMs = 0;

  bool _databaseBusy = false;
  String _databaseActivity = '';
  double? _databaseImportProgress;
  String? _databaseInitializationError;

  PuzzleMode get mode => _mode;
  PuzzleRange get range => _range;
  bool get randomMode => _randomMode;
  bool get ratedTasks => _ratedTasks;
  PuzzleDifficulty get difficulty => _difficulty;
  Glicko2Rating get puzzleRating => _puzzleRating;
  int get lastRatingChange => _lastRatingChange;
  PuzzleDatabaseStatus get databaseStatus => _databaseStatus;
  PuzzleRecord? get currentPuzzle => _currentPuzzle;
  String? get selectedSquare => _selectedSquare;
  bool get playerIsWhite => _playerIsWhite;
  int get score => _score;
  int get mistakes => _mistakes;
  int get streak => _streak;
  int get combo => _combo;
  int get bestCombo => _bestCombo;
  int get streakBest => _streakBest;
  int get stormBest => _stormBest;
  int get stormBestCombo => _stormBestCombo;
  int get highestSolvedRating => _highestSolvedRating;
  bool get runEnded => _runEnded;
  bool get stormStarted => _stormStarted;
  bool get loadingPuzzle => _loadingPuzzle;
  PuzzleFeedback get feedback => _feedback;
  String get feedbackText => _feedbackText;
  int get lastQueryDurationMs => _lastQueryDurationMs;
  int get lastStormModifierSeconds => _lastStormModifierSeconds;
  int get stormRemainingSeconds =>
      (_stormRemaining.inMilliseconds / 1000).ceil().clamp(0, 600).toInt();
  bool get databaseReady => _stores != null;
  bool get databaseBusy => _databaseBusy;
  String get databaseActivity => _databaseActivity;
  double? get databaseImportProgress => _databaseImportProgress;
  String? get databaseInitializationError => _databaseInitializationError;

  bool get taskControlsUseRange => _mode == PuzzleMode.tasks && !_ratedTasks;
  bool get canSkipPuzzle => _mode == PuzzleMode.tasks && !_runEnded;

  String get localRatingLabel {
    final provisional = _puzzleRating.provisional ? '?' : '';
    return '${_puzzleRating.displayRating}$provisional';
  }

  String get ratingChangeLabel {
    if (_lastRatingChange == 0) {
      return '±0';
    }
    return '${_lastRatingChange > 0 ? '+' : ''}$_lastRatingChange';
  }

  String get stormTimeText {
    final milliseconds = _stormRemaining.inMilliseconds
        .clamp(0, PuzzleModePlan.stormInitialSeconds * 1000 * 2)
        .toInt();
    final totalSeconds = (milliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get runStateLabel {
    if (_runEnded) {
      return _mode == PuzzleMode.streak
          ? 'Streak beendet'
          : _mode == PuzzleMode.storm
          ? 'Storm beendet'
          : 'Run beendet';
    }
    if (_loadingPuzzle) {
      return 'Puzzle wird geladen';
    }
    if (_mode == PuzzleMode.storm && !_stormStarted) {
      return 'Erster Zug startet die Uhr';
    }
    return 'Läuft';
  }

  String get primaryMetricLabel {
    return switch (_mode) {
      PuzzleMode.tasks => 'Wertung',
      PuzzleMode.streak => 'Streak',
      PuzzleMode.storm => 'Zeit',
    };
  }

  String get primaryMetricValue {
    return switch (_mode) {
      PuzzleMode.tasks => localRatingLabel,
      PuzzleMode.streak => '$_streak',
      PuzzleMode.storm => stormTimeText,
    };
  }

  String get secondaryMetricLabel {
    return switch (_mode) {
      PuzzleMode.tasks => 'Serie',
      PuzzleMode.streak => 'Bestwert',
      PuzzleMode.storm => 'Gelöst',
    };
  }

  String get secondaryMetricValue {
    return switch (_mode) {
      PuzzleMode.tasks => '$_streak',
      PuzzleMode.streak => '$_streakBest',
      PuzzleMode.storm => '$_score',
    };
  }

  String get tertiaryMetricLabel {
    return switch (_mode) {
      PuzzleMode.tasks => 'Änderung',
      PuzzleMode.streak => 'Fehler',
      PuzzleMode.storm => 'Combo',
    };
  }

  String get tertiaryMetricValue {
    return switch (_mode) {
      PuzzleMode.tasks => ratingChangeLabel,
      PuzzleMode.streak => '$_mistakes',
      PuzzleMode.storm => '$_combo',
    };
  }

  String get boardFen {
    return _position?.toFen() ??
        _currentPuzzle?.puzzleFen ??
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
      legalTargets: const <String>[],
    );
  }

  String get activeTitle => _mode.label;

  String get statusText {
    final puzzle = _currentPuzzle;

    if (_runEnded) {
      return switch (_mode) {
        PuzzleMode.tasks => 'Aufgaben · $localRatingLabel',
        PuzzleMode.streak => 'Streak beendet · $_score gelöst',
        PuzzleMode.storm => 'Storm beendet · $_score gelöst',
      };
    }

    if (puzzle == null) {
      return _loadingPuzzle ? 'Puzzle wird geladen …' : 'Keine Aufgabe geladen';
    }

    return switch (_mode) {
      PuzzleMode.tasks =>
        'Aufgaben · $localRatingLabel · Puzzle ${puzzle.rating}',
      PuzzleMode.streak =>
        'Streak $_streak · Best $_streakBest · ${puzzle.rating}',
      PuzzleMode.storm => '$stormTimeText · Gelöst $_score · Combo $_combo',
    };
  }

  String get moveStripText {
    if (_feedbackText.isNotEmpty) {
      return _feedbackText;
    }

    final puzzle = _currentPuzzle;
    if (puzzle == null) {
      return 'Datenbank vorbereiten';
    }

    final queryInfo = _lastQueryDurationMs > 0
        ? ' · ${_lastQueryDurationMs}ms'
        : '';
    return 'Puzzle ${puzzle.lichessPuzzleId} · ${puzzle.themes}$queryInfo';
  }

  Future<void> attachStores(BetterPuzzlesStores stores) async {
    _stores = stores;
    _importService = stores.importService;
    _userRepository = PuzzleUserRepository(stores.userStore);
    _databaseInitializationError = null;

    final settings = _userRepository!.loadSettings();
    _range = settings.range;
    _randomMode = settings.randomMode;
    _mode = settings.mode;
    _ratedTasks = settings.ratedTasks;
    _difficulty = settings.difficulty;
    _puzzleRating = settings.rating;
    _streakBest = settings.streakBest;
    _stormBest = settings.stormBest;
    _stormBestCombo = settings.stormBestCombo;

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
    await _beginMode(resetCounters: true);
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
      await _beginMode(resetCounters: true);
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
    unawaited(_setMode(mode));
  }

  Future<void> _setMode(PuzzleMode mode) async {
    _finishRun(completed: false);
    _mode = mode;
    _saveSettings();
    await _beginMode(resetCounters: true);
  }

  void setRange(PuzzleRange range) {
    _range = range;
    _repository.resetCursors();
    _saveSettings();
    unawaited(_beginMode(resetCounters: true));
  }

  void setRandomMode(bool enabled) {
    if (_randomMode == enabled) {
      return;
    }

    _randomMode = enabled;
    _repository.resetCursors();
    _saveSettings();
    unawaited(_beginMode(resetCounters: true));
  }

  void setRatedTasks(bool enabled) {
    if (_ratedTasks == enabled) {
      return;
    }
    _ratedTasks = enabled;
    _lastRatingChange = 0;
    _repository.resetCursors();
    _saveSettings();
    unawaited(_beginMode(resetCounters: true));
  }

  void cycleDifficulty() {
    _difficulty = _difficulty.next;
    _repository.resetCursors();
    _saveSettings();
    unawaited(_beginMode(resetCounters: true));
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
    if (_runEnded) {
      return;
    }
    await _loadPuzzleForCurrentSlot();
  }

  Future<void> skipCurrentPuzzle() async {
    if (!canSkipPuzzle || _currentPuzzle == null) {
      return;
    }

    if (!_currentResultRecorded) {
      _recordCurrentResult(solved: false);
      if (_ratedTasks) {
        _updateTaskRating(win: false);
      }
    }
    _mistakes++;
    _streak = 0;
    await _loadPuzzleForCurrentSlot();
  }

  Future<void> tapSquare(String square) async {
    final selected = _selectedSquare;
    final pieces = piecesBySquare;

    if (selected == null) {
      if (canHumanMovePiece(square) && pieces.containsKey(square)) {
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
    if (_loadingPuzzle || _runEnded || _currentPuzzle == null) {
      return false;
    }

    final piece = _position?.pieceAt(square);
    if (piece == null) {
      return false;
    }

    final pieceIsWhite = piece == piece.toUpperCase();
    return pieceIsWhite == _solverIsWhite;
  }

  bool canMoveTo({required String from, required String to}) {
    return !_loadingPuzzle && !_runEnded && from != to;
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

    final puzzle = _currentPuzzle;
    final position = _position;
    if (puzzle == null || position == null) {
      return false;
    }

    final solution = puzzle.solutionMoves;
    if (_solutionIndex >= solution.length) {
      return false;
    }

    _startStormClockIfNeeded();

    final expected = solution[_solutionIndex];
    var played = '$from$to${promotion ?? ''}'.toLowerCase();
    if (promotion == null &&
        expected.length == 5 &&
        expected.startsWith('$from$to')) {
      played = expected;
    }
    played = _normalizeCastle(played);

    _selectedSquare = null;
    _lastFrom = from;
    _lastTo = to;

    if (played != expected) {
      await _handleWrongMove();
      return false;
    }

    try {
      position.applyUci(expected);
    } on FormatException {
      await _handleWrongMove();
      return false;
    }

    _solutionIndex++;
    _feedback = PuzzleFeedback.goodMove;
    _feedbackText = 'Guter Zug';

    if (_mode == PuzzleMode.storm) {
      _combo++;
      if (_combo > _bestCombo) {
        _bestCombo = _combo;
      }
      final bonus = PuzzleModePlan.stormBonusSecondsForCombo(_combo);
      if (bonus > 0) {
        _addStormSeconds(bonus);
        _lastStormModifierSeconds = bonus;
        _feedbackText = 'Combo $_combo · +${bonus}s';
      } else {
        _lastStormModifierSeconds = 0;
      }
    }

    notifyListeners();

    if (_solutionIndex >= solution.length) {
      await _handleSolvedPuzzle();
      return true;
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (_runEnded || !identical(puzzle, _currentPuzzle)) {
      return true;
    }

    final reply = solution[_solutionIndex];
    try {
      position.applyUci(reply);
      _solutionIndex++;
      _lastFrom = reply.substring(0, 2);
      _lastTo = reply.substring(2, 4);
    } on FormatException {
      _feedback = PuzzleFeedback.noPuzzle;
      _feedbackText = 'Puzzle-Zugfolge ist ungültig';
      notifyListeners();
      return false;
    }

    notifyListeners();

    if (_solutionIndex >= solution.length) {
      await _handleSolvedPuzzle();
    }

    return true;
  }

  void onPieceDragStarted(String square) {
    if (!canHumanMovePiece(square)) {
      return;
    }
    _selectedSquare = square;
    notifyListeners();
  }

  void onPieceDragEnded() {
    _selectedSquare = null;
    notifyListeners();
  }

  void registerMistake() {
    unawaited(_handleWrongMove());
  }

  void resetRun() {
    unawaited(_beginMode(resetCounters: true));
  }

  Future<void> _beginMode({required bool resetCounters}) async {
    _finishRun(completed: false);
    _runGeneration++;
    _stormTimer?.cancel();
    _stormTimer = null;
    _stormDeadline = null;
    _stormRemaining = const Duration(
      seconds: PuzzleModePlan.stormInitialSeconds,
    );
    _stormStarted = false;
    _lastStormModifierSeconds = 0;
    _runEnded = false;
    _runSelectionIndex = 0;
    _runPuzzleIds.clear();
    _repository.resetCursors();

    if (resetCounters) {
      _score = 0;
      _mistakes = 0;
      _streak = 0;
      _combo = 0;
      _bestCombo = 0;
      _highestSolvedRating = 0;
      _lastRatingChange = 0;
    }

    _runSelections = switch (_mode) {
      PuzzleMode.tasks => const <PuzzleSelection>[],
      PuzzleMode.streak => PuzzleModePlan.buildStreakSelections(),
      PuzzleMode.storm => PuzzleModePlan.buildStormSelections(
        playerColor: DateTime.now().millisecondsSinceEpoch.isEven ? 0 : 1,
      ),
    };

    _runStartedAt = DateTime.now().toUtc();
    _runRatingBefore = _puzzleRating.displayRating;
    _runId = _userRepository?.startRun(
      catalogId: _databaseStatus.catalogId ?? 'demo',
      mode: _mode,
      range: _range,
      randomMode: _randomMode,
      ratingBefore: _runRatingBefore,
    );

    _saveSettings();
    await _loadPuzzleForCurrentSlot();
  }

  Future<void> _loadPuzzleForCurrentSlot() async {
    if (_runEnded) {
      return;
    }

    final generation = _runGeneration;
    final selection = _selectionForCurrentSlot();
    if (selection == null) {
      _endRun(completed: true);
      return;
    }

    _loadingPuzzle = true;
    _feedback = PuzzleFeedback.loading;
    _feedbackText = 'Puzzle wird geladen …';
    _selectedSquare = null;
    _lastFrom = null;
    _lastTo = null;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    PuzzleRecord? puzzle;
    if (_mode == PuzzleMode.tasks && !_ratedTasks) {
      puzzle = await _repository.nextPuzzle(range: _range, random: _randomMode);
    } else {
      puzzle = await _repository.selectPuzzle(selection);
    }
    stopwatch.stop();

    if (generation != _runGeneration) {
      return;
    }

    _lastQueryDurationMs = stopwatch.elapsedMilliseconds;
    _loadingPuzzle = false;
    _currentPuzzle = puzzle;
    _solutionIndex = 0;
    _currentPuzzleFailed = false;
    _currentResultRecorded = false;
    _puzzleStartedAt = DateTime.now().toUtc();
    _feedbackText = '';

    if (puzzle == null) {
      _position = null;
      _feedback = PuzzleFeedback.noPuzzle;
      _feedbackText = 'Keine passende Aufgabe gefunden';
      notifyListeners();
      return;
    }

    try {
      _position = FenPosition.parse(puzzle.puzzleFen);
    } on FormatException {
      _position = null;
      _feedback = PuzzleFeedback.noPuzzle;
      _feedbackText = 'Puzzle-FEN konnte nicht gelesen werden';
      notifyListeners();
      return;
    }

    _runPuzzleIds.add(puzzle.lichessPuzzleId);
    _solverIsWhite = puzzle.playerColor == 0;
    _playerIsWhite = _solverIsWhite;
    _feedback = PuzzleFeedback.idle;
    notifyListeners();
  }

  PuzzleSelection? _selectionForCurrentSlot() {
    if (_mode == PuzzleMode.tasks) {
      if (!_ratedTasks) {
        return PuzzleSelection(
          minRating: _range.minRating,
          maxRating: _range.maxRating,
          random: _randomMode,
        );
      }

      final catalogMin = _databaseStatus.minRating ?? 400;
      final catalogMax = _databaseStatus.maxRating ?? 4000;
      final target = (_puzzleRating.displayRating + _difficulty.ratingDelta)
          .clamp(catalogMin, catalogMax)
          .toInt();
      return PuzzleSelection(
        minRating: (target - 120).clamp(catalogMin, catalogMax).toInt(),
        maxRating: (target + 120).clamp(catalogMin, catalogMax).toInt(),
        targetRating: target,
        random: true,
        maxRatingDeviation: 150,
        minPopularity: 0,
        minPlays: 10,
        excludePuzzleIds: _runPuzzleIds,
      );
    }

    if (_runSelectionIndex >= _runSelections.length) {
      return null;
    }

    return _runSelections[_runSelectionIndex].copyWith(
      excludePuzzleIds: _runPuzzleIds,
    );
  }

  Future<void> _handleSolvedPuzzle() async {
    final puzzle = _currentPuzzle;
    if (puzzle == null || _runEnded) {
      return;
    }

    final countsAsSolved = !_currentPuzzleFailed;
    _feedback = PuzzleFeedback.solved;
    _feedbackText = countsAsSolved ? 'Gelöst' : 'Lösung abgeschlossen';

    if (countsAsSolved) {
      _score++;
      if (_highestSolvedRating < puzzle.rating) {
        _highestSolvedRating = puzzle.rating;
      }
    }

    if (!_currentResultRecorded) {
      _recordCurrentResult(solved: countsAsSolved);
    }

    switch (_mode) {
      case PuzzleMode.tasks:
        if (countsAsSolved) {
          _streak++;
          if (_ratedTasks) {
            _updateTaskRating(win: true);
          }
        }
        break;
      case PuzzleMode.streak:
        _streak = _score;
        if (_streak > _streakBest) {
          _streakBest = _streak;
          _saveSettings();
        }
        _runSelectionIndex++;
        break;
      case PuzzleMode.storm:
        _runSelectionIndex++;
        if (_score > _stormBest) {
          _stormBest = _score;
        }
        if (_bestCombo > _stormBestCombo) {
          _stormBestCombo = _bestCombo;
        }
        _saveSettings();
        break;
    }

    notifyListeners();
    await Future<void>.delayed(
      Duration(milliseconds: _mode == PuzzleMode.storm ? 90 : 260),
    );

    if (!_runEnded) {
      await _loadPuzzleForCurrentSlot();
    }
  }

  Future<void> _handleWrongMove() async {
    final puzzle = _currentPuzzle;
    if (puzzle == null || _runEnded || _loadingPuzzle) {
      return;
    }

    final firstFailure = !_currentPuzzleFailed;
    _currentPuzzleFailed = true;
    _feedback = PuzzleFeedback.wrongMove;
    _feedbackText = 'Nicht korrekt';
    _mistakes++;

    if (firstFailure && !_currentResultRecorded) {
      _recordCurrentResult(solved: false);
    }

    switch (_mode) {
      case PuzzleMode.tasks:
        _streak = 0;
        if (firstFailure && _ratedTasks) {
          _updateTaskRating(win: false);
        }
        _feedbackText = 'Nicht korrekt – versuche weiter';
        notifyListeners();
        break;
      case PuzzleMode.streak:
        _streak = _score;
        _endRun(completed: false);
        break;
      case PuzzleMode.storm:
        _combo = 0;
        _lastStormModifierSeconds = -PuzzleModePlan.stormMistakePenaltySeconds;
        _addStormSeconds(-PuzzleModePlan.stormMistakePenaltySeconds);
        _feedbackText = '-${PuzzleModePlan.stormMistakePenaltySeconds}s';
        notifyListeners();
        if (_stormRemaining.inMicroseconds <= 0) {
          _endRun(completed: true);
          return;
        }
        _runSelectionIndex++;
        await Future<void>.delayed(const Duration(milliseconds: 160));
        await _loadPuzzleForCurrentSlot();
        break;
    }
  }

  void _recordCurrentResult({required bool solved}) {
    final puzzle = _currentPuzzle;
    if (puzzle == null || _currentResultRecorded) {
      return;
    }

    _currentResultRecorded = true;
    final elapsed = _puzzleStartedAt == null
        ? 0
        : DateTime.now().toUtc().difference(_puzzleStartedAt!).inMilliseconds;
    _userRepository?.recordPuzzleResult(
      lichessPuzzleId: puzzle.lichessPuzzleId,
      solved: solved,
      elapsedMs: elapsed,
    );
  }

  void _updateTaskRating({required bool win}) {
    final puzzle = _currentPuzzle;
    if (puzzle == null) {
      return;
    }

    final update = _ratingCalculator.updateSingle(
      player: _puzzleRating,
      opponentRating: puzzle.rating.toDouble(),
      opponentDeviation: puzzle.ratingDeviation.toDouble(),
      win: win,
    );
    _puzzleRating = update.after;
    _lastRatingChange = update.ratingChange;
    _saveSettings();
  }

  void _startStormClockIfNeeded() {
    if (_mode != PuzzleMode.storm || _stormStarted || _runEnded) {
      return;
    }

    _stormStarted = true;
    _stormDeadline = DateTime.now().add(_stormRemaining);
    _stormTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final deadline = _stormDeadline;
      if (deadline == null || _runEnded) {
        return;
      }

      final remaining = deadline.difference(DateTime.now());
      _stormRemaining = remaining.isNegative ? Duration.zero : remaining;
      if (_stormRemaining.inMicroseconds <= 0) {
        _endRun(completed: true);
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _addStormSeconds(int seconds) {
    if (_mode != PuzzleMode.storm) {
      return;
    }

    if (!_stormStarted) {
      final nextMs = _stormRemaining.inMilliseconds + seconds * 1000;
      _stormRemaining = Duration(milliseconds: nextMs.clamp(0, 600000).toInt());
      return;
    }

    final deadline = _stormDeadline ?? DateTime.now();
    _stormDeadline = deadline.add(Duration(seconds: seconds));
    final remaining = _stormDeadline!.difference(DateTime.now());
    _stormRemaining = remaining.isNegative ? Duration.zero : remaining;
  }

  void _endRun({required bool completed}) {
    if (_runEnded) {
      return;
    }

    _runEnded = true;
    _stormTimer?.cancel();
    _stormTimer = null;
    _feedback = PuzzleFeedback.runEnded;
    _feedbackText = switch (_mode) {
      PuzzleMode.tasks => 'Run beendet',
      PuzzleMode.streak => 'Streak beendet · $_score gelöst',
      PuzzleMode.storm => 'Storm beendet · $_score gelöst',
    };

    if (_mode == PuzzleMode.streak && _score > _streakBest) {
      _streakBest = _score;
    }
    if (_mode == PuzzleMode.storm) {
      if (_score > _stormBest) {
        _stormBest = _score;
      }
      if (_bestCombo > _stormBestCombo) {
        _stormBestCombo = _bestCombo;
      }
    }

    _saveSettings();
    _finishRun(completed: completed);
    notifyListeners();
  }

  void _finishRun({required bool completed}) {
    final runId = _runId;
    if (runId == null) {
      return;
    }

    _runId = null;
    final durationMs = _runStartedAt == null
        ? 0
        : DateTime.now().toUtc().difference(_runStartedAt!).inMilliseconds;
    _userRepository?.finishRun(
      runId: runId,
      score: _score,
      streak: _streak,
      mistakes: _mistakes,
      bestCombo: _bestCombo,
      highestRating: _highestSolvedRating,
      durationMs: durationMs,
      ratingAfter: _puzzleRating.displayRating,
      ratingChange: _puzzleRating.displayRating - _runRatingBefore,
      completed: completed,
    );
  }

  void _saveSettings() {
    _userRepository?.saveSettings(
      PuzzleSettingsSnapshot(
        range: _range,
        randomMode: _randomMode,
        mode: _mode,
        ratedTasks: _ratedTasks,
        difficulty: _difficulty,
        rating: _puzzleRating,
        streakBest: _streakBest,
        stormBest: _stormBest,
        stormBestCombo: _stormBestCombo,
      ),
    );
  }

  String _normalizeCastle(String uci) {
    return switch (uci) {
      'e1a1' => 'e1c1',
      'e1h1' => 'e1g1',
      'e8a8' => 'e8c8',
      'e8h8' => 'e8g8',
      _ => uci,
    };
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

  @override
  void dispose() {
    _stormTimer?.cancel();
    _finishRun(completed: false);
    super.dispose();
  }
}
