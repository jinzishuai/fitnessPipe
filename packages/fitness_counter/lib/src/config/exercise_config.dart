import '../models/landmark.dart';

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
}
