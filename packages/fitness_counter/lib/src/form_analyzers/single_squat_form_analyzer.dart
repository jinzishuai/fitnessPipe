import 'dart:math';

import '../config/single_squat_sensitivity_config.dart';
import '../core/angle_calculator.dart';
import '../core/smoothing.dart';
import '../models/form_feedback.dart';
import '../models/landmark.dart';

/// Analyzes single-squat form frame-by-frame.
///
/// Three biomechanical rules are checked:
///
/// 1. **Knee Valgus** – knees caving inward relative to ankles (front-facing
///    camera required; both knees must be visible).
/// 2. **Trunk Forward Lean** – excessive forward lean measured as the angle of
///    the shoulder-centre → hip-centre segment from vertical.
/// 3. **Squat Depth** – whether the user achieves sufficient depth, evaluated
///    on ascent (triggered when the user comes back up without having reached
///    the target knee-angle threshold).
class SingleSquatFormAnalyzer {
  // Smoothers
  final AngleSmoother _trunkLeanSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _valgusLeftSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _valgusRightSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _kneeAngleSmoother = AngleSmoother(alpha: 0.2);

  SingleSquatSensitivity _sensitivity;

  SingleSquatSensitivity get sensitivity => _sensitivity;

  // Sustain-frame counters (to avoid flicker)
  int _valgusWarnFrames = 0;
  bool _valgusWarningActive = false;
  int _trunkLeanWarnFrames = 0;
  bool _trunkLeanWarningActive = false;

  // Depth tracking
  double _minKneeAngleInRep = 180.0;
  bool _wasDescending = false;
  bool _depthFeedbackGiven = false;

  static const int _sustainedFrameThreshold = 6;

  /// Angle threshold describing when the user is standing upright.
  final double standingThreshold;

  SingleSquatFormAnalyzer({
    SingleSquatSensitivity? sensitivity,
    this.standingThreshold = 170.0,
  }) : _sensitivity = sensitivity ?? const SingleSquatSensitivity.defaults();

  void updateSensitivity(SingleSquatSensitivity newSensitivity) {
    _sensitivity = newSensitivity;
  }

  /// Analyse a single frame and return form feedback.
  FormFeedback analyzeFrame(Map<LandmarkId, Landmark> landmarks) {
    if (!_hasRequiredLandmarks(landmarks)) {
      return const FormFeedback(
        status: FormStatus.warning,
        issues: [
          FormIssue(
            code: 'LOW_CONFIDENCE',
            message: 'Ensure full body is visible',
            severity: FormStatus.warning,
          ),
        ],
      );
    }

    final List<FormIssue> issues = [];
    final Map<String, double> metrics = {};

    _checkKneeValgus(landmarks, issues, metrics);
    _checkTrunkLean(landmarks, issues, metrics);
    _checkDepth(landmarks, issues, metrics);

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
    _trunkLeanSmoother.reset();
    _valgusLeftSmoother.reset();
    _valgusRightSmoother.reset();
    _kneeAngleSmoother.reset();
    _valgusWarnFrames = 0;
    _valgusWarningActive = false;
    _trunkLeanWarnFrames = 0;
    _trunkLeanWarningActive = false;
    _minKneeAngleInRep = 180.0;
    _wasDescending = false;
    _depthFeedbackGiven = false;
  }

  // ── Landmark Check ─────────────────────────────────────────────────────

  bool _hasRequiredLandmarks(Map<LandmarkId, Landmark> landmarks) {
    const required = [
      LandmarkId.leftShoulder,
      LandmarkId.rightShoulder,
      LandmarkId.leftHip,
      LandmarkId.rightHip,
      LandmarkId.leftKnee,
      LandmarkId.rightKnee,
      LandmarkId.leftAnkle,
      LandmarkId.rightAnkle,
    ];
    return required.every((id) => landmarks[id]?.isVisible ?? false);
  }

  // ── Rule 1: Knee Valgus ────────────────────────────────────────────────

  void _checkKneeValgus(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    final lKnee = landmarks[LandmarkId.leftKnee]!;
    final rKnee = landmarks[LandmarkId.rightKnee]!;
    final lHip = landmarks[LandmarkId.leftHip]!;
    final rHip = landmarks[LandmarkId.rightHip]!;

    final hipDistance = (lHip.x - rHip.x).abs();
    if (hipDistance < 0.01) return; // Hips too close together — unreliable

    // Knee valgus = knees collapsing inward past the hips.
    // Measured as: 1 - (kneeDistance / hipDistance).
    // When valgus ≈ 0 → knees about as wide as hips (neutral).
    // When valgus > 0 → knees narrower than hips (inward collapse).
    // When valgus < 0 → knees wider than hips (OK / normal stance).
    //
    // Using hip distance as reference avoids false positives from the
    // normal Q-angle (femur angles inward from hip to knee).
    final kneeDistance = (lKnee.x - rKnee.x).abs();
    final valgusRatio = 1.0 - (kneeDistance / hipDistance);

    final smoothedValgus = _valgusLeftSmoother.smooth(
      valgusRatio > 0 ? valgusRatio : 0.0,
    );
    // Keep right smoother in sync
    _valgusRightSmoother.smooth(valgusRatio > 0 ? valgusRatio : 0.0);

    metrics['valgus_ratio'] = smoothedValgus;
    metrics['valgus_left'] = smoothedValgus;
    metrics['valgus_right'] = smoothedValgus;

    // BAD check
    if (smoothedValgus > _sensitivity.kneeValgusBadRatio) {
      issues.add(
        const FormIssue(
          code: 'KNEE_VALGUS_BAD',
          message: 'Push your knees outward — they are caving in',
          severity: FormStatus.bad,
        ),
      );
      return;
    }

    // WARN check with hysteresis + sustained frames
    bool triggerCondition = false;
    if (_valgusWarningActive) {
      if (smoothedValgus < _sensitivity.kneeValgusWarnExitRatio) {
        _valgusWarningActive = false;
      } else {
        triggerCondition = true;
      }
    } else {
      if (smoothedValgus > _sensitivity.kneeValgusWarnRatio) {
        triggerCondition = true;
      }
    }

    if (triggerCondition) {
      _valgusWarnFrames++;
      if (_valgusWarnFrames >= _sustainedFrameThreshold) {
        _valgusWarningActive = true;
        issues.add(
          const FormIssue(
            code: 'KNEE_VALGUS_WARN',
            message: 'Keep your knees over your toes',
            severity: FormStatus.warning,
          ),
        );
      }
    } else {
      if (_valgusWarnFrames > 0) _valgusWarnFrames--;
    }
  }

