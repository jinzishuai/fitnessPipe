import '../models/landmark.dart';
import 'bench_press_sensitivity_config.dart';
import 'exercise_config.dart';
import 'form_sensitivity_config.dart';

/// Configuration for the Bench Press exercise.
class BenchPressConfig extends ExerciseConfig {
  const BenchPressConfig();

  @override
  Set<LandmarkId> get requiredLandmarks => const {
    LandmarkId.leftShoulder,
    LandmarkId.rightShoulder,
    LandmarkId.leftElbow,
    LandmarkId.rightElbow,
    LandmarkId.leftWrist,
    LandmarkId.rightWrist,
    LandmarkId.leftHip,
    LandmarkId.rightHip,
  };

  @override
  Set<LandmarkId> get visibleLandmarks => requiredLandmarks;

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
  (double, double) get defaultThresholds => (160.0, 100.0);

  @override
  (double, double) get topThresholdBounds => (130.0, 180.0);

  @override
  (double, double) get bottomThresholdBounds => (60.0, 130.0);

  @override
  FormSensitivityConfig get defaultFormSensitivity =>
      const BenchPressSensitivity.defaults();

  @override
  String get startPositionPrompt => 'Extend arms to start';
}
