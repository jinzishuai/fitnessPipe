import 'dart:math';

import '../config/bench_press_sensitivity_config.dart';
import '../core/angle_calculator.dart';
import '../core/smoothing.dart';
import '../models/form_feedback.dart';
import '../models/landmark.dart';

/// Analyzes bench press form frame-by-frame.
class BenchPressFormAnalyzer {
  final AngleSmoother _flareLeftSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _flareRightSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _unevenSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _hipRiseSmoother = AngleSmoother(alpha: 0.1);

  BenchPressSensitivity _sensitivity;

  BenchPressSensitivity get sensitivity => _sensitivity;

  // State
  double? _baselineHipDistance;
  int _flareWarnFrames = 0;
  bool _flareWarningActive = false;
  int _unevenWarnFrames = 0;
  bool _unevenWarningActive = false;

  static const int _sustainedFrameThreshold = 6;

  BenchPressFormAnalyzer({BenchPressSensitivity? sensitivity})
    : _sensitivity = sensitivity ?? const BenchPressSensitivity.defaults();

  void updateSensitivity(BenchPressSensitivity newSensitivity) {
    _sensitivity = newSensitivity;
  }

  FormFeedback analyzeFrame(Map<LandmarkId, Landmark> landmarks) {
    if (!_hasRequiredLandmarks(landmarks)) {
      return const FormFeedback(
        status: FormStatus.warning,
        issues: [
          FormIssue(
            code: 'LOW_CONFIDENCE',
            message: 'Ensure upper body and hips are visible',
            severity: FormStatus.warning,
          ),
        ],
      );
    }

    final List<FormIssue> issues = [];
    final Map<String, double> metrics = {};

    _checkElbowFlare(landmarks, issues, metrics);
    _checkUnevenExtension(landmarks, issues, metrics);
    _checkHipsRising(landmarks, issues, metrics);

    FormStatus status = FormStatus.good;
    for (final issue in issues) {
      if (issue.severity == FormStatus.bad) {
        status = FormStatus.bad;
        break;
      } else if (issue.severity == FormStatus.warning &&
          status != FormStatus.bad) {
        status = FormStatus.warning;
      }
    }

    return FormFeedback(status: status, issues: issues, debugMetrics: metrics);
  }

  void reset() {
    _flareLeftSmoother.reset();
    _flareRightSmoother.reset();
    _unevenSmoother.reset();
    _hipRiseSmoother.reset();
    _baselineHipDistance = null;
    _flareWarnFrames = 0;
    _flareWarningActive = false;
    _unevenWarnFrames = 0;
    _unevenWarningActive = false;
  }

  bool _hasRequiredLandmarks(Map<LandmarkId, Landmark> landmarks) {
    const required = [
      LandmarkId.leftShoulder,
      LandmarkId.rightShoulder,
      LandmarkId.leftElbow,
      LandmarkId.rightElbow,
      LandmarkId.leftWrist,
      LandmarkId.rightWrist,
      LandmarkId.leftHip,
      LandmarkId.rightHip,
    ];
    return required.every((id) => landmarks[id]?.isVisible ?? false);
  }

  void _checkElbowFlare(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    // Flare angle is the angle between the torso (shoulder to hip) and humerus (shoulder to elbow).
    // calculateShoulderAngle calculates this exactly.
    final lAngle = calculateShoulderAngle(
      shoulder: landmarks[LandmarkId.leftShoulder]!,
      elbow: landmarks[LandmarkId.leftElbow]!,
      hip: landmarks[LandmarkId.leftHip]!,
    );

    final rAngle = calculateShoulderAngle(
      shoulder: landmarks[LandmarkId.rightShoulder]!,
      elbow: landmarks[LandmarkId.rightElbow]!,
      hip: landmarks[LandmarkId.rightHip]!,
    );

    final lSm = _flareLeftSmoother.smooth(lAngle);
    final rSm = _flareRightSmoother.smooth(rAngle);

    metrics['flare_left'] = lSm;
    metrics['flare_right'] = rSm;

    final maxFlare = max(lSm, rSm);

    // BAD Check
    if (maxFlare > _sensitivity.flareBadAngle) {
      issues.add(
        const FormIssue(
          code: 'ELBOW_FLARE_BAD',
          message: 'Tuck your elbows — flaring is dangerous for shoulders',
          severity: FormStatus.bad,
        ),
      );
      return;
    }

    // WARN Check with Hysteresis
    bool triggerCondition = false;
    if (_flareWarningActive) {
      if (lSm < _sensitivity.flareWarnExitAngle &&
          rSm < _sensitivity.flareWarnExitAngle) {
        _flareWarningActive = false;
      } else {
        triggerCondition = true;
      }
    } else {
      if (lSm > _sensitivity.flareWarnAngle ||
          rSm > _sensitivity.flareWarnAngle) {
        triggerCondition = true;
      }
    }

    if (triggerCondition) {
      _flareWarnFrames++;
      if (_flareWarnFrames >= _sustainedFrameThreshold) {
        _flareWarningActive = true;
        issues.add(
          const FormIssue(
            code: 'ELBOW_FLARE_WARN',
            message: 'Tuck your elbows closer to your body',
            severity: FormStatus.warning,
          ),
        );
      }
    } else {
      if (_flareWarnFrames > 0) _flareWarnFrames--;
    }
  }