  // ── Rule 2: Trunk Forward Lean ─────────────────────────────────────────

  void _checkTrunkLean(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    final lShoulder = landmarks[LandmarkId.leftShoulder]!;
    final rShoulder = landmarks[LandmarkId.rightShoulder]!;
    final lHip = landmarks[LandmarkId.leftHip]!;
    final rHip = landmarks[LandmarkId.rightHip]!;

    final shoulderCenterX = (lShoulder.x + rShoulder.x) / 2;
    final shoulderCenterY = (lShoulder.y + rShoulder.y) / 2;
    final hipCenterX = (lHip.x + rHip.x) / 2;
    final hipCenterY = (lHip.y + rHip.y) / 2;

    // Angle from vertical (purely in the image plane).
    // atan2(horizontal distance, vertical distance) — 0° is perfectly upright.
    final trunkDx = (shoulderCenterX - hipCenterX).abs();
    final trunkDy = (shoulderCenterY - hipCenterY).abs();
    final trunkLeanDeg = atan2(trunkDx, trunkDy) * 180.0 / pi;

    final smoothedLean = _trunkLeanSmoother.smooth(trunkLeanDeg);
    metrics['trunk_lean'] = smoothedLean;

    // BAD check
    if (smoothedLean > _sensitivity.trunkLeanBadAngle) {
      issues.add(
        const FormIssue(
          code: 'TRUNK_LEAN_BAD',
          message: 'Keep your chest up — you are leaning too far forward',
          severity: FormStatus.bad,
        ),
      );
      return;
    }

    // WARN check with hysteresis + sustained frames
    bool triggerCondition = false;
    if (_trunkLeanWarningActive) {
      if (smoothedLean < _sensitivity.trunkLeanWarnExitAngle) {
        _trunkLeanWarningActive = false;
      } else {
        triggerCondition = true;
      }
    } else {
      if (smoothedLean > _sensitivity.trunkLeanWarnAngle) {
        triggerCondition = true;
      }
    }

    if (triggerCondition) {
      _trunkLeanWarnFrames++;
      if (_trunkLeanWarnFrames >= _sustainedFrameThreshold) {
        _trunkLeanWarningActive = true;
        issues.add(
          const FormIssue(
            code: 'TRUNK_LEAN_WARN',
            message: 'Keep your back straighter',
            severity: FormStatus.warning,
          ),
        );
      }
    } else {
      if (_trunkLeanWarnFrames > 0) _trunkLeanWarnFrames--;
    }
  }

  // ── Rule 3: Squat Depth ────────────────────────────────────────────────

  void _checkDepth(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    // Calculate current average knee angle
    final kneeAngle = calculateAverageKneeAngle(
      leftHip: landmarks[LandmarkId.leftHip],
      leftKnee: landmarks[LandmarkId.leftKnee],
      leftAnkle: landmarks[LandmarkId.leftAnkle],
      rightHip: landmarks[LandmarkId.rightHip],
      rightKnee: landmarks[LandmarkId.rightKnee],
      rightAnkle: landmarks[LandmarkId.rightAnkle],
    );

    final smoothedKneeAngle = _kneeAngleSmoother.smooth(kneeAngle);
    metrics['knee_angle'] = smoothedKneeAngle;

    if (!_wasDescending) {
      // Not yet descending — check if we're starting a descent (10 degrees below standing)
      if (smoothedKneeAngle < standingThreshold - 10.0) {
        _wasDescending = true;
        _minKneeAngleInRep = smoothedKneeAngle;
      }
    } else {
      // Currently in a descent or at bottom
      if (smoothedKneeAngle < _minKneeAngleInRep) {
        _minKneeAngleInRep = smoothedKneeAngle;
      }

      // Detect ascending phase: angle returning past standing threshold - 5
      if (smoothedKneeAngle > standingThreshold - 5.0) {
        // Check depth: only give feedback once per rep
        if (!_depthFeedbackGiven &&
            _minKneeAngleInRep > _sensitivity.depthWarnAngle &&
            _minKneeAngleInRep > _sensitivity.depthGoodAngle) {
          issues.add(
            const FormIssue(
              code: 'DEPTH_WARN',
              message: 'Try to squat lower for better activation',
              severity: FormStatus.warning,
            ),
          );
          _depthFeedbackGiven = true;
        }

        // Reset for next rep once mostly upright
        if (smoothedKneeAngle > standingThreshold) {
          _wasDescending = false;
          _minKneeAngleInRep = 180.0;
          _depthFeedbackGiven = false;
        }
      }
    }

    // Assign min angle to metric after all potential updates
    metrics['min_knee_angle_in_rep'] = _minKneeAngleInRep;
  }
}
