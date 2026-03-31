import '../models/landmark.dart';
import 'exercise_config.dart';
import 'form_sensitivity_config.dart';
import 'single_squat_sensitivity_config.dart';

/// Configuration for the Single Squat exercise.
class SingleSquatConfig extends ExerciseConfig {
  const SingleSquatConfig();

  @override
  Set<LandmarkId> get requiredLandmarks => const {
    LandmarkId.leftHip,
    LandmarkId.rightHip,
    LandmarkId.leftKnee,
    LandmarkId.rightKnee,
    LandmarkId.leftAnkle,
    LandmarkId.rightAnkle,
  };

  @override
  Set<LandmarkId> get visibleLandmarks => const {
    // Shoulders needed for trunk-lean form analysis overlay
    LandmarkId.leftShoulder,
    LandmarkId.rightShoulder,
    // Core leg landmarks
    LandmarkId.leftHip,
    LandmarkId.rightHip,
    LandmarkId.leftKnee,
    LandmarkId.rightKnee,
    LandmarkId.leftAnkle,
    LandmarkId.rightAnkle,
  };

  @override
  List<(LandmarkId, LandmarkId)> get visibleBones => const [
    // Trunk (for form feedback visualisation)
    (LandmarkId.leftShoulder, LandmarkId.rightShoulder),
    (LandmarkId.leftShoulder, LandmarkId.leftHip),
    (LandmarkId.rightShoulder, LandmarkId.rightHip),
    // Hip connection
    (LandmarkId.leftHip, LandmarkId.rightHip),
    // Left leg
    (LandmarkId.leftHip, LandmarkId.leftKnee),
    (LandmarkId.leftKnee, LandmarkId.leftAnkle),
    // Right leg
    (LandmarkId.rightHip, LandmarkId.rightKnee),
    (LandmarkId.rightKnee, LandmarkId.rightAnkle),
  ];

  @override
  bool get hasThresholds => true;

  @override
  (double, double) get defaultThresholds => (170.0, 160.0);

  @override
  (double, double) get topThresholdBounds => (160.0, 180.0);

  @override
  (double, double) get bottomThresholdBounds => (140.0, 170.0);

  @override
  FormSensitivityConfig get defaultFormSensitivity =>
      const SingleSquatSensitivity.defaults();

  @override
  String get startPositionPrompt => 'Stand straight to begin';
}