  void _checkUnevenExtension(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    final lExtension = calculateElbowAngle(
      shoulder: landmarks[LandmarkId.leftShoulder]!,
      elbow: landmarks[LandmarkId.leftElbow]!,
      wrist: landmarks[LandmarkId.leftWrist]!,
    );
    final rExtension = calculateElbowAngle(
      shoulder: landmarks[LandmarkId.rightShoulder]!,
      elbow: landmarks[LandmarkId.rightElbow]!,
      wrist: landmarks[LandmarkId.rightWrist]!,
    );

    final diff = (lExtension - rExtension).abs();
    final smoothedDiff = _unevenSmoother.smooth(diff);
    metrics['uneven_diff'] = smoothedDiff;

    if (smoothedDiff > _sensitivity.unevenBadAngle) {
      issues.add(
        const FormIssue(
          code: 'UNEVEN_PRESS_BAD',
          message: 'Push evenly with both arms',
          severity: FormStatus.bad,
        ),
      );
      return;
    }

    bool triggerCondition = false;
    if (_unevenWarningActive) {
      if (smoothedDiff < _sensitivity.unevenWarnExitAngle) {
        _unevenWarningActive = false;
      } else {
        triggerCondition = true;
      }
    } else {
      if (smoothedDiff > _sensitivity.unevenWarnAngle) {
        triggerCondition = true;
      }
    }

    if (triggerCondition) {
      _unevenWarnFrames++;
      if (_unevenWarnFrames >= _sustainedFrameThreshold) {
        _unevenWarningActive = true;
        issues.add(
          const FormIssue(
            code: 'UNEVEN_PRESS_WARN',
            message: 'Keep the bar level',
            severity: FormStatus.warning,
          ),
        );
      }
    } else {
      if (_unevenWarnFrames > 0) _unevenWarnFrames--;
    }
  }

  void _checkHipsRising(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    final lShoulder = landmarks[LandmarkId.leftShoulder]!;
    final rShoulder = landmarks[LandmarkId.rightShoulder]!;
    final lHip = landmarks[LandmarkId.leftHip]!;
    final rHip = landmarks[LandmarkId.rightHip]!;

    final shoulderCenterY = (lShoulder.y + rShoulder.y) / 2.0;
    final hipCenterY = (lHip.y + rHip.y) / 2.0;

    // Distance in Y axis
    final rawDistance = (hipCenterY - shoulderCenterY).abs();
    final smoothedDistance = _hipRiseSmoother.smooth(rawDistance);

    metrics['hip_shoulder_dist'] = smoothedDistance;

    // Use maximum distance seen effectively as baseline when arms are extended
    // Usually hips start on the bench.
    // We can assume the max distance we see while setting up is the baseline (flat on bench).
    if (_baselineHipDistance == null ||
        smoothedDistance > _baselineHipDistance!) {
      _baselineHipDistance = smoothedDistance;
    }

    if (_baselineHipDistance == null || _baselineHipDistance! < 0.05) return;

    final drop =
        (_baselineHipDistance! - smoothedDistance) / _baselineHipDistance!;
    metrics['hip_rise_drop'] = drop;

    if (drop > _sensitivity.hipRiseBadDrop) {
      issues.add(
        const FormIssue(
          code: 'HIPS_RISING_BAD',
          message: 'Keep your glutes on the bench',
          severity: FormStatus.bad,
        ),
      );
    } else if (drop > _sensitivity.hipRiseWarnDrop) {
      issues.add(
        const FormIssue(
          code: 'HIPS_RISING_WARN',
          message: 'Don\'t lift your hips',
          severity: FormStatus.warning,
        ),
      );
    }
  }
}
