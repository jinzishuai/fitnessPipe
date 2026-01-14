import '../core/angle_calculator.dart';
import '../core/exercise_counter.dart';
import '../core/smoothing.dart';
import '../models/counter_event.dart';
import '../models/counter_state.dart';
import '../models/landmark.dart';
import '../models/pose_frame.dart';

/// Single Squat exercise rep counter.
///
/// Tracks knee angle to count repetitions of single leg squats.
/// Uses the minimum angle of either knee to detect the squatting leg.
class SingleSquatCounter implements ExerciseCounter {
  // State
  SingleSquatState _state = const SingleSquatState.initial();
  final AngleSmoother _leftSmoother;
  final AngleSmoother _rightSmoother;

  // Timing state
  DateTime? _stableStartTime;
  DateTime? _repStartTime;
  DateTime? _lastStateChange;
  double _minAngle = 180.0; // Track lowest angle (deepest squat)

  // Thresholds (degrees)
  // 180 is straight, < 90 is deep squat.
  // Based on video analysis (shallow squat ~158), we use generous thresholds.
  final double topThreshold; // e.g. 170
  final double bottomThreshold; // e.g. 160
  final double descendingThreshold; // top - hysteresis
  final double ascendingThreshold; // bottom + hysteresis

  // Timing parameters
  final Duration readyHoldTime;
  final Duration minRepDuration;
  final Duration maxRepDuration;
  final Duration debounceTime;

  SingleSquatCounter({
    double? topThreshold,
    double? bottomThreshold,
    double smoothingAlpha = 0.2, // More smoothing for legs
    Duration? readyHoldTime,
    Duration? minRepDuration,
    Duration? maxRepDuration,
    Duration? debounceTime,
  }) : topThreshold = topThreshold ?? 170.0,
       bottomThreshold = bottomThreshold ?? 160.0,
       descendingThreshold = (topThreshold ?? 170.0) - 5.0,
       ascendingThreshold = (bottomThreshold ?? 160.0) + 5.0,
       readyHoldTime = readyHoldTime ?? const Duration(milliseconds: 500),
       minRepDuration = minRepDuration ?? const Duration(milliseconds: 500),
       maxRepDuration = maxRepDuration ?? const Duration(seconds: 5),
       debounceTime = debounceTime ?? const Duration(milliseconds: 100),
       _leftSmoother = AngleSmoother(alpha: smoothingAlpha),
       _rightSmoother = AngleSmoother(alpha: smoothingAlpha);

  @override
  Set<LandmarkId> get requiredLandmarks => {
    LandmarkId.leftHip,
    LandmarkId.leftKnee,
    LandmarkId.leftAnkle,
    LandmarkId.rightHip,
    LandmarkId.rightKnee,
    LandmarkId.rightAnkle,
  };

  @override
  SingleSquatState get state => _state;

  @override
  RepEvent? processPose(PoseFrame frame) {
    if (!frame.hasLandmarks(requiredLandmarks)) {
      return null;
    }

    final leftHip = frame[LandmarkId.leftHip];
    final leftKnee = frame[LandmarkId.leftKnee];
    final leftAnkle = frame[LandmarkId.leftAnkle];
    final rightHip = frame[LandmarkId.rightHip];
    final rightKnee = frame[LandmarkId.rightKnee];
    final rightAnkle = frame[LandmarkId.rightAnkle];

    // Calculate angles
    var leftAngle = 180.0;
    var rightAngle = 180.0;

    if (leftHip != null && leftKnee != null && leftAnkle != null) {
      leftAngle = calculateKneeAngle(
        hip: leftHip,
        knee: leftKnee,
        ankle: leftAnkle,
      );
    }

    if (rightHip != null && rightKnee != null && rightAnkle != null) {
      rightAngle = calculateKneeAngle(
        hip: rightHip,
        knee: rightKnee,
        ankle: rightAnkle,
      );
    }

    // Smooth angles
    final smoothLeft = _leftSmoother.smooth(leftAngle);
    final smoothRight = _rightSmoother.smooth(rightAngle);

    // Use the "working" leg (the one bending more)
    final currentAngle = leftAngle < rightAngle ? leftAngle : rightAngle;
    final smoothAngle = smoothLeft < smoothRight ? smoothLeft : smoothRight;

    _state = _state.copyWith(
      currentAngle: currentAngle,
      smoothedAngle: smoothAngle,
    );

    return _processStateMachine(smoothAngle, frame.timestamp);
  }

