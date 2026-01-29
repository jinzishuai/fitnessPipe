import 'dart:math';

import '../core/smoothing.dart';
import '../models/landmark.dart';

/// Status of the user's form for a single frame.
enum FormStatus { good, warning, bad }

/// A specific issue detected with the form.
class FormIssue {
  final String code;
  final String message;
  final FormStatus severity;

  const FormIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  @override
  String toString() => '$code: $message ($severity)';
}

/// Complete feedback for a single frame.
class FormFeedback {
  final FormStatus status;
  final List<FormIssue> issues;
  final Map<String, double> debugMetrics;

  const FormFeedback({
    required this.status,
    this.issues = const [],
    this.debugMetrics = const {},
  });

  factory FormFeedback.empty() => const FormFeedback(status: FormStatus.good);
}

/// Analyzes lateral raise form frame-by-frame using biomechanical rules.
class LateralRaiseFormAnalyzer {
  // Smoothing for key metrics
  final AngleSmoother _leftElbowSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _rightElbowSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _trunkLeanSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _trunkRotationSmoother = AngleSmoother(alpha: 0.2);
  final AngleSmoother _neckLenSmoother = AngleSmoother(alpha: 0.2);

  // Constants / Thresholds
  static const double _elbowBadThreshold = 145.0; // Immediate BAD
  static const double _elbowSoftWarnEnter = 155.0; // Threshold to start warning
  static const double _elbowSoftWarnExit =
      158.0; // Threshold to clear warning (hysteresis)
  static const int _elbowWarnFrameThreshold = 6; // Sustain for ~0.2s

  static const double _trunkLeanWarning = 8.0;
  static const double _trunkLeanBad = 15.0;

  static const double _trunkShiftWarning = 0.10;
  static const double _trunkShiftBad = 0.18;

  static const double _shrugWarning = 0.10; // 10% drop in neck length
  static const double _shrugBad = 0.28; // 28% drop (less sensitive)
  static const int _shrugBadFrameThreshold = 8; // Sustain for ~0.25s

  // State
  double? _baselineNeckLength;
  int _shrugBadFrames = 0;
  int _elbowWarnFrames = 0;
  bool _elbowWarningActive = false; // For hysteresis

  /// Main entry point: Analyze a frame of landmarks
  FormFeedback analyzeFrame(Map<LandmarkId, Landmark> landmarks) {
    // 1. Check for required landmarks
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

    // 2. Rule: Straight Arms (Elbow Angle)
    _checkElbows(landmarks, issues, metrics);

    // 3. Rule: Stable Trunk (Lean, Shift, Rotation)
    _checkTrunk(landmarks, issues, metrics);

    // 4. Rule: No Shrugging
    _checkShrugging(landmarks, issues, metrics);

    // Determine overall status
    FormStatus status = FormStatus.good;
    for (final issue in issues) {
      if (issue.severity == FormStatus.bad) {
        status = FormStatus.bad;
        break; // One bad apple spoils the bunch
      } else if (issue.severity == FormStatus.warning &&
          status != FormStatus.bad) {
        status = FormStatus.warning;
      }
    }

    return FormFeedback(status: status, issues: issues, debugMetrics: metrics);
  }

