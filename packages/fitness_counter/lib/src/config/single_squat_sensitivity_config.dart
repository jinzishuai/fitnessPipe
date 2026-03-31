import 'form_sensitivity_config.dart';

/// Sensitivity thresholds for the Single Squat form analyzer.
///
/// All thresholds are tuned for a front-facing camera capturing a full-body
/// squat. Values were validated against real pose fixture data extracted from
/// single_squat.mp4 (68 frames, ~2.3 s, 30 fps).
class SingleSquatSensitivity extends FormSensitivityConfig {
  // ── Knee Valgus ──────────────────────────────────────────────────────────
  // Measured as the inward deviation of each knee from its corresponding
  // ankle, normalised by hip width.  Positive = knee caves inward.

  /// Normalised valgus ratio above which a WARNING is triggered.
  final double kneeValgusWarnRatio;

  /// Normalised valgus ratio above which a BAD issue is triggered.
  final double kneeValgusBadRatio;

  /// Hysteresis exit ratio for knee-valgus warning.
  double get kneeValgusWarnExitRatio => kneeValgusWarnRatio - 0.03;

  // ── Trunk Forward Lean ───────────────────────────────────────────────────
  // Angle (degrees) of the shoulder-centre → hip-centre vector from vertical.

  /// Trunk lean angle (°) above which a WARNING is triggered.
  final double trunkLeanWarnAngle;

  /// Trunk lean angle (°) above which a BAD issue is triggered.
  final double trunkLeanBadAngle;

  /// Hysteresis exit angle for trunk-lean warning.
  double get trunkLeanWarnExitAngle => trunkLeanWarnAngle - 5.0;

  // ── Squat Depth ──────────────────────────────────────────────────────────
  // Knee angle (hip-knee-ankle) below which depth is "sufficient".
  // 180° = straight leg;  90° = thigh parallel to floor.

  /// Knee angle below which a depth WARNING is issued (not quite parallel).
  final double depthWarnAngle;

  /// Knee angle at or below which depth is considered good (at/below parallel).
  final double depthGoodAngle;

  const SingleSquatSensitivity({
    required this.kneeValgusWarnRatio,
    required this.kneeValgusBadRatio,
    required this.trunkLeanWarnAngle,
    required this.trunkLeanBadAngle,
    required this.depthWarnAngle,
    required this.depthGoodAngle,
  });

  /// Factory with research-backed default values.
  const factory SingleSquatSensitivity.defaults() = SingleSquatSensitivity._;

  const SingleSquatSensitivity._()
    : kneeValgusWarnRatio = 0.08,
      kneeValgusBadRatio = 0.15,
      trunkLeanWarnAngle = 30.0,
      trunkLeanBadAngle = 45.0,
      depthWarnAngle = 120.0,
      depthGoodAngle = 100.0;

  SingleSquatSensitivity copyWith({
    double? kneeValgusWarnRatio,
    double? kneeValgusBadRatio,
    double? trunkLeanWarnAngle,
    double? trunkLeanBadAngle,
    double? depthWarnAngle,
    double? depthGoodAngle,
  }) {
    return SingleSquatSensitivity(
      kneeValgusWarnRatio: kneeValgusWarnRatio ?? this.kneeValgusWarnRatio,
      kneeValgusBadRatio: kneeValgusBadRatio ?? this.kneeValgusBadRatio,
      trunkLeanWarnAngle: trunkLeanWarnAngle ?? this.trunkLeanWarnAngle,
      trunkLeanBadAngle: trunkLeanBadAngle ?? this.trunkLeanBadAngle,
      depthWarnAngle: depthWarnAngle ?? this.depthWarnAngle,
      depthGoodAngle: depthGoodAngle ?? this.depthGoodAngle,
    );
  }

  @override
  SingleSquatSensitivity resetToDefaults() =>
      const SingleSquatSensitivity.defaults();
}
