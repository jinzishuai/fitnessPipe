/// Events emitted by exercise counters during processing.
///
/// Use pattern matching to handle different event types:
/// ```dart
/// if (event is RepCompleted) {
///   print('Rep ${event.totalReps} completed!');
/// }
/// ```
sealed class RepEvent {
  const RepEvent();
}

/// Emitted when exercise tracking begins (user in ready position).
class ExerciseStarted extends RepEvent {
  const ExerciseStarted();

  @override
  String toString() => 'ExerciseStarted()';
}

/// Emitted when a repetition is successfully completed.
class RepCompleted extends RepEvent {
  /// Total number of reps completed so far.
  final int totalReps;

  /// How long this rep took from start to finish.
  final Duration repDuration;

  /// The peak angle achieved during the raising phase.
  ///
  /// For lateral raises, this is the maximum shoulder angle.
  /// Can be used to assess range of motion quality.
  final double peakAngle;

  const RepCompleted({
    required this.totalReps,
    required this.repDuration,
    required this.peakAngle,
  });

  @override
  String toString() =>
      'RepCompleted(totalReps: $totalReps, duration: ${repDuration.inMilliseconds}ms, '
      'peakAngle: ${peakAngle.toStringAsFixed(1)}°)';
}

/// Emitted when the exercise phase changes.
///
/// For lateral raises: waiting → down → rising → up → falling → down
class PhaseChanged extends RepEvent {
  /// The new phase name (exercise-specific).
  final String phaseName;

  /// Current angle at the time of phase change.
  final double currentAngle;

  const PhaseChanged({required this.phaseName, required this.currentAngle});

  @override
  String toString() =>
      'PhaseChanged(phase: $phaseName, angle: ${currentAngle.toStringAsFixed(1)}°)';
}
