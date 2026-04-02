import 'package:fitness_pipe/presentation/screens/pose_detection_input_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PoseDetectionInputMode', () {
    test('camera modes have labels and no file-preview metadata', () {
      expect(PoseDetectionInputMode.frontCamera.label, 'Front Camera');
      expect(PoseDetectionInputMode.backCamera.label, 'Back Camera');

      expect(PoseDetectionInputMode.frontCamera.isFilePreviewMode, isFalse);
      expect(PoseDetectionInputMode.backCamera.isFilePreviewMode, isFalse);

      expect(PoseDetectionInputMode.frontCamera.poseLabel, 'Pose');
      expect(PoseDetectionInputMode.backCamera.poseLabel, 'Pose');

      expect(PoseDetectionInputMode.frontCamera.badgeLabel, isEmpty);
      expect(PoseDetectionInputMode.backCamera.badgeLabel, isEmpty);
      expect(PoseDetectionInputMode.frontCamera.badgeColor, isNull);
      expect(PoseDetectionInputMode.backCamera.badgeColor, isNull);
    });

    test('library video mode exposes replay-specific metadata', () {
      expect(PoseDetectionInputMode.libraryVideo.label, 'Library Video');
      expect(PoseDetectionInputMode.libraryVideo.isFilePreviewMode, isTrue);
      expect(PoseDetectionInputMode.libraryVideo.poseLabel, 'Video Pose');
      expect(PoseDetectionInputMode.libraryVideo.badgeLabel, 'VIDEO REPLAY');
      expect(PoseDetectionInputMode.libraryVideo.badgeColor, Colors.blueAccent);
    });

    test('simulator mode exposes fixture-specific metadata', () {
      expect(
        PoseDetectionInputMode.simulatorFixtures.label,
        'Simulator Fixtures',
      );
      expect(
        PoseDetectionInputMode.simulatorFixtures.isFilePreviewMode,
        isTrue,
      );
      expect(
        PoseDetectionInputMode.simulatorFixtures.poseLabel,
        'Virtual Pose',
      );
      expect(
        PoseDetectionInputMode.simulatorFixtures.badgeLabel,
        'SIMULATOR MODE',
      );
      expect(
        PoseDetectionInputMode.simulatorFixtures.badgeColor,
        Colors.redAccent,
      );
    });
  });
}
