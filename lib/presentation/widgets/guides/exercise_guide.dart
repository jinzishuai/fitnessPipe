import 'dart:ui';

import '../../../domain/models/pose.dart';

/// Abstract base class for exercise-specific visual guides.
///
/// Implementations draw overlay guides (e.g., target arm positions for lateral raise)
/// to help users maintain proper form during exercises.
abstract class ExerciseGuide {
  const ExerciseGuide();

  /// Paint the guide overlay on the canvas.
  ///
  /// [canvas] - Canvas to draw on
  /// [canvasSize] - Size of the rendering canvas
  /// [pose] - Current detected pose with landmark positions
  /// [imageSize] - Original camera image size (for coordinate scaling)
  /// [rotationDegrees] - Rotation applied to match camera orientation
  /// [inputsAreRotated] - Whether ML Kit already rotated the coordinates
  void paint(
    Canvas canvas,
    Size canvasSize,
    Pose pose, {
    Size? imageSize,
    int rotationDegrees = 0,
    bool inputsAreRotated = false,
  });
}
