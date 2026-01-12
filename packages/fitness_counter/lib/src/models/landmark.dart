import 'dart:math';

/// Standard landmark identifiers matching MediaPipe Pose model's 33 landmarks.
///
/// Each exercise counter declares which subset of these it requires.
enum LandmarkId {
  // Face
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

  // Upper body
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,

  // Hands
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,

  // Core
  leftHip,
  rightHip,

  // Lower body
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// A single landmark point in normalized 3D space.
///
/// Coordinates are normalized to 0.0-1.0 range for x and y.
/// Z represents relative depth.
class Landmark {
  /// X coordinate (0.0 - 1.0 normalized).
  final double x;

  /// Y coordinate (0.0 - 1.0 normalized).
  final double y;

  /// Z coordinate (relative depth).
  final double z;

  /// Confidence score for this landmark detection (0.0 - 1.0).
  final double confidence;

  const Landmark({
    required this.x,
    required this.y,
    this.z = 0.0,
    required this.confidence,
  });

  /// Whether this landmark has sufficient confidence to be considered valid.
  bool get isVisible => confidence > 0.5;

  /// Calculate Euclidean distance to another landmark in 2D space.
  double distanceTo(Landmark other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() =>
      'Landmark(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, '
      'confidence: ${confidence.toStringAsFixed(2)})';
}