  RepEvent? _processStateMachine(double angle, DateTime timestamp) {
    final currentPhase = _state.phase;
    RepEvent? event;

    switch (currentPhase) {
      case SingleSquatPhase.waiting:
        event = _processWaiting(angle, timestamp);
        break;
      case SingleSquatPhase.standing:
        event = _processStanding(angle, timestamp);
        break;
      case SingleSquatPhase.descending:
        event = _processDescending(angle);
        break;
      case SingleSquatPhase.bottom:
        event = _processBottom(angle);
        break;
      case SingleSquatPhase.ascending:
        event = _processAscending(angle, timestamp);
        break;
    }

    return event;
  }

  RepEvent? _processWaiting(double angle, DateTime timestamp) {
    // Must stand straight (high angle) to start
    if (angle > topThreshold) {
      _stableStartTime ??= timestamp;

      if (timestamp.difference(_stableStartTime!) >= readyHoldTime) {
        return _changePhase(SingleSquatPhase.standing, angle, timestamp);
      }
    } else {
      _stableStartTime = null;
    }
    return null;
  }

  RepEvent? _processStanding(double angle, DateTime timestamp) {
    if (angle < descendingThreshold && _canChangeState(timestamp)) {
      // Start descending
      _repStartTime = timestamp;
      _minAngle = angle;
      return _changePhase(SingleSquatPhase.descending, angle, timestamp);
    }
    return null;
  }

  RepEvent? _processDescending(double angle) {
    if (angle < _minAngle) {
      _minAngle = angle;
    }

    if (angle <= bottomThreshold) {
      // Reached bottom
      return _changePhase(SingleSquatPhase.bottom, angle, DateTime.now());
    } else if (angle > topThreshold) {
      // Aborted, went back up
      _repStartTime = null;
      _minAngle = 180.0;
      return _changePhase(SingleSquatPhase.standing, angle, DateTime.now());
    }
    return null;
  }

  RepEvent? _processBottom(double angle) {
    if (angle < _minAngle) {
      _minAngle = angle;
    }

    if (angle > ascendingThreshold) {
      // Starting to go up
      return _changePhase(SingleSquatPhase.ascending, angle, DateTime.now());
    }
    return null;
  }

  RepEvent? _processAscending(double angle, DateTime timestamp) {
    if (angle >= topThreshold && _canChangeState(timestamp)) {
      // Rep completed
      return _completeRep(timestamp);
    } else if (angle < bottomThreshold) {
      // Went back down
      return _changePhase(SingleSquatPhase.bottom, angle, timestamp);
    }
    return null;
  }

  RepEvent _completeRep(DateTime timestamp) {
    if (_repStartTime != null) {
      final duration = timestamp.difference(_repStartTime!);

      if (duration < minRepDuration) {
        // Too fast
        _repStartTime = null;
        _minAngle = 180.0;
        return _changePhase(
          SingleSquatPhase.standing,
          _state.smoothedAngle,
          timestamp,
        );
      }

      if (duration > maxRepDuration) {
        // Timed out
        _repStartTime = null;
        _minAngle = 180.0;
        return _changePhase(
          SingleSquatPhase.waiting,
          _state.smoothedAngle,
          timestamp,
        );
      }

      final newCount = _state.repCount + 1;
      _state = _state.copyWith(
        repCount: newCount,
        phase: SingleSquatPhase.standing,
      );
      _lastStateChange = timestamp;

      final event = RepCompleted(
        totalReps: newCount,
        repDuration: duration,
        peakAngle: _minAngle,
      );

      _repStartTime = null;
      _minAngle = 180.0;

      return event;
    }

    return _changePhase(
      SingleSquatPhase.standing,
      _state.smoothedAngle,
      timestamp,
    );
  }

  RepEvent _changePhase(
    SingleSquatPhase newPhase,
    double angle,
    DateTime timestamp,
  ) {
    _state = _state.copyWith(phase: newPhase);
    _lastStateChange = timestamp;

    if (newPhase == SingleSquatPhase.standing && _state.repCount == 0) {
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
    _state = const SingleSquatState.initial();
    _leftSmoother.reset();
    _rightSmoother.reset();
    _stableStartTime = null;
    _repStartTime = null;
    _lastStateChange = null;
    _minAngle = 180.0;
  }
}
