import 'pose_landmark.dart';

/// Represents a detected human pose with all landmarks.
class Pose {
  /// All 33 landmarks detected in this pose.
  final List<PoseLandmark> landmarks;

  /// Overall confidence score for this pose detection.
  final double confidence;

  /// Timestamp when this pose was detected.
  final DateTime timestamp;

  const Pose({
    required this.landmarks,
    required this.confidence,
    required this.timestamp,
  });

  /// Get a specific landmark by type.
  PoseLandmark? getLandmark(LandmarkType type) {
    try {
      return landmarks.firstWhere((l) => l.type == type);
    } catch (_) {
      return null;
    }
  }

  /// Whether this pose has sufficient landmarks for processing.
  bool get isValid => landmarks.where((l) => l.isVisible).length >= 10;
}
