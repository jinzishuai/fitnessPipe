import 'dart:ui';

import 'package:camera/camera.dart';
import '../models/pose.dart';

/// Configuration for pose detector.
class PoseDetectorConfig {
  /// Detection mode - single image or streaming video.
  final PoseDetectionMode mode;

  /// Minimum confidence threshold for pose detection.
  final double minConfidence;

  const PoseDetectorConfig({
    this.mode = PoseDetectionMode.stream,
    this.minConfidence = 0.5,
  });
}

/// Detection mode for pose detection.
enum PoseDetectionMode {
  /// Single image mode - optimized for static images.
  singleImage,

  /// Stream mode - optimized for video/camera streams.
  stream,
}

/// Abstract interface for pose detection implementations.
///
/// This abstraction allows swapping between ML Kit and future
/// native FFI implementations without changing the rest of the app.
abstract class PoseDetector {
  /// Initialize the detector with configuration.
  Future<void> initialize(PoseDetectorConfig config);

  /// Process a camera frame and return detected poses.
  ///
  /// [image] - The camera frame to process.
  /// [imageSize] - The size of the image for coordinate normalization.
  /// [rotation] - The rotation of the image for proper orientation.
  Future<List<Pose>> detectPoses(
    CameraImage image,
    Size imageSize,
    InputImageRotation rotation,
  );

  /// Release resources held by the detector.
  Future<void> dispose();

  /// Whether the detector has been initialized.
  bool get isInitialized;
}

/// Input image rotation values.
enum InputImageRotation {
  rotation0deg,
  rotation90deg,
  rotation180deg,
  rotation270deg,
}
