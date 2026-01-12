import 'package:fitness_counter/fitness_counter.dart' as counter;

import '../../domain/models/pose.dart';
import '../../domain/models/pose_landmark.dart';

/// Adapter to convert app's Pose model to fitness_counter's PoseFrame.
///
/// This decouples the counter package from the app's pose detection implementation.
class PoseAdapter {
  /// Convert app Pose to counter PoseFrame.
  counter.PoseFrame convert(Pose pose) {
    final landmarks = <counter.LandmarkId, counter.Landmark>{};

    for (final poseLandmark in pose.landmarks) {
      final id = _mapLandmarkType(poseLandmark.type);
      if (id != null) {
        landmarks[id] = counter.Landmark(
          x: poseLandmark.x,
          y: poseLandmark.y,
          z: poseLandmark.z,
          confidence: poseLandmark.confidence,
        );
      }
    }

    return counter.PoseFrame(
      landmarks: landmarks,
      timestamp: pose.timestamp,
    );
  }

  /// Map app's LandmarkType to counter's LandmarkId.
  counter.LandmarkId? _mapLandmarkType(LandmarkType type) {
    const mapping = {
      LandmarkType.nose: counter.LandmarkId.nose,
      LandmarkType.leftEyeInner: counter.LandmarkId.leftEyeInner,
      LandmarkType.leftEye: counter.LandmarkId.leftEye,
      LandmarkType.leftEyeOuter: counter.LandmarkId.leftEyeOuter,
      LandmarkType.rightEyeInner: counter.LandmarkId.rightEyeInner,
      LandmarkType.rightEye: counter.LandmarkId.rightEye,
      LandmarkType.rightEyeOuter: counter.LandmarkId.rightEyeOuter,
      LandmarkType.leftEar: counter.LandmarkId.leftEar,
      LandmarkType.rightEar: counter.LandmarkId.rightEar,
      LandmarkType.mouthLeft: counter.LandmarkId.mouthLeft,
      LandmarkType.mouthRight: counter.LandmarkId.mouthRight,
      LandmarkType.leftShoulder: counter.LandmarkId.leftShoulder,
      LandmarkType.rightShoulder: counter.LandmarkId.rightShoulder,
      LandmarkType.leftElbow: counter.LandmarkId.leftElbow,
      LandmarkType.rightElbow: counter.LandmarkId.rightElbow,
      LandmarkType.leftWrist: counter.LandmarkId.leftWrist,
      LandmarkType.rightWrist: counter.LandmarkId.rightWrist,
      LandmarkType.leftPinky: counter.LandmarkId.leftPinky,
      LandmarkType.rightPinky: counter.LandmarkId.rightPinky,
      LandmarkType.leftIndex: counter.LandmarkId.leftIndex,
      LandmarkType.rightIndex: counter.LandmarkId.rightIndex,
      LandmarkType.leftThumb: counter.LandmarkId.leftThumb,
      LandmarkType.rightThumb: counter.LandmarkId.rightThumb,
      LandmarkType.leftHip: counter.LandmarkId.leftHip,
      LandmarkType.rightHip: counter.LandmarkId.rightHip,
      LandmarkType.leftKnee: counter.LandmarkId.leftKnee,
      LandmarkType.rightKnee: counter.LandmarkId.rightKnee,
      LandmarkType.leftAnkle: counter.LandmarkId.leftAnkle,
      LandmarkType.rightAnkle: counter.LandmarkId.rightAnkle,
      LandmarkType.leftHeel: counter.LandmarkId.leftHeel,
      LandmarkType.rightHeel: counter.LandmarkId.rightHeel,
      LandmarkType.leftFootIndex: counter.LandmarkId.leftFootIndex,
      LandmarkType.rightFootIndex: counter.LandmarkId.rightFootIndex,
    };

    return mapping[type];
  }
}
