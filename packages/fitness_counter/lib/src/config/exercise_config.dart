import '../models/landmark.dart';
import 'form_sensitivity_config.dart';

/// Abstract configuration for an exercise type.
///
/// Each exercise implements this to define:
/// - Which landmarks are required/visible
/// - Which bone connections to draw
/// - Threshold configuration
abstract class ExerciseConfig {
  const ExerciseConfig();

  /// Landmarks required for rep counting and form analysis.
  Set<LandmarkId> get requiredLandmarks;

  /// All landmarks to display when this exercise is selected.
  /// By default equals requiredLandmarks, but may include additional
  /// landmarks needed for form analysis (e.g., ears for shrug detection).
  Set<LandmarkId> get visibleLandmarks => requiredLandmarks;

  /// Bone connections to draw (subset of full skeleton).
  /// Each tuple represents (startLandmark, endLandmark).
  List<(LandmarkId, LandmarkId)> get visibleBones;

  /// Whether this exercise has configurable thresholds.
  bool get hasThresholds;

  /// Default threshold values as (topThreshold, bottomThreshold).
  (double, double) get defaultThresholds;

  /// Slider bounds for top threshold configuration as (min, max).
  (double, double) get topThresholdBounds => (30.0, 90.0);

  /// Slider bounds for bottom threshold configuration as (min, max).
  (double, double) get bottomThresholdBounds => (10.0, 40.0);

  /// Minimum cooldown between repeated feedback for the same issue code.
  ///
  /// Different exercises may have different-length feedback messages,
  /// so this is configurable per exercise. The global minimum cooldown
  /// between any feedback is controlled separately by [FeedbackCooldownManager].
  Duration get feedbackCooldown => const Duration(seconds: 3);

  /// Default form sensitivity config, or null if this exercise has no
  /// form analysis. Override in subclasses that support form checks.
  FormSensitivityConfig? get defaultFormSensitivity => null;

  /// Short instruction shown (and spoken via TTS) when the user has not yet
  /// reached the exercise's starting position.
  ///
  /// Examples: `'Lower arms to start'`, `'Stand straight to begin'`.
  String get startPositionPrompt;
}
