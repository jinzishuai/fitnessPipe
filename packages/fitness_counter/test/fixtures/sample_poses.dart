import 'package:fitness_counter/fitness_counter.dart';

/// Helper functions to create test PoseFrame objects.

/// Create a pose frame with specified landmark positions.
///
/// Positions are given as (x, y) offsets where 0.0-1.0 is normalized.
PoseFrame createPoseFrame(
  Map<LandmarkId, (double x, double y)> positions, {
  DateTime? timestamp,
  double confidence = 1.0,
}) {
  final landmarks = <LandmarkId, Landmark>{};

  for (final entry in positions.entries) {
    landmarks[entry.key] = Landmark(
      x: entry.value.$1,
      y: entry.value.$2,
      confidence: confidence,
    );
  }

  return PoseFrame(
    landmarks: landmarks,
    timestamp: timestamp ?? DateTime.now(),
  );
}

/// Create a pose with arms down (lateral raise starting position).
///
/// Arms approximately 15° from vertical (very close to body).
PoseFrame createArmsDownPose({DateTime? timestamp}) {
  return createPoseFrame({
    // Left side
    LandmarkId.leftShoulder: (0.3, 0.3),
    LandmarkId.leftElbow: (0.32, 0.5), // Slightly out, mostly down
    LandmarkId.leftHip: (0.35, 0.7),

    // Right side (mirror)
    LandmarkId.rightShoulder: (0.7, 0.3),
    LandmarkId.rightElbow: (0.68, 0.5),
    LandmarkId.rightHip: (0.65, 0.7),
  }, timestamp: timestamp);
}

/// Create a pose with arms halfway raised (~45°).
PoseFrame createArmsMidRaisePose({DateTime? timestamp}) {
  return createPoseFrame({
    // Left side
    LandmarkId.leftShoulder: (0.3, 0.3),
    LandmarkId.leftElbow: (0.15, 0.35), // Out at 45 degrees
    LandmarkId.leftHip: (0.35, 0.7),

    // Right side (mirror)
    LandmarkId.rightShoulder: (0.7, 0.3),
    LandmarkId.rightElbow: (0.85, 0.35),
    LandmarkId.rightHip: (0.65, 0.7),
  }, timestamp: timestamp);
}

/// Create a pose with arms fully raised (~85°).
PoseFrame createArmsUpPose({DateTime? timestamp}) {
  return createPoseFrame({
    // Left side
    LandmarkId.leftShoulder: (0.3, 0.3),
    LandmarkId.leftElbow: (0.05, 0.29), // Nearly horizontal
    LandmarkId.leftHip: (0.35, 0.7),

    // Right side (mirror)
    LandmarkId.rightShoulder: (0.7, 0.3),
    LandmarkId.rightElbow: (0.95, 0.29),
    LandmarkId.rightHip: (0.65, 0.7),
  }, timestamp: timestamp);
}

/// Create a pose with incomplete landmarks (missing shoulder).
PoseFrame createIncompletePose({DateTime? timestamp}) {
  return createPoseFrame({
    // Missing leftShoulder
    LandmarkId.leftElbow: (0.32, 0.5),
    LandmarkId.leftHip: (0.35, 0.7),
    LandmarkId.rightShoulder: (0.7, 0.3),
    LandmarkId.rightElbow: (0.68, 0.5),
    LandmarkId.rightHip: (0.65, 0.7),
  }, timestamp: timestamp);
}
