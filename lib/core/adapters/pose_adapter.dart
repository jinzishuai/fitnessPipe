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

    return counter.PoseFrame(landmarks: landmarks, timestamp: pose.timestamp);
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

  /// Convert counter's LandmarkId to app's LandmarkType.
  static LandmarkType? toLandmarkType(counter.LandmarkId id) {
    const mapping = {
      counter.LandmarkId.nose: LandmarkType.nose,
      counter.LandmarkId.leftEyeInner: LandmarkType.leftEyeInner,
      counter.LandmarkId.leftEye: LandmarkType.leftEye,
      counter.LandmarkId.leftEyeOuter: LandmarkType.leftEyeOuter,
      counter.LandmarkId.rightEyeInner: LandmarkType.rightEyeInner,
      counter.LandmarkId.rightEye: LandmarkType.rightEye,
      counter.LandmarkId.rightEyeOuter: LandmarkType.rightEyeOuter,
      counter.LandmarkId.leftEar: LandmarkType.leftEar,
      counter.LandmarkId.rightEar: LandmarkType.rightEar,
      counter.LandmarkId.mouthLeft: LandmarkType.mouthLeft,
      counter.LandmarkId.mouthRight: LandmarkType.mouthRight,
      counter.LandmarkId.leftShoulder: LandmarkType.leftShoulder,
      counter.LandmarkId.rightShoulder: LandmarkType.rightShoulder,
      counter.LandmarkId.leftElbow: LandmarkType.leftElbow,
      counter.LandmarkId.rightElbow: LandmarkType.rightElbow,
      counter.LandmarkId.leftWrist: LandmarkType.leftWrist,
      counter.LandmarkId.rightWrist: LandmarkType.rightWrist,
      counter.LandmarkId.leftPinky: LandmarkType.leftPinky,
      counter.LandmarkId.rightPinky: LandmarkType.rightPinky,
      counter.LandmarkId.leftIndex: LandmarkType.leftIndex,
      counter.LandmarkId.rightIndex: LandmarkType.rightIndex,
      counter.LandmarkId.leftThumb: LandmarkType.leftThumb,
      counter.LandmarkId.rightThumb: LandmarkType.rightThumb,
      counter.LandmarkId.leftHip: LandmarkType.leftHip,
      counter.LandmarkId.rightHip: LandmarkType.rightHip,
      counter.LandmarkId.leftKnee: LandmarkType.leftKnee,
      counter.LandmarkId.rightKnee: LandmarkType.rightKnee,
      counter.LandmarkId.leftAnkle: LandmarkType.leftAnkle,
      counter.LandmarkId.rightAnkle: LandmarkType.rightAnkle,
      counter.LandmarkId.leftHeel: LandmarkType.leftHeel,
      counter.LandmarkId.rightHeel: LandmarkType.rightHeel,
      counter.LandmarkId.leftFootIndex: LandmarkType.leftFootIndex,
      counter.LandmarkId.rightFootIndex: LandmarkType.rightFootIndex,
    };

    return mapping[id];
  }

  /// Convert a set of counter LandmarkIds to app LandmarkTypes.
  static Set<LandmarkType> toLandmarkTypeSet(Set<counter.LandmarkId> ids) {
    return ids
        .map((id) => toLandmarkType(id))
        .whereType<LandmarkType>()
        .toSet();
  }

  /// Convert bone connections from counter LandmarkIds to app LandmarkTypes.
  static List<(LandmarkType, LandmarkType)> toBoneConnections(
    List<(counter.LandmarkId, counter.LandmarkId)> bones,
  ) {
    return bones
        .map((pair) {
          final start = toLandmarkType(pair.$1);
          final end = toLandmarkType(pair.$2);
          if (start != null && end != null) {
            return (start, end);
          }
          return null;
        })
        .whereType<(LandmarkType, LandmarkType)>()
        .toList();
  }
}
