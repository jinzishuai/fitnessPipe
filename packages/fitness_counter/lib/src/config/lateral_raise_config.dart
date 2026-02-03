import '../models/landmark.dart';
import 'exercise_config.dart';

/// Configuration for the Lateral Raise exercise.
class LateralRaiseConfig extends ExerciseConfig {
  const LateralRaiseConfig();

  @override
  Set<LandmarkId> get requiredLandmarks => const {
        LandmarkId.leftShoulder,
        LandmarkId.rightShoulder,
        LandmarkId.leftElbow,
        LandmarkId.rightElbow,
        LandmarkId.leftHip,
        LandmarkId.rightHip,
      };

  @override
  Set<LandmarkId> get visibleLandmarks => const {
        // Required landmarks from counter
        LandmarkId.leftShoulder,
        LandmarkId.rightShoulder,
        LandmarkId.leftElbow,
        LandmarkId.rightElbow,
        LandmarkId.leftHip,
        LandmarkId.rightHip,
        // Additional landmarks for form analyzer (shrug detection)
        LandmarkId.leftEar,
        LandmarkId.rightEar,
        // Wrists for visual completion of arms
        LandmarkId.leftWrist,
        LandmarkId.rightWrist,
      };

  @override
  List<(LandmarkId, LandmarkId)> get visibleBones => const [
        // Torso
        (LandmarkId.leftShoulder, LandmarkId.rightShoulder),
        (LandmarkId.leftShoulder, LandmarkId.leftHip),
        (LandmarkId.rightShoulder, LandmarkId.rightHip),
        (LandmarkId.leftHip, LandmarkId.rightHip),
        // Left arm
        (LandmarkId.leftShoulder, LandmarkId.leftElbow),
        (LandmarkId.leftElbow, LandmarkId.leftWrist),
        // Right arm
        (LandmarkId.rightShoulder, LandmarkId.rightElbow),
        (LandmarkId.rightElbow, LandmarkId.rightWrist),
      ];

  @override
  bool get hasThresholds => true;

  @override
  (double, double) get defaultThresholds => (50.0, 25.0);
}
