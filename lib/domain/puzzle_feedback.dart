enum PuzzleFeedback {
  idle,
  loading,
  goodMove,
  solved,
  wrongMove,
  runEnded,
  noPuzzle;

  bool get isFailure => this == PuzzleFeedback.wrongMove;
}
