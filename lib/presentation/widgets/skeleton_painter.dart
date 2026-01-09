import 'package:flutter/material.dart';

import '../../domain/models/pose.dart';
import '../../domain/models/pose_landmark.dart';

/// CustomPainter that draws a skeleton overlay on detected pose landmarks.
class SkeletonPainter extends CustomPainter {
  final Pose? pose;
  final int rotationDegrees;
  final Size? imageSize;

  /// Color for the skeleton lines and points.
  final Color skeletonColor;

  /// Size of the landmark points.
  final double pointRadius;

  /// Stroke width for the skeleton lines.
  final double strokeWidth;

  SkeletonPainter({
    required this.pose,
    this.rotationDegrees = 0,
    this.imageSize,
    this.skeletonColor = Colors.green,
    this.pointRadius = 6.0,
    this.strokeWidth = 3.0,
  });

  /// Bone connections defining the skeleton structure.
  static const List<(LandmarkType, LandmarkType)> boneConnections = [
    // Face
    (LandmarkType.leftEar, LandmarkType.leftEye),
    (LandmarkType.leftEye, LandmarkType.nose),
    (LandmarkType.nose, LandmarkType.rightEye),
    (LandmarkType.rightEye, LandmarkType.rightEar),

    // Torso
    (LandmarkType.leftShoulder, LandmarkType.rightShoulder),
    (LandmarkType.leftShoulder, LandmarkType.leftHip),
    (LandmarkType.rightShoulder, LandmarkType.rightHip),
    (LandmarkType.leftHip, LandmarkType.rightHip),

    // Left arm
    (LandmarkType.leftShoulder, LandmarkType.leftElbow),
    (LandmarkType.leftElbow, LandmarkType.leftWrist),
    (LandmarkType.leftWrist, LandmarkType.leftThumb),
    (LandmarkType.leftWrist, LandmarkType.leftIndex),
    (LandmarkType.leftWrist, LandmarkType.leftPinky),

    // Right arm
    (LandmarkType.rightShoulder, LandmarkType.rightElbow),
    (LandmarkType.rightElbow, LandmarkType.rightWrist),
    (LandmarkType.rightWrist, LandmarkType.rightThumb),
    (LandmarkType.rightWrist, LandmarkType.rightIndex),
    (LandmarkType.rightWrist, LandmarkType.rightPinky),

    // Left leg
    (LandmarkType.leftHip, LandmarkType.leftKnee),
    (LandmarkType.leftKnee, LandmarkType.leftAnkle),
    (LandmarkType.leftAnkle, LandmarkType.leftHeel),
    (LandmarkType.leftAnkle, LandmarkType.leftFootIndex),

    // Right leg
    (LandmarkType.rightHip, LandmarkType.rightKnee),
    (LandmarkType.rightKnee, LandmarkType.rightAnkle),
    (LandmarkType.rightAnkle, LandmarkType.rightHeel),
    (LandmarkType.rightAnkle, LandmarkType.rightFootIndex),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null || !pose!.isValid) return;

    final paint = Paint()
      ..color = skeletonColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = skeletonColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw bone connections
    for (final connection in boneConnections) {
      final start = pose!.getLandmark(connection.$1);
      final end = pose!.getLandmark(connection.$2);

      if (start != null && end != null && start.isVisible && end.isVisible) {
        final startPoint = _scalePoint(start, size);
        final endPoint = _scalePoint(end, size);

        canvas.drawLine(startPoint, endPoint, linePaint);
      }
    }

    // Draw landmark points
    for (final landmark in pose!.landmarks) {
      if (landmark.isVisible) {
        final point = _scalePoint(landmark, size);

        // Draw outer circle
        canvas.drawCircle(point, pointRadius, paint);

        // Draw inner circle for better visibility
        canvas.drawCircle(
          point,
          pointRadius * 0.5,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  /// Scale a landmark's normalized coordinates to canvas coordinates.
  /// ML Kit already handles rotation internally when we pass InputImageRotation,
  /// so the coordinates are already in the display's coordinate space.
  /// However, we need to account for aspect-fit scaling when the camera image
  /// is letterboxed to fit the canvas.
  Offset _scalePoint(PoseLandmark landmark, Size canvasSize) {
    if (imageSize == null) {
      // Fallback: direct scaling
      return Offset(
        landmark.x * canvasSize.width,
        landmark.y * canvasSize.height,
      );
    }

    // When rotated 90 or 270 degrees, the image dimensions are effectively swapped
    final effectiveImageSize = (rotationDegrees == 90 || rotationDegrees == 270)
        ? Size(imageSize!.height, imageSize!.width)
        : imageSize!;

    // Calculate the scale factor and offset for aspect-fit
    final imageAspect = effectiveImageSize.width / effectiveImageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;

    double scale;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspect > canvasAspect) {
      // Image is wider - fit to width, letterbox top/bottom
      scale = canvasSize.width / effectiveImageSize.width;
      offsetY = (canvasSize.height - effectiveImageSize.height * scale) / 2;
    } else {
      // Image is taller - fit to height, letterbox left/right
      scale = canvasSize.height / effectiveImageSize.height;
      offsetX = (canvasSize.width - effectiveImageSize.width * scale) / 2;
    }

    // Scale from normalized [0,1] to image size, then to canvas size
    final x = landmark.x * effectiveImageSize.width * scale + offsetX;
    final y = landmark.y * effectiveImageSize.height * scale + offsetY;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(SkeletonPainter oldDelegate) {
    return pose != oldDelegate.pose ||
        rotationDegrees != oldDelegate.rotationDegrees ||
        imageSize != oldDelegate.imageSize;
  }
}
