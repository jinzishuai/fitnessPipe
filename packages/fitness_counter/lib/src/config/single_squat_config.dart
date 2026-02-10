import '../models/landmark.dart';
import 'exercise_config.dart';

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

  // visibleLandmarks defaults to requiredLandmarks (no additional needed)

  @override
  List<(LandmarkId, LandmarkId)> get visibleBones => const [
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
  bool get hasThresholds => false;

  @override
  (double, double) get defaultThresholds => (170.0, 160.0);
}
