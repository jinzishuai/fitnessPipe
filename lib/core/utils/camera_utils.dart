import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Utilities for camera image processing.
class CameraUtils {
  /// Convert CameraImage to ML Kit InputImage.
  static InputImage? convertCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    // Get the image format based on platform
    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    // For Android, use nv21 format from the first plane
    // For iOS, use bgra8888 format
    final bytes = image.planes.first.bytes;

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}
