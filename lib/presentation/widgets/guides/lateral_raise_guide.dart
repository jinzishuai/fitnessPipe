import 'dart:math';
import 'dart:ui';

import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart' show Colors;

import '../../../domain/models/pose.dart';
import '../../../domain/models/pose_landmark.dart';
import 'exercise_guide.dart';

/// Visual guide for lateral raise exercise.
///
/// Draws dashed projection lines from shoulders showing target arm positions:
/// - During down/rising phase: horizontal lines at topThreshold (target "up")
/// - During up/falling phase: downward lines at bottomThreshold (target "down")
class LateralRaiseGuide extends ExerciseGuide {
  final double topThreshold;
  final double bottomThreshold;
  final LateralRaisePhase currentPhase;
  final Color guideColor;

  const LateralRaiseGuide({
    required this.topThreshold,
    required this.bottomThreshold,
    required this.currentPhase,
    this.guideColor = Colors.cyanAccent,
  });

  @override
  void paint(
    Canvas canvas,
    Size canvasSize,
    Pose pose, {
    Size? imageSize,
    int rotationDegrees = 0,
    bool inputsAreRotated = false,
  }) {
    final leftShoulder = pose.getLandmark(LandmarkType.leftShoulder);
    final rightShoulder = pose.getLandmark(LandmarkType.rightShoulder);

    if (leftShoulder == null ||
        rightShoulder == null ||
        !leftShoulder.isVisible ||
        !rightShoulder.isVisible) {
      return;
    }

    // Calculate arm length based on shoulder width
    final leftShoulderPoint = _scalePoint(
      leftShoulder,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );
    final rightShoulderPoint = _scalePoint(
      rightShoulder,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );

    final shoulderWidth =
        (leftShoulderPoint - rightShoulderPoint).distance;
    final armLength = shoulderWidth * 1.5; // Approximate arm length

    // Convert threshold angles to radians
    final topAngleRadians = topThreshold * (pi / 180);
    final bottomAngleRadians = bottomThreshold * (pi / 180);

    // Calculate endpoints for "up" guide lines (green)
    final leftUpEndPoint = Offset(
      leftShoulderPoint.dx + armLength * sin(topAngleRadians),
      leftShoulderPoint.dy + armLength * cos(topAngleRadians),
    );
    final rightUpEndPoint = Offset(
      rightShoulderPoint.dx - armLength * sin(topAngleRadians),
      rightShoulderPoint.dy + armLength * cos(topAngleRadians),
    );

    // Calculate endpoints for "down" guide lines (blue)
    final leftDownEndPoint = Offset(
      leftShoulderPoint.dx + armLength * sin(bottomAngleRadians),
      leftShoulderPoint.dy + armLength * cos(bottomAngleRadians),
    );
    final rightDownEndPoint = Offset(
      rightShoulderPoint.dx - armLength * sin(bottomAngleRadians),
      rightShoulderPoint.dy + armLength * cos(bottomAngleRadians),
    );

    // Draw guides based on phase:
    // - waiting: only show "down" lines (blue) to guide user to starting position
    // - all other phases: show both lines so user sees full range
    if (currentPhase == LateralRaisePhase.waiting) {
      _drawDashedLine(canvas, leftShoulderPoint, leftDownEndPoint, Colors.blue);
      _drawDashedLine(canvas, rightShoulderPoint, rightDownEndPoint, Colors.blue);
    } else {
      // Show both lines: green for "up" target, blue for "down" target
      _drawDashedLine(canvas, leftShoulderPoint, leftUpEndPoint, Colors.green);
      _drawDashedLine(canvas, rightShoulderPoint, rightUpEndPoint, Colors.green);
      _drawDashedLine(canvas, leftShoulderPoint, leftDownEndPoint, Colors.blue);
      _drawDashedLine(canvas, rightShoulderPoint, rightDownEndPoint, Colors.blue);
    }
  }

  /// Draw a dashed line from start to end.
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color.withAlpha(180)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    const dashLength = 10.0;
    const gapLength = 8.0;

    final direction = (end - start);
    final totalLength = direction.distance;
    final unitVector = direction / totalLength;

    double currentLength = 0;
    bool isDrawing = true;

    while (currentLength < totalLength) {
      final segmentLength =
          isDrawing ? dashLength : gapLength;
      final nextLength = (currentLength + segmentLength).clamp(0.0, totalLength);

      if (isDrawing) {
        final startPoint = start + unitVector * currentLength;
        final endPoint = start + unitVector * nextLength;
        canvas.drawLine(startPoint, endPoint, paint);
      }

      currentLength = nextLength.toDouble();
      isDrawing = !isDrawing;
    }
  }

  /// Scale a landmark's coordinates to canvas coordinates.
  /// Mirrors the logic from SkeletonPainter for consistency.
  Offset _scalePoint(
    PoseLandmark landmark,
    Size canvasSize,
    Size? imageSize,
    int rotationDegrees,
    bool inputsAreRotated,
  ) {
    if (imageSize == null) {
      // Fallback: direct scaling
      return Offset(
        landmark.x * canvasSize.width,
        landmark.y * canvasSize.height,
      );
    }

    // When rotated 90 or 270 degrees, the image dimensions are effectively swapped
    final effectiveImageSize = (rotationDegrees == 90 || rotationDegrees == 270)
        ? Size(imageSize.height, imageSize.width)
        : imageSize;

    // Calculate the scale factor and offset for aspect-fit
    final imageAspect = effectiveImageSize.width / effectiveImageSize.height;
    final canvasAspect = canvasSize.width / canvasSize.height;

    double scale;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspect > canvasAspect) {
      scale = canvasSize.width / effectiveImageSize.width;
      offsetY = (canvasSize.height - effectiveImageSize.height * scale) / 2;
    } else {
      scale = canvasSize.height / effectiveImageSize.height;
      offsetX = (canvasSize.width - effectiveImageSize.width * scale) / 2;
    }

    double x, y;

    if (!inputsAreRotated &&
        (rotationDegrees == 90 || rotationDegrees == 270)) {
      final isNormalized = landmark.x <= 2.0 && landmark.y <= 2.0;

      if (isNormalized) {
        x = landmark.y * effectiveImageSize.width * scale + offsetX;
        y = landmark.x * effectiveImageSize.height * scale + offsetY;
      } else {
        x = landmark.y * scale + offsetX;
        y = landmark.x * scale + offsetY;
      }
    } else {
      final isNormalized = landmark.x <= 2.0 && landmark.y <= 2.0;

      if (isNormalized) {
        x = landmark.x * effectiveImageSize.width * scale + offsetX;
        y = landmark.y * effectiveImageSize.height * scale + offsetY;
      } else {
        x = landmark.x * scale + offsetX;
        y = landmark.y * scale + offsetY;
      }
    }

    return Offset(x, y);
  }
}
