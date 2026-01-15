import 'package:google_mlkit_commons/google_mlkit_commons.dart';
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

  /// Process an input image and return detected poses.
  ///
  /// [inputImage] - The input image to process.
  Future<List<Pose>> detectPoses(InputImage inputImage);

  /// Release resources held by the detector.
  Future<void> dispose();

  /// Whether the detector has been initialized.
  bool get isInitialized;
}
