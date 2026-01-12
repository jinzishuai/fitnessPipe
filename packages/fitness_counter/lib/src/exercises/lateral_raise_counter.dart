import '../core/angle_calculator.dart';
import '../core/exercise_counter.dart';
import '../core/smoothing.dart';
import '../models/counter_event.dart';
import '../models/counter_state.dart';
import '../models/landmark.dart';
import '../models/pose_frame.dart';

/// Lateral raise exercise rep counter.
///
/// Tracks shoulder abduction angle to count repetitions of lateral raises.
/// Uses a state machine with 5 phases:
/// - waiting: User getting into position
/// - down: Arms at sides, ready to start
/// - rising: Raising arms
/// - up: Arms at target height
/// - falling: Lowering arms (rep counted when returning to down)
///
/// Example usage:
/// ```dart
/// final counter = LateralRaiseCounter();
///
/// // In your pose processing loop:
/// final event = counter.processPose(poseFrame);
/// if (event is RepCompleted) {
///   print('Rep ${event.totalReps} completed!');
/// }
/// ```
class LateralRaiseCounter implements ExerciseCounter {
  // State
  LateralRaiseState _state = const LateralRaiseState.initial();
  final AngleSmoother _smoother;

  // Timing state
  DateTime? _stableStartTime; // For ready state hold time
  DateTime? _repStartTime; // When current rep started (entering rising)
  DateTime? _lastStateChange; // For debouncing
  double _peakAngle = 0.0; // Peak angle during current rep

  // Thresholds (degrees)
  final double bottomThreshold;
  final double risingThreshold; // Higher than bottom for hysteresis
  final double topThreshold;
  final double fallingThreshold; // Lower than top for hysteresis

  // Timing parameters
  final Duration readyHoldTime;
  final Duration minRepDuration;
  final Duration maxRepDuration;
  final Duration debounceTime;

  LateralRaiseCounter({
    double? bottomThreshold,
    double? topThreshold,
    double smoothingAlpha = 0.3,
    Duration? readyHoldTime,
    Duration? minRepDuration,
    Duration? maxRepDuration,
    Duration? debounceTime,
  }) : bottomThreshold = bottomThreshold ?? 20.0,
       topThreshold = topThreshold ?? 80.0,
       risingThreshold = (bottomThreshold ?? 20.0) + 5.0, // Hysteresis
       fallingThreshold = (topThreshold ?? 80.0) - 5.0, // Hysteresis
       readyHoldTime = readyHoldTime ?? const Duration(milliseconds: 500),
       minRepDuration = minRepDuration ?? const Duration(milliseconds: 500),
       maxRepDuration = maxRepDuration ?? const Duration(seconds: 5),
       debounceTime = debounceTime ?? const Duration(milliseconds: 100),
       _smoother = AngleSmoother(alpha: smoothingAlpha);

  @override
  Set<LandmarkId> get requiredLandmarks => {
    LandmarkId.leftShoulder,
    LandmarkId.rightShoulder,
    LandmarkId.leftElbow,
    LandmarkId.rightElbow,
    LandmarkId.leftHip,
    LandmarkId.rightHip,
  };

  @override
  LateralRaiseState get state => _state;

  @override
  RepEvent? processPose(PoseFrame frame) {
    // Check if we have all required landmarks
    if (!frame.hasLandmarks(requiredLandmarks)) {
      return null; // Skip this frame
    }

    // Extract landmarks
    final leftShoulder = frame[LandmarkId.leftShoulder];
    final rightShoulder = frame[LandmarkId.rightShoulder];
    final leftElbow = frame[LandmarkId.leftElbow];
    final rightElbow = frame[LandmarkId.rightElbow];
    final leftHip = frame[LandmarkId.leftHip];
    final rightHip = frame[LandmarkId.rightHip];

    // Calculate average shoulder angle
    final rawAngle = calculateAverageShoulderAngle(
      leftShoulder: leftShoulder,
      leftElbow: leftElbow,
      leftHip: leftHip,
      rightShoulder: rightShoulder,
      rightElbow: rightElbow,
      rightHip: rightHip,
    );

    // Apply smoothing
    final smoothedAngle = _smoother.smooth(rawAngle);

    // Update current state angles
    _state = _state.copyWith(
      currentAngle: rawAngle,
      smoothedAngle: smoothedAngle,
    );

    // Process through state machine
    return _processStateMachine(smoothedAngle, frame.timestamp);
  }

