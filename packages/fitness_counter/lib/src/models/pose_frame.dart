import 'landmark.dart';

/// A frame of pose data containing detected landmarks.
///
/// This is the input format expected by all exercise counters.
/// The main app is responsible for converting from its pose provider
/// (ML Kit, Apple Vision, etc.) to this format.
class PoseFrame {
  /// Map of landmark IDs to their detected positions.
  final Map<LandmarkId, Landmark> landmarks;

  /// Timestamp when this pose was detected.
  final DateTime timestamp;

  const PoseFrame({
    required this.landmarks,
    required this.timestamp,
  });

  /// Get a specific landmark by ID.
  ///
  /// Returns null if the landmark is not present in this frame.
  Landmark? operator [](LandmarkId id) => landmarks[id];

  /// Check if all required landmarks are present and visible.
  ///
  /// This is used by exercise counters to validate they have
  /// the minimum data needed to process the frame.
  bool hasLandmarks(Set<LandmarkId> required) {
    return required.every((id) => landmarks[id]?.isVisible ?? false);
  }

  /// Get a landmark, throwing if not present or not visible.
  ///
  /// Use this when you've already validated with [hasLandmarks].
  Landmark getLandmark(LandmarkId id) {
    final landmark = landmarks[id];
    if (landmark == null || !landmark.isVisible) {
      throw StateError('Landmark $id not available in this frame');
    }
    return landmark;
  }

  @override
  String toString() =>
      'PoseFrame(landmarks: ${landmarks.length}, timestamp: $timestamp)';
}
