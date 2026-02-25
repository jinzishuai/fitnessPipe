/// Base class for exercise-specific form sensitivity configuration.
///
/// Each exercise that has form analysis defines a concrete subclass
/// with its adjustable thresholds. This base class provides the
/// interface for the UI to discover and render sliders.
abstract class FormSensitivityConfig {
  const FormSensitivityConfig();

  /// Returns a new instance with all values reset to factory defaults.
  FormSensitivityConfig resetToDefaults();
}

/// Sensitivity thresholds for the Lateral Raise form analyzer.
///
/// Each field maps directly to a slider in the settings dialog.
/// Lower angle values = more bend tolerated before warning/bad.
/// Higher drop values = more shrug tolerated before warning/bad.
class LateralRaiseSensitivity extends FormSensitivityConfig {
  /// Elbow angle below which a BAD issue is triggered (degrees).
  /// 180° = perfectly straight, lower = more bent.
  final double elbowBadAngle;

  /// Elbow angle below which a WARNING is triggered (degrees).
  final double elbowWarnAngle;

  /// Elbow angle above which a warning is cleared (hysteresis, degrees).
  /// Derived from [elbowWarnAngle] + 4° to maintain proper hysteresis gap.
  double get elbowWarnExitAngle => elbowWarnAngle + 4.0;

  /// Trunk lean angle at which a WARNING is triggered (degrees from vertical).
  final double trunkLeanWarnAngle;

  /// Trunk lean angle at which a BAD issue is triggered (degrees from vertical).
  final double trunkLeanBadAngle;

  /// Neck-length drop (as fraction) at which a shrug WARNING triggers.
  final double shrugWarnDrop;

  /// Neck-length drop (as fraction) at which a shrug BAD triggers.
  final double shrugBadDrop;

  const LateralRaiseSensitivity({
    required this.elbowBadAngle,
    required this.elbowWarnAngle,
    required this.trunkLeanWarnAngle,
    required this.trunkLeanBadAngle,
    required this.shrugWarnDrop,
    required this.shrugBadDrop,
  });

  /// Factory with default values matching the tuned analyzer constants.
  ///
  /// These defaults were re-tuned from the original hardcoded constants based
  /// on real-device testing to reduce false positives:
  ///   - Elbow: stricter (bad 145→140°, warn 155→151°) — original values
  ///     missed genuinely bent elbows.
  ///   - Shrug: more lenient (warn 0.10→0.115, bad 0.28→0.322) — original
  ///     values triggered too often due to natural shoulder movement.
  ///   - Trunk: unchanged (warn 8°, bad 15°).
  const factory LateralRaiseSensitivity.defaults() = LateralRaiseSensitivity._;

  const LateralRaiseSensitivity._()
    : elbowBadAngle = 140.0,
      elbowWarnAngle = 151.0,
      trunkLeanWarnAngle = 8.0,
      trunkLeanBadAngle = 15.0,
      shrugWarnDrop = 0.115,
      shrugBadDrop = 0.322;

  /// Creates a copy with the specified fields replaced.
  LateralRaiseSensitivity copyWith({
    double? elbowBadAngle,
    double? elbowWarnAngle,
    double? trunkLeanWarnAngle,
    double? trunkLeanBadAngle,
    double? shrugWarnDrop,
    double? shrugBadDrop,
  }) {
    return LateralRaiseSensitivity(
      elbowBadAngle: elbowBadAngle ?? this.elbowBadAngle,
      elbowWarnAngle: elbowWarnAngle ?? this.elbowWarnAngle,
      trunkLeanWarnAngle: trunkLeanWarnAngle ?? this.trunkLeanWarnAngle,
      trunkLeanBadAngle: trunkLeanBadAngle ?? this.trunkLeanBadAngle,
      shrugWarnDrop: shrugWarnDrop ?? this.shrugWarnDrop,
      shrugBadDrop: shrugBadDrop ?? this.shrugBadDrop,
    );
  }

  @override
  LateralRaiseSensitivity resetToDefaults() =>
      const LateralRaiseSensitivity.defaults();
}
