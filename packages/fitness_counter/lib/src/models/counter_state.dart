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
