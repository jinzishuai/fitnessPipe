import 'dart:ui';

import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart' show Colors;

import '../../../domain/models/pose.dart';
import '../../../domain/models/pose_landmark.dart';
import 'exercise_guide.dart';

/// Visual guide for flat bench chest press exercise.
///
/// Draws a straight line connecting both wrists to simulate the barbell,
/// colored based on the current phase of the movement.
class BenchPressGuide extends ExerciseGuide {
  final BenchPressPhase currentPhase;

  const BenchPressGuide({required this.currentPhase});

  @override
  void paint(
    Canvas canvas,
    Size canvasSize,
    Pose pose, {
    Size? imageSize,
    int rotationDegrees = 0,
    bool inputsAreRotated = false,
  }) {
    final leftWrist = pose.getLandmark(LandmarkType.leftWrist);
    final rightWrist = pose.getLandmark(LandmarkType.rightWrist);

    if (leftWrist == null ||
        rightWrist == null ||
        !leftWrist.isVisible ||
        !rightWrist.isVisible) {
      return;
    }

    final leftWristPoint = _scalePoint(
      leftWrist,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );
    final rightWristPoint = _scalePoint(
      rightWrist,
      canvasSize,
      imageSize,
      rotationDegrees,
      inputsAreRotated,
    );

    Color barColor;
    switch (currentPhase) {
      case BenchPressPhase.waiting:
        barColor = Colors.white54;
        break;
      case BenchPressPhase.up:
        barColor = Colors.greenAccent;
        break;
      case BenchPressPhase.falling:
        barColor = Colors.orangeAccent;
        break;
      case BenchPressPhase.down:
        barColor = Colors.blueAccent;
        break;
      case BenchPressPhase.rising:
        barColor = Colors.purpleAccent;
        break;
    }

    // Draw the "barbell"
    final paint = Paint()
      ..color = barColor
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(leftWristPoint, rightWristPoint, paint);

    // Draw "plates" or ends of the bar
    final platePaint = Paint()
      ..color = barColor.withAlpha(204)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(leftWristPoint, 10.0, platePaint);
    canvas.drawCircle(rightWristPoint, 10.0, platePaint);
  }

  /// Scale a landmark's coordinates to canvas coordinates.
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
