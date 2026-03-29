import 'form_sensitivity_config.dart';

/// Sensitivity thresholds for the Bench Press form analyzer.
class BenchPressSensitivity extends FormSensitivityConfig {
  /// Elbow flare angle (torso to humerus) above which a WARNING is triggered.
  final double flareWarnAngle;

  /// Elbow flare angle above which a BAD issue is triggered.
  final double flareBadAngle;

  /// Hysteresis exit angle for elbow flare warning.
  double get flareWarnExitAngle => flareWarnAngle - 5.0;

  /// Difference between left and right elbow extension angles for WARNING.
  final double unevenWarnAngle;

  /// Difference between left and right elbow extension angles for BAD.
  final double unevenBadAngle;

  /// Hysteresis exit angle for uneven extension warning.
  double get unevenWarnExitAngle => unevenWarnAngle - 5.0;

  /// Normalized hip-to-shoulder vertical distance drop fraction for WARNING.
  final double hipRiseWarnDrop;

  /// Normalized hip-to-shoulder vertical distance drop fraction for BAD.
  final double hipRiseBadDrop;

  const BenchPressSensitivity({
    required this.flareWarnAngle,
    required this.flareBadAngle,
    required this.unevenWarnAngle,
    required this.unevenBadAngle,
    required this.hipRiseWarnDrop,
    required this.hipRiseBadDrop,
  });

  /// Factory with default values based on common biomechanical safe zones.
  const factory BenchPressSensitivity.defaults() = BenchPressSensitivity._;

  const BenchPressSensitivity._()
    : flareWarnAngle = 75.0,
      flareBadAngle = 85.0,
      unevenWarnAngle = 15.0,
      unevenBadAngle = 25.0,
      hipRiseWarnDrop = 0.05,
      hipRiseBadDrop = 0.10;

  BenchPressSensitivity copyWith({
    double? flareWarnAngle,
    double? flareBadAngle,
    double? unevenWarnAngle,
    double? unevenBadAngle,
    double? hipRiseWarnDrop,
    double? hipRiseBadDrop,
  }) {
    return BenchPressSensitivity(
      flareWarnAngle: flareWarnAngle ?? this.flareWarnAngle,
      flareBadAngle: flareBadAngle ?? this.flareBadAngle,
      unevenWarnAngle: unevenWarnAngle ?? this.unevenWarnAngle,
      unevenBadAngle: unevenBadAngle ?? this.unevenBadAngle,
      hipRiseWarnDrop: hipRiseWarnDrop ?? this.hipRiseWarnDrop,
      hipRiseBadDrop: hipRiseBadDrop ?? this.hipRiseBadDrop,
    );
  }

  @override
  BenchPressSensitivity resetToDefaults() =>
      const BenchPressSensitivity.defaults();
}
