/// Phases of a lateral raise exercise.
enum LateralRaisePhase {
  /// Waiting for user to get into starting position.
  waiting,

  /// Arms at sides, ready to start rep.
  down,

  /// Raising arms upward.
  rising,

  /// Arms raised to target height.
  up,

  /// Lowering arms back down.
  falling,
}

/// Current state of the lateral raise counter.
class LateralRaiseState {
  /// Total number of completed reps.
  final int repCount;

  /// Current phase of the movement.
  final LateralRaisePhase phase;

  /// Current raw shoulder angle (averaged from both arms).
  final double currentAngle;

  /// Smoothed shoulder angle after EMA filtering.
  final double smoothedAngle;

  const LateralRaiseState({
    required this.repCount,
    required this.phase,
    required this.currentAngle,
    required this.smoothedAngle,
  });

  /// Initial state when counter is created.
  const LateralRaiseState.initial()
    : repCount = 0,
      phase = LateralRaisePhase.waiting,
      currentAngle = 0.0,
      smoothedAngle = 0.0;

  /// Create a copy with updated fields.
  LateralRaiseState copyWith({
    int? repCount,
    LateralRaisePhase? phase,
    double? currentAngle,
    double? smoothedAngle,
  }) {
    return LateralRaiseState(
      repCount: repCount ?? this.repCount,
      phase: phase ?? this.phase,
      currentAngle: currentAngle ?? this.currentAngle,
      smoothedAngle: smoothedAngle ?? this.smoothedAngle,
    );
  }

  @override
  String toString() =>
      'LateralRaiseState(reps: $repCount, phase: $phase, '
      'angle: ${smoothedAngle.toStringAsFixed(1)}°)';
}

/// Phases of a single squat exercise.
enum SingleSquatPhase {
  /// Waiting for user to get into starting position (standing straight).
  waiting,

  /// Standing straight, ready to start descending.
  standing,

  /// Descending (knees Bending).
  descending,

  /// Bottom of the squat (max knee bend).
  bottom,

  /// Ascending (straightening legs).
  ascending,
}

/// Current state of the single squat counter.
class SingleSquatState {
  /// Total number of completed reps.
  final int repCount;

  /// Current phase of the movement.
  final SingleSquatPhase phase;

  /// Current raw knee angle (min of both legs).
  final double currentAngle;

  /// Smoothed knee angle after EMA filtering.
  final double smoothedAngle;

  const SingleSquatState({
    required this.repCount,
    required this.phase,
    required this.currentAngle,
    required this.smoothedAngle,
  });

  /// Initial state when counter is created.
  const SingleSquatState.initial()
    : repCount = 0,
      phase = SingleSquatPhase.waiting,
      currentAngle = 180.0,
      smoothedAngle = 180.0;

  /// Create a copy with updated fields.
  SingleSquatState copyWith({
    int? repCount,
    SingleSquatPhase? phase,
    double? currentAngle,
    double? smoothedAngle,
  }) {
    return SingleSquatState(
      repCount: repCount ?? this.repCount,
      phase: phase ?? this.phase,
      currentAngle: currentAngle ?? this.currentAngle,
      smoothedAngle: smoothedAngle ?? this.smoothedAngle,
    );
  }

  @override
  String toString() =>
      'SingleSquatState(reps: $repCount, phase: $phase, '
      'angle: ${smoothedAngle.toStringAsFixed(1)}°)';
}

/// Phases of a bench press exercise.
enum BenchPressPhase {
  /// Waiting for user to get into starting position (arms extended).
  waiting,

  /// Arms fully extended, ready to start descending.
  up,

  /// Descending (lowering arm to chest).
  falling,

  /// At the chest (bottom of movement).
  down,

  /// Ascending (pressing the bar up).
  rising,
}

/// Current state of the bench press counter.
class BenchPressState {
  /// Total number of completed reps.
  final int repCount;

  /// Current phase of the movement.
  final BenchPressPhase phase;

  /// Current raw elbow angle (average of both arms).
  final double currentAngle;

  /// Smoothed elbow angle after EMA filtering.
  final double smoothedAngle;

  const BenchPressState({
    required this.repCount,
    required this.phase,
    required this.currentAngle,
    required this.smoothedAngle,
  });

  /// Initial state when counter is created.
  const BenchPressState.initial()
    : repCount = 0,
      phase = BenchPressPhase.waiting,
      currentAngle = 180.0,
      smoothedAngle = 180.0;

  /// Create a copy with updated fields.
  BenchPressState copyWith({
    int? repCount,
    BenchPressPhase? phase,
    double? currentAngle,
    double? smoothedAngle,
  }) {
    return BenchPressState(
      repCount: repCount ?? this.repCount,
      phase: phase ?? this.phase,
      currentAngle: currentAngle ?? this.currentAngle,
      smoothedAngle: smoothedAngle ?? this.smoothedAngle,
    );
  }

  @override
  String toString() =>
      'BenchPressState(reps: $repCount, phase: $phase, '
      'angle: ${smoothedAngle.toStringAsFixed(1)}°)';
}