  void reset() {
    _leftElbowSmoother.reset();
    _rightElbowSmoother.reset();
    _trunkLeanSmoother.reset();
    _trunkRotationSmoother.reset();
    _neckLenSmoother.reset();
    _baselineNeckLength = null;
    _shrugBadFrames = 0;
    _elbowWarnFrames = 0;
    _elbowWarningActive = false;
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

  // --- Rule Implementations ---

  void _checkElbows(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    // 1. Calculate raw angles
    final lShoulder = landmarks[LandmarkId.leftShoulder]!;
    final lElbow = landmarks[LandmarkId.leftElbow]!;
    final lWrist = landmarks[LandmarkId.leftWrist]!;

    final rShoulder = landmarks[LandmarkId.rightShoulder]!;
    final rElbow = landmarks[LandmarkId.rightElbow]!;
    final rWrist = landmarks[LandmarkId.rightWrist]!;

    final leftAngle = _calculateAngle(lShoulder, lElbow, lWrist);
    final rightAngle = _calculateAngle(rShoulder, rElbow, rWrist);

    metrics['elbow_left_raw'] = leftAngle;
    metrics['elbow_right_raw'] = rightAngle;

    // 2. Smooth separately
    final leftSm = _leftElbowSmoother.smooth(leftAngle);
    final rightSm = _rightElbowSmoother.smooth(rightAngle);

    metrics['elbow_left_smoothed'] = leftSm;
    metrics['elbow_right_smoothed'] = rightSm;

    // 3. Phase Gating
    // Re-using the same phase gate as shrugging for now
    // (This requires _checkShrugging or _isRaisingOrAtTop to have run/be run)
    // Ideally we calculate it once per frame.
    // Since analyzeFrame doesn't cache it, we'll recompute or rely on metric if order is guaranteed?
    // _isRaisingOrAtTop is stateless/idempotent.
    final isActivePhase = _isRaisingOrAtTop(landmarks, metrics);
    metrics['elbow_active_phase'] = isActivePhase ? 1.0 : 0.0;

    if (!isActivePhase) {
      // Not active: decay counters and return
      if (_elbowWarnFrames > 0) _elbowWarnFrames--;
      return;
    }

    // 4. Evaluate Rules (Active Only)

    // BAD Check: Safety critical, use min of smoothed
    final minSm = min(leftSm, rightSm);

    if (minSm < _elbowBadThreshold) {
      issues.add(
        const FormIssue(
          code: 'ELBOW_BENT',
          message: 'Keep your elbows straighter',
          severity: FormStatus.bad,
        ),
      );
      // If bad, we reset the warning counters/state to avoid double jeopardy?
      // Or keep them? Usually Bad supersedes Warning.
      return;
    }

    // WARNING Check: Soft bend
    // Condition: Either arm is bent enough to trigger entry, OR we are already in warning and haven't exited
    bool triggerCondition = false;

    if (_elbowWarningActive) {
      // Hysteresis: Stay active until both arms are > Exit Threshold
      if (leftSm > _elbowSoftWarnExit && rightSm > _elbowSoftWarnExit) {
        _elbowWarningActive = false;
      } else {
        triggerCondition = true;
      }
    } else {
      // Hysteresis: Enter if either arm < Enter Threshold
      if (leftSm < _elbowSoftWarnEnter || rightSm < _elbowSoftWarnEnter) {
        triggerCondition = true;
      }
    }

    if (triggerCondition) {
      _elbowWarnFrames++;
      // Trigger actual warning if sustained
      if (_elbowWarnFrames >= _elbowWarnFrameThreshold) {
        _elbowWarningActive = true;
        issues.add(
          const FormIssue(
            code: 'ELBOW_SOFT',
            message: 'Straighten arms slightly',
            severity: FormStatus.warning,
          ),
        );
      }
    } else {
      // Decay if condition not met (and not locked in by hysteresis)
      if (_elbowWarnFrames > 0) _elbowWarnFrames--;
    }

    metrics['elbow_warn_frames'] = _elbowWarnFrames.toDouble();
  }

  void _checkTrunk(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    final lShoulder = landmarks[LandmarkId.leftShoulder]!;
    final rShoulder = landmarks[LandmarkId.rightShoulder]!;
    final lHip = landmarks[LandmarkId.leftHip]!;
    final rHip = landmarks[LandmarkId.rightHip]!;

    final shoulderCenter = _midpoint(lShoulder, rShoulder);
    final hipCenter = _midpoint(lHip, rHip);
    final shoulderWidth = _dist(lShoulder, rShoulder);

    // 1. Trunk Lean (angle with vertical)
    // Vector from hip to shoulder
    final trunkDx = shoulderCenter.x - hipCenter.x;
    final trunkDy =
        shoulderCenter.y -
        hipCenter
            .y; // Y is usually down in CV, but we care about vertical alignment
    // Vertical vector is (0, -1) [up] or (0, 1) [down].
    // Angle with Vertical axis (Y-axis).
    // atan2(dx, dy) gives angle from Y axis.
    final leanRad = atan2(
      trunkDx.abs(),
      trunkDy.abs(),
    ); // Deviation from vertical
    final leanDeg = leanRad * 180 / pi;

    // Actually, simple atan2(dx, dy) works if we assume upright.
    // If trunk is perfectly vertical, dx is 0.
    final smoothedLean = _trunkLeanSmoother.smooth(leanDeg);
    metrics['trunk_lean'] = smoothedLean;

    if (smoothedLean > _trunkLeanBad) {
      issues.add(
        const FormIssue(
          code: 'TRUNK_LEAN',
          message: 'Avoid leaning your torso',
          severity: FormStatus.bad,
        ),
      );
    } else if (smoothedLean > _trunkLeanWarning) {
      issues.add(
        const FormIssue(
          code: 'TRUNK_LEAN',
          message: 'Stand straighter',
          severity: FormStatus.warning,
        ),
      );
    }

    // 2. Lateral Shift (shoulder center relative to hip center X)
    final shift =
        (shoulderCenter.x - hipCenter.x).abs() /
        (shoulderWidth > 0 ? shoulderWidth : 1.0);
    metrics['trunk_shift'] = shift;

    if (shift > _trunkShiftBad) {
      issues.add(
        const FormIssue(
          code: 'TRUNK_SHIFT',
          message: 'Core is shifting - brace tight',
          severity: FormStatus.bad,
        ),
      );
    } else if (shift > _trunkShiftWarning) {
      issues.add(
        const FormIssue(
          code: 'TRUNK_SHIFT',
          message: 'Keep hips stable',
          severity: FormStatus.warning,
        ),
      );
    }
  }

  void _checkShrugging(
    Map<LandmarkId, Landmark> landmarks,
    List<FormIssue> issues,
    Map<String, double> metrics,
  ) {
    // Requires ears
    if (!landmarks.containsKey(LandmarkId.leftEar) ||
        !landmarks.containsKey(LandmarkId.rightEar)) {
      return;
    }

    final lEar = landmarks[LandmarkId.leftEar]!;
    final rEar = landmarks[LandmarkId.rightEar]!;

    if (!lEar.isVisible || !rEar.isVisible) return;

    final lShoulder = landmarks[LandmarkId.leftShoulder]!;
    final rShoulder = landmarks[LandmarkId.rightShoulder]!;

    final shoulderWidth = _dist(lShoulder, rShoulder);
    // Sanity check to avoid div by zero
    if (shoulderWidth < 0.05) return;

    // "Neck Length" proxy
    final lDist = _dist(lEar, lShoulder);
    final rDist = _dist(rEar, rShoulder);
    final avgNeck = (lDist + rDist) / 2.0;

    final rawNormalizedNeck = avgNeck / shoulderWidth;
    // Smooth the neck length
    final normalizedNeck = _neckLenSmoother.smooth(rawNormalizedNeck);

    metrics['neck_length_raw'] = rawNormalizedNeck;
    metrics['neck_length_smoothed'] = normalizedNeck;

    // Check if we are in active phase (raising or at top)
    final isActivePhase = _isRaisingOrAtTop(landmarks, metrics);
    metrics['shrug_active_phase'] = isActivePhase ? 1.0 : 0.0;

    // Baseline Calibration
    // Only update baseline when NOT in active phase (arms down/neutral).
    // This prevents "learning" a shrugged state as the baseline.
    if (!isActivePhase) {
      // Use a simple max as a proxy for "most relaxed" (longest neck)
      // A moving window median would be better but requires more state.
      // This is consistent with previous logic but gated.
      if (_baselineNeckLength == null ||
          normalizedNeck > _baselineNeckLength!) {
        _baselineNeckLength = normalizedNeck;
      }
    }

    metrics['neck_baseline'] = _baselineNeckLength ?? 0.0;

    // Evaluate Shrug
    // Only evaluate if we have a baseline and are in the active phase
    if (_baselineNeckLength == null) {
      // If we haven't calibrated yet (user started immediately?), we can't judge.
      // Optionally warn if this persists?
      return;
    }

    final drop = (_baselineNeckLength! - normalizedNeck) / _baselineNeckLength!;
    metrics['shrug_drop'] = drop; // allow negative if neck got longer

    // Check thresholds with gating
    bool isBad = false;
    bool isWarning = false;

    if (isActivePhase) {
      if (drop > _shrugBad) {
        // Check for sustained bad frames
        _shrugBadFrames++;
        if (_shrugBadFrames >= _shrugBadFrameThreshold) {
          isBad = true;
        } else {
          // While building up to BAD, show WARNING to give immediate feedback
          isWarning = true;
        }
      } else {
        // Decay bad frames count if not bad this frame but active
        if (_shrugBadFrames > 0) _shrugBadFrames--;

        if (drop > _shrugWarning) {
          isWarning = true;
        }
      }
    } else {
      // Reset counter when not active (e.g. going down)
      _shrugBadFrames = 0;
    }

    metrics['shrug_bad_frames'] = _shrugBadFrames.toDouble();

    if (isBad) {
      issues.add(
        const FormIssue(
          code: 'SHRUGGING',
          message: 'Don\'t shrug—shoulders down',
          severity: FormStatus.bad,
        ),
      );
    } else if (isWarning) {
      issues.add(
        const FormIssue(
          code: 'SHRUGGING',
          message: 'Relax your shoulders',
          severity: FormStatus.warning,
        ),
      );
    }
  }

  /// Determines if the user is in the "active" phase of the lateral raise
  /// (lifting or at the top), where shrugging is most critical.
  bool _isRaisingOrAtTop(
    Map<LandmarkId, Landmark> landmarks,
    Map<String, double> metrics,
  ) {
    final lWrist = landmarks[LandmarkId.leftWrist]!;
    final rWrist = landmarks[LandmarkId.rightWrist]!;
    final lHip = landmarks[LandmarkId.leftHip]!;
    final rHip = landmarks[LandmarkId.rightHip]!;

    // Midpoint calculations
    final hipCenterY = (lHip.y + rHip.y) / 2.0;
    final avgWristY = (lWrist.y + rWrist.y) / 2.0;

    // Y increases downwards. Smaller Y is higher.
    // 1. Minimum Height Check: Wrists must be clearly above hips.
    // Let's say higher than hips by 5% of screen (approx).
    // Or relative to shoulder-hip distance? Normalized coords are 0-1.
    // Using simple y difference: hipCenterY - avgWristY > 0.1
    // (Wrists are 0.1 normalized units above hips).
    final heightAboveHips = hipCenterY - avgWristY;
    metrics['wrist_height_above_hips'] = heightAboveHips;

    const activeHeightThreshold = 0.05; // Tunable

    if (heightAboveHips < activeHeightThreshold) {
      return false; // Arms too low
    }

    // 2. Elbow check (optional): Don't gate if elbows are totally collapsed?
    // Assuming existing geometry.

    return true;
  }

  // --- Geometric Helpers ---

  double _calculateAngle(Landmark a, Landmark b, Landmark c) {
    final angleRad = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    var angleDeg = angleRad * 180 / pi;
    angleDeg = angleDeg.abs();
    if (angleDeg > 180) {
      angleDeg = 360 - angleDeg;
    }
    return angleDeg;
  }

  double _dist(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  Landmark _midpoint(Landmark a, Landmark b) {
    return Landmark(
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
      z: (a.z + b.z) / 2,
      confidence: min(a.confidence, b.confidence),
    );
  }
}
