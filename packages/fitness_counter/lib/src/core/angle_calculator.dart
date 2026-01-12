import 'dart:math';

import '../models/landmark.dart';

/// Calculate the shoulder abduction angle (arm raised from body).
///
/// This computes the angle between the upper arm and the torso
/// using the dot product formula.
///
/// Returns angle in degrees (0-180).
///
/// Example:
/// ```dart
/// final angle = calculateShoulderAngle(
///   shoulder: leftShoulder,
///   elbow: leftElbow,
///   hip: leftHip,
/// );
/// ```
double calculateShoulderAngle({
  required Landmark shoulder,
  required Landmark elbow,
  required Landmark hip,
}) {
  // Vector from shoulder to elbow (arm direction)
  final armX = elbow.x - shoulder.x;
  final armY = elbow.y - shoulder.y;

  // Vector from shoulder to hip (torso direction, pointing down)
  final torsoX = hip.x - shoulder.x;
  final torsoY = hip.y - shoulder.y;

  // Calculate magnitudes
  final armMagnitude = sqrt(armX * armX + armY * armY);
  final torsoMagnitude = sqrt(torsoX * torsoX + torsoY * torsoY);

  // Handle edge case: zero-length vectors
  if (armMagnitude == 0 || torsoMagnitude == 0) {
    return 0.0;
  }

  // Dot product
  final dotProduct = armX * torsoX + armY * torsoY;

  // Calculate cosine of angle
  final cosAngle = dotProduct / (armMagnitude * torsoMagnitude);

  // Clamp to valid range for acos (numerical stability)
  final clampedCos = cosAngle.clamp(-1.0, 1.0);

  // Calculate angle in radians, then convert to degrees
  final angleRadians = acos(clampedCos);
  final angleDegrees = angleRadians * 180.0 / pi;

  return angleDegrees;
}

/// Calculate the average shoulder angle from both arms.
///
/// If only one arm is visible, returns that arm's angle.
/// If neither arm is visible, returns 0.
double calculateAverageShoulderAngle({
  Landmark? leftShoulder,
  Landmark? leftElbow,
  Landmark? leftHip,
  Landmark? rightShoulder,
  Landmark? rightElbow,
  Landmark? rightHip,
}) {
  double? leftAngle;
  double? rightAngle;

  // Calculate left arm angle if all landmarks present
  if (leftShoulder != null && leftElbow != null && leftHip != null) {
    leftAngle = calculateShoulderAngle(
      shoulder: leftShoulder,
      elbow: leftElbow,
      hip: leftHip,
    );
  }

  // Calculate right arm angle if all landmarks present
  if (rightShoulder != null && rightElbow != null && rightHip != null) {
    rightAngle = calculateShoulderAngle(
      shoulder: rightShoulder,
      elbow: rightElbow,
      hip: rightHip,
    );
  }

  // Return based on what's available
  if (leftAngle != null && rightAngle != null) {
    return (leftAngle + rightAngle) / 2.0;
  } else if (leftAngle != null) {
    return leftAngle;
  } else if (rightAngle != null) {
    return rightAngle;
  } else {
    return 0.0;
  }
}