  RepEvent? _processStateMachine(double angle, DateTime timestamp) {
    final currentPhase = _state.phase;
    RepEvent? event;

    switch (currentPhase) {
      case LateralRaisePhase.waiting:
        event = _processWaiting(angle, timestamp);
        break;
      case LateralRaisePhase.down:
        event = _processDown(angle, timestamp);
        break;
      case LateralRaisePhase.rising:
        event = _processRising(angle);
        break;
      case LateralRaisePhase.up:
        event = _processUp(angle);
        break;
      case LateralRaisePhase.falling:
        event = _processFalling(angle, timestamp);
        break;
    }

    return event;
  }

  RepEvent? _processWaiting(double angle, DateTime timestamp) {
    // Ready state: user must hold arms down for readyHoldTime
    if (angle < bottomThreshold) {
      _stableStartTime ??= timestamp;

      if (timestamp.difference(_stableStartTime!) >= readyHoldTime) {
        // Transition to down
        return _changePhase(LateralRaisePhase.down, angle, timestamp);
      }
    } else {
      _stableStartTime = null; // Reset if arms not down
    }
    return null;
  }

  RepEvent? _processDown(double angle, DateTime timestamp) {
    if (angle > risingThreshold && _canChangeState(timestamp)) {
      // Start rising - begin rep timer
      _repStartTime = timestamp;
      _peakAngle = angle;
      return _changePhase(LateralRaisePhase.rising, angle, timestamp);
    }
    return null;
  }

  RepEvent? _processRising(double angle) {
    // Track peak angle
    if (angle > _peakAngle) {
      _peakAngle = angle;
    }

    if (angle >= topThreshold) {
      // Reached top
      return _changePhase(LateralRaisePhase.up, angle, DateTime.now());
    } else if (angle < bottomThreshold) {
      // Aborted rep - went back down without reaching top
      _repStartTime = null;
      _peakAngle = 0.0;
      return _changePhase(LateralRaisePhase.down, angle, DateTime.now());
    }
    return null;
  }

  RepEvent? _processUp(double angle) {
    if (angle < fallingThreshold) {
      // Starting to lower
      return _changePhase(LateralRaisePhase.falling, angle, DateTime.now());
    }
    return null;
  }

  RepEvent? _processFalling(double angle, DateTime timestamp) {
    // Track peak angle (in case they go back up)
    if (angle > _peakAngle) {
      _peakAngle = angle;
    }

    if (angle <= bottomThreshold && _canChangeState(timestamp)) {
      // Rep completed!
      return _completeRep(timestamp);
    } else if (angle >= topThreshold) {
      // Went back up without completing
      return _changePhase(LateralRaisePhase.up, angle, timestamp);
    }
    return null;
  }

  RepEvent _completeRep(DateTime timestamp) {
    // Validate rep duration
    if (_repStartTime != null) {
      final duration = timestamp.difference(_repStartTime!);

      // Check if too fast or too slow
      if (duration < minRepDuration) {
        // Too fast - likely noise, don't count
        _repStartTime = null;
        _peakAngle = 0.0;
        return _changePhase(
          LateralRaisePhase.down,
          _state.smoothedAngle,
          timestamp,
        );
      }

      if (duration > maxRepDuration) {
        // Timed out - reset
        _repStartTime = null;
        _peakAngle = 0.0;
        return _changePhase(
          LateralRaisePhase.waiting,
          _state.smoothedAngle,
          timestamp,
        );
      }

      // Valid rep!
      final newCount = _state.repCount + 1;
      _state = _state.copyWith(
        repCount: newCount,
        phase: LateralRaisePhase.down,
      );
      _lastStateChange = timestamp;

      final event = RepCompleted(
        totalReps: newCount,
        repDuration: duration,
        peakAngle: _peakAngle,
      );

      // Reset for next rep
      _repStartTime = null;
      _peakAngle = 0.0;

      return event;
    }

    // Shouldn't happen, but fail gracefully
    return _changePhase(
      LateralRaisePhase.down,
      _state.smoothedAngle,
      timestamp,
    );
  }

  RepEvent _changePhase(
    LateralRaisePhase newPhase,
    double angle,
    DateTime timestamp,
  ) {
    _state = _state.copyWith(phase: newPhase);
    _lastStateChange = timestamp;

    // Emit ExerciseStarted when entering down for the first time
    if (newPhase == LateralRaisePhase.down && _state.repCount == 0) {
      return const ExerciseStarted();
    }

    return PhaseChanged(phaseName: newPhase.name, currentAngle: angle);
  }

  bool _canChangeState(DateTime timestamp) {
    if (_lastStateChange == null) return true;
    return timestamp.difference(_lastStateChange!) > debounceTime;
  }

  @override
  void reset() {
    _state = const LateralRaiseState.initial();
    _smoother.reset();
    _stableStartTime = null;
    _repStartTime = null;
    _lastStateChange = null;
    _peakAngle = 0.0;
  }
}
