import '../core/angle_calculator.dart';
import '../core/exercise_counter.dart';
import '../core/smoothing.dart';
import '../models/counter_event.dart';
import '../models/counter_state.dart';
import '../models/landmark.dart';
import '../models/pose_frame.dart';

/// Bench press exercise rep counter.
///
/// Tracks elbow extension angle to count repetitions.
/// Uses a state machine with 5 phases:
/// - waiting: User getting into position (arms not yet straight)
/// - up: Arms extended, ready to start rep
/// - falling: Lowering bar to chest
/// - down: Bar at chest (arms bent)
/// - rising: Pressing bar up (rep counted when returning to up)
class BenchPressCounter implements ExerciseCounter {
  // State
  BenchPressState _state = const BenchPressState.initial();
  final AngleSmoother _smoother;

  // Timing state
  DateTime? _stableStartTime; // For ready state hold time
  DateTime? _repStartTime; // When current rep started (entering falling)
  DateTime? _lastStateChange; // For debouncing
  double _peakAngle = 180.0; // Minimum angle reached during current rep

  // Thresholds (degrees)
  final double topThreshold;
  final double fallingThreshold; // Lower than top for hysteresis
  final double bottomThreshold;
  final double risingThreshold; // Higher than bottom for hysteresis

  // Timing parameters
  final Duration readyHoldTime;
  final Duration minRepDuration;
  final Duration maxRepDuration;
  final Duration debounceTime;

  BenchPressCounter({
    double? topThreshold,
    double? bottomThreshold,
    double smoothingAlpha = 0.3,
    int smoothingWarmupFrames = 5,
    Duration? readyHoldTime,
    Duration? minRepDuration,
    Duration? maxRepDuration,
    Duration? debounceTime,
  }) : topThreshold = topThreshold ?? 160.0,
       bottomThreshold = bottomThreshold ?? 100.0,
       fallingThreshold = (topThreshold ?? 160.0) - 5.0,
       risingThreshold = (bottomThreshold ?? 100.0) + 5.0,
       readyHoldTime = readyHoldTime ?? const Duration(milliseconds: 150),
       minRepDuration = minRepDuration ?? const Duration(milliseconds: 500),
       maxRepDuration = maxRepDuration ?? const Duration(seconds: 5),
       debounceTime = debounceTime ?? const Duration(milliseconds: 100),
       _smoother = AngleSmoother(
         alpha: smoothingAlpha,
         warmupFrames: smoothingWarmupFrames,
       );

  @override
  Set<LandmarkId> get requiredLandmarks => {
    LandmarkId.leftShoulder,
    LandmarkId.rightShoulder,
    LandmarkId.leftElbow,
    LandmarkId.rightElbow,
    LandmarkId.leftWrist,
    LandmarkId.rightWrist,
  };

  @override
  BenchPressState get state => _state;

  @override
  RepEvent? processPose(PoseFrame frame) {
    if (!frame.hasLandmarks(requiredLandmarks)) {
      return null;
    }

    final rawAngle = calculateAverageElbowAngle(
      leftShoulder: frame[LandmarkId.leftShoulder],
      leftElbow: frame[LandmarkId.leftElbow],
      leftWrist: frame[LandmarkId.leftWrist],
      rightShoulder: frame[LandmarkId.rightShoulder],
      rightElbow: frame[LandmarkId.rightElbow],
      rightWrist: frame[LandmarkId.rightWrist],
    );

    final smoothedAngle = _smoother.smooth(rawAngle);

    _state = _state.copyWith(
      currentAngle: rawAngle,
      smoothedAngle: smoothedAngle,
    );

    return _processStateMachine(smoothedAngle, frame.timestamp);
  }

  RepEvent? _processStateMachine(double angle, DateTime timestamp) {
    final currentPhase = _state.phase;
    RepEvent? event;

    switch (currentPhase) {
      case BenchPressPhase.waiting:
        event = _processWaiting(angle, timestamp);
        break;
      case BenchPressPhase.up:
        event = _processUp(angle, timestamp);
        break;
      case BenchPressPhase.falling:
        event = _processFalling(angle);
        break;
      case BenchPressPhase.down:
        event = _processDown(angle);
        break;
      case BenchPressPhase.rising:
        event = _processRising(angle, timestamp);
        break;
    }

    return event;
  }

  RepEvent? _processWaiting(double angle, DateTime timestamp) {
    if (angle > topThreshold) {
      _stableStartTime ??= timestamp;

      if (timestamp.difference(_stableStartTime!) >= readyHoldTime) {
        return _changePhase(BenchPressPhase.up, angle, timestamp);
      }
    } else {
      _stableStartTime = null;
    }
    return null;
  }

  RepEvent? _processUp(double angle, DateTime timestamp) {
    if (angle < fallingThreshold && _canChangeState(timestamp)) {
      _repStartTime = timestamp;
      _peakAngle = angle;
      return _changePhase(BenchPressPhase.falling, angle, timestamp);
    }
    return null;
  }

  RepEvent? _processFalling(double angle) {
    // Track peak angle (minimum angle reached, max elbow bend)
    if (angle < _peakAngle) {
      _peakAngle = angle;
    }

    if (angle <= bottomThreshold) {
      return _changePhase(BenchPressPhase.down, angle, DateTime.now());
    } else if (angle > topThreshold) {
      _repStartTime = null;
      _peakAngle = 180.0;
      return _changePhase(BenchPressPhase.up, angle, DateTime.now());
    }
    return null;
  }

  RepEvent? _processDown(double angle) {
    if (angle > risingThreshold) {
      return _changePhase(BenchPressPhase.rising, angle, DateTime.now());
    }
    return null;
  }

  RepEvent? _processRising(double angle, DateTime timestamp) {
    if (angle < _peakAngle) {
      _peakAngle = angle;
    }

    if (angle >= topThreshold && _canChangeState(timestamp)) {
      return _completeRep(timestamp);
    } else if (angle <= bottomThreshold) {
      return _changePhase(BenchPressPhase.down, angle, timestamp);
    }
    return null;
  }

  RepEvent _completeRep(DateTime timestamp) {
    if (_repStartTime != null) {
      final duration = timestamp.difference(_repStartTime!);

      if (duration < minRepDuration) {
        _repStartTime = null;
        _peakAngle = 180.0;
        return _changePhase(
          BenchPressPhase.up,
          _state.smoothedAngle,
          timestamp,
        );
      }

      if (duration > maxRepDuration) {
        _repStartTime = null;
        _peakAngle = 180.0;
        return _changePhase(
          BenchPressPhase.waiting,
          _state.smoothedAngle,
          timestamp,
        );
      }

      final newCount = _state.repCount + 1;
      _state = _state.copyWith(repCount: newCount, phase: BenchPressPhase.up);
      _lastStateChange = timestamp;

      final event = RepCompleted(
        totalReps: newCount,
        repDuration: duration,
        peakAngle: _peakAngle,
      );

      _repStartTime = null;
      _peakAngle = 180.0;
      return event;
    }

    return _changePhase(BenchPressPhase.up, _state.smoothedAngle, timestamp);
  }

  RepEvent _changePhase(
    BenchPressPhase newPhase,
    double angle,
    DateTime timestamp,
  ) {
    _state = _state.copyWith(phase: newPhase);
    _lastStateChange = timestamp;

    if (newPhase == BenchPressPhase.up && _state.repCount == 0) {
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
    _state = const BenchPressState.initial();
    _smoother.reset();
    _stableStartTime = null;
    _repStartTime = null;
    _lastStateChange = null;
    _peakAngle = 180.0;
  }
}
