import 'dart:ui';

import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart' show Colors;

import '../../../domain/models/pose.dart';
import '../../../domain/models/pose_landmark.dart';
import 'exercise_guide.dart';

/// Visual guide for single squat exercise.
///
/// Draws vertical dashed alignment lines from each knee to the corresponding
/// ankle, coloured by the current movement phase.  When the user is at the
/// bottom of the squat the lines turn green to indicate the target was reached.
class SingleSquatGuide extends ExerciseGuide {
  final SingleSquatPhase currentPhase;

  const SingleSquatGuide({required this.currentPhase});

  @override
  void paint(
    Canvas canvas,
    Size canvasSize,
    Pose pose, {
    Size? imageSize,
    int rotationDegrees = 0,
    bool inputsAreRotated = false,
  }) {
    final leftKnee = pose.getLandmark(LandmarkType.leftKnee);
    final rightKnee = pose.getLandmark(LandmarkType.rightKnee);
    final leftAnkle = pose.getLandmark(LandmarkType.leftAnkle);
    final rightAnkle = pose.getLandmark(LandmarkType.rightAnkle);

    if (leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        !leftKnee.isVisible ||
        !rightKnee.isVisible ||
        !leftAnkle.isVisible ||
        !rightAnkle.isVisible) {
      return;
    }

    // Knee-ankle alignment lines
    final leftKneePoint = _scalePoint(
      leftKnee,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );
    final rightKneePoint = _scalePoint(
      rightKnee,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );
    final leftAnklePoint = _scalePoint(
      leftAnkle,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );
    final rightAnklePoint = _scalePoint(
      rightAnkle,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );

    Color phaseColor;
    switch (currentPhase) {
      case SingleSquatPhase.waiting:
        phaseColor = Colors.white54;
        break;
      case SingleSquatPhase.standing:
        phaseColor = Colors.cyanAccent;
        break;
      case SingleSquatPhase.descending:
        phaseColor = Colors.orangeAccent;
        break;
      case SingleSquatPhase.bottom:
        phaseColor = Colors.greenAccent;
        break;
      case SingleSquatPhase.ascending:
        phaseColor = Colors.purpleAccent;
        break;
    }

    // Draw vertical alignment lines from knee to ankle
    // These help the user keep knees tracking over toes.
    _drawDashedLine(
      canvas,
      Offset(leftAnklePoint.dx, leftKneePoint.dy),
      leftAnklePoint,
      phaseColor,
    );
    _drawDashedLine(
      canvas,
      Offset(rightAnklePoint.dx, rightKneePoint.dy),
      rightAnklePoint,
      phaseColor,
    );

    // Draw small circles at ankle positions (target markers)
    final markerPaint = Paint()
      ..color = phaseColor.withAlpha(180)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(leftAnklePoint, 6.0, markerPaint);
    canvas.drawCircle(rightAnklePoint, 6.0, markerPaint);
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
    if (totalLength < 1.0) return;
    final unitVector = direction / totalLength;

    double currentLength = 0;
    bool isDrawing = true;

    while (currentLength < totalLength) {
      final segmentLength = isDrawing ? dashLength : gapLength;
      final nextLength = (currentLength + segmentLength).clamp(
        0.0,
        totalLength,
      );

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
      return Offset(
        landmark.x * canvasSize.width,
        landmark.y * canvasSize.height,
      );
    }

    final effectiveImageSize = (rotationDegrees == 90 || rotationDegrees == 270)
        ? Size(imageSize.height, imageSize.width)
        : imageSize;

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
