import 'package:flutter/material.dart';

enum PoseDetectionInputMode {
  frontCamera,
  backCamera,
  libraryVideo,
  simulatorFixtures,
}

extension PoseDetectionInputModeMetadata on PoseDetectionInputMode {
  String get label {
    return switch (this) {
      PoseDetectionInputMode.frontCamera => 'Front Camera',
      PoseDetectionInputMode.backCamera => 'Back Camera',
      PoseDetectionInputMode.libraryVideo => 'Library Video',
      PoseDetectionInputMode.simulatorFixtures => 'Simulator Fixtures',
    };
  }

  bool get isFilePreviewMode {
    return switch (this) {
      PoseDetectionInputMode.libraryVideo ||
      PoseDetectionInputMode.simulatorFixtures => true,
      PoseDetectionInputMode.frontCamera ||
      PoseDetectionInputMode.backCamera => false,
    };
  }

  String get poseLabel {
    return switch (this) {
      PoseDetectionInputMode.libraryVideo => 'Video Pose',
      PoseDetectionInputMode.simulatorFixtures => 'Virtual Pose',
      PoseDetectionInputMode.frontCamera ||
      PoseDetectionInputMode.backCamera => 'Pose',
    };
  }

  String get badgeLabel {
    return switch (this) {
      PoseDetectionInputMode.libraryVideo => 'VIDEO REPLAY',
      PoseDetectionInputMode.simulatorFixtures => 'SIMULATOR MODE',
      PoseDetectionInputMode.frontCamera ||
      PoseDetectionInputMode.backCamera => '',
    };
  }

  Color? get badgeColor {
    return switch (this) {
      PoseDetectionInputMode.libraryVideo => Colors.blueAccent,
      PoseDetectionInputMode.simulatorFixtures => Colors.redAccent,
      PoseDetectionInputMode.frontCamera ||
      PoseDetectionInputMode.backCamera => null,
    };
  }
}
