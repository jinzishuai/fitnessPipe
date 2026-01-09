import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import '../../domain/interfaces/pose_detector.dart';
import '../../domain/models/pose.dart';
import '../../domain/models/pose_landmark.dart';

/// ML Kit-based implementation of [PoseDetector].
///
/// Uses google_mlkit_pose_detection package for pose detection.
/// Models are bundled in the app, no network download required.
class MLKitPoseDetector implements PoseDetector {
  mlkit.PoseDetector? _detector;
  bool _isInitialized = false;
  double _minConfidence = 0.5;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize(PoseDetectorConfig config) async {
    _minConfidence = config.minConfidence;

    final options = mlkit.PoseDetectorOptions(
      mode: config.mode == PoseDetectionMode.stream
          ? mlkit.PoseDetectionMode.stream
          : mlkit.PoseDetectionMode.single,
    );

    _detector = mlkit.PoseDetector(options: options);
    _isInitialized = true;
  }

  @override
  Future<List<Pose>> detectPoses(
    CameraImage image,
    Size imageSize,
    InputImageRotation rotation,
  ) async {
    if (!_isInitialized || _detector == null) {
      throw StateError('Detector not initialized. Call initialize() first.');
    }

    final inputImage = _convertToInputImage(image, rotation);
    if (inputImage == null) return [];

    final mlkitPoses = await _detector!.processImage(inputImage);

    return mlkitPoses
        .map((pose) => _convertPose(pose, imageSize, rotation))
        .where((pose) => pose.confidence >= _minConfidence)
        .toList();
  }

  @override
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
    _isInitialized = false;
  }

  /// Convert a camera image to ML Kit InputImage.
  mlkit.InputImage? _convertToInputImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final mlkitRotation = _convertRotation(rotation);

    // Get the image format based on platform
    final format = Platform.isAndroid
        ? mlkit.InputImageFormat.nv21
        : mlkit.InputImageFormat.bgra8888;

    // For Android, use nv21 format from the first plane
    // For iOS, use bgra8888 format
    final bytes = Platform.isAndroid
        ? image.planes.first.bytes
        : image.planes.first.bytes;

    final metadata = mlkit.InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: mlkitRotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return mlkit.InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  /// Convert our rotation enum to ML Kit's.
  mlkit.InputImageRotation _convertRotation(InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation0deg:
        return mlkit.InputImageRotation.rotation0deg;
      case InputImageRotation.rotation90deg:
        return mlkit.InputImageRotation.rotation90deg;
      case InputImageRotation.rotation180deg:
        return mlkit.InputImageRotation.rotation180deg;
      case InputImageRotation.rotation270deg:
        return mlkit.InputImageRotation.rotation270deg;
    }
  }

  /// Convert ML Kit pose to our domain model.
  Pose _convertPose(mlkit.Pose mlkitPose, Size imageSize, InputImageRotation rotation) {
    final landmarks = <PoseLandmark>[];
    double totalConfidence = 0;

    // When rotated 90 or 270 degrees, ML Kit returns coordinates in rotated space
    // So we need to normalize by the rotated dimensions
    final normalizeWidth = (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg)
        ? imageSize.height
        : imageSize.width;
    final normalizeHeight = (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg)
        ? imageSize.width
        : imageSize.height;

    for (final entry in mlkitPose.landmarks.entries) {
      final mlkitLandmark = entry.value;
      final landmarkType = _convertLandmarkType(entry.key);

      if (landmarkType != null) {
        landmarks.add(PoseLandmark(
          type: landmarkType,
          x: mlkitLandmark.x / normalizeWidth,
          y: mlkitLandmark.y / normalizeHeight,
          z: mlkitLandmark.z,
          confidence: mlkitLandmark.likelihood,
        ));
        totalConfidence += mlkitLandmark.likelihood;
      }
    }

    final avgConfidence =
        landmarks.isEmpty ? 0.0 : totalConfidence / landmarks.length;

    return Pose(
      landmarks: landmarks,
      confidence: avgConfidence,
      timestamp: DateTime.now(),
    );
  }

  /// Convert ML Kit landmark type to our enum.
  LandmarkType? _convertLandmarkType(mlkit.PoseLandmarkType mlkitType) {
    const mapping = {
      mlkit.PoseLandmarkType.nose: LandmarkType.nose,
      mlkit.PoseLandmarkType.leftEyeInner: LandmarkType.leftEyeInner,
      mlkit.PoseLandmarkType.leftEye: LandmarkType.leftEye,
      mlkit.PoseLandmarkType.leftEyeOuter: LandmarkType.leftEyeOuter,
      mlkit.PoseLandmarkType.rightEyeInner: LandmarkType.rightEyeInner,
      mlkit.PoseLandmarkType.rightEye: LandmarkType.rightEye,
      mlkit.PoseLandmarkType.rightEyeOuter: LandmarkType.rightEyeOuter,
      mlkit.PoseLandmarkType.leftEar: LandmarkType.leftEar,
      mlkit.PoseLandmarkType.rightEar: LandmarkType.rightEar,
      mlkit.PoseLandmarkType.leftMouth: LandmarkType.mouthLeft,
      mlkit.PoseLandmarkType.rightMouth: LandmarkType.mouthRight,
      mlkit.PoseLandmarkType.leftShoulder: LandmarkType.leftShoulder,
      mlkit.PoseLandmarkType.rightShoulder: LandmarkType.rightShoulder,
      mlkit.PoseLandmarkType.leftElbow: LandmarkType.leftElbow,
      mlkit.PoseLandmarkType.rightElbow: LandmarkType.rightElbow,
      mlkit.PoseLandmarkType.leftWrist: LandmarkType.leftWrist,
      mlkit.PoseLandmarkType.rightWrist: LandmarkType.rightWrist,
      mlkit.PoseLandmarkType.leftPinky: LandmarkType.leftPinky,
      mlkit.PoseLandmarkType.rightPinky: LandmarkType.rightPinky,
      mlkit.PoseLandmarkType.leftIndex: LandmarkType.leftIndex,
      mlkit.PoseLandmarkType.rightIndex: LandmarkType.rightIndex,
      mlkit.PoseLandmarkType.leftThumb: LandmarkType.leftThumb,
      mlkit.PoseLandmarkType.rightThumb: LandmarkType.rightThumb,
      mlkit.PoseLandmarkType.leftHip: LandmarkType.leftHip,
      mlkit.PoseLandmarkType.rightHip: LandmarkType.rightHip,
      mlkit.PoseLandmarkType.leftKnee: LandmarkType.leftKnee,
      mlkit.PoseLandmarkType.rightKnee: LandmarkType.rightKnee,
      mlkit.PoseLandmarkType.leftAnkle: LandmarkType.leftAnkle,
      mlkit.PoseLandmarkType.rightAnkle: LandmarkType.rightAnkle,
      mlkit.PoseLandmarkType.leftHeel: LandmarkType.leftHeel,
      mlkit.PoseLandmarkType.rightHeel: LandmarkType.rightHeel,
      mlkit.PoseLandmarkType.leftFootIndex: LandmarkType.leftFootIndex,
      mlkit.PoseLandmarkType.rightFootIndex: LandmarkType.rightFootIndex,
    };

    return mapping[mlkitType];
  }
}
