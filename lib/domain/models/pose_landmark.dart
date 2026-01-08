/// Pose landmark types matching MediaPipe Pose model's 33 landmarks.
enum LandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  mouthLeft,
  mouthRight,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// A single landmark in a detected pose with normalized coordinates.
class PoseLandmark {
  /// The type of this landmark.
  final LandmarkType type;

  /// X coordinate normalized to 0.0 - 1.0 range.
  final double x;

  /// Y coordinate normalized to 0.0 - 1.0 range.
  final double y;

  /// Z coordinate (depth) relative to hip center.
  final double z;

  /// Confidence score for this landmark detection (0.0 - 1.0).
  final double confidence;

  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.confidence,
  });

  /// Whether this landmark has sufficient confidence to be considered valid.
  bool get isVisible => confidence > 0.5;
}
