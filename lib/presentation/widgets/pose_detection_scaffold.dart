// pose_detection_scaffold.dart - Top-level screen widget
// Replaces the main body building logic from pose_detection_screen.dart

import 'package:flutter/material.dart';
import '../screens/pose_detection_controller.dart';
import '../screens/lib/pose_detection_camera.dart' as camerasLib;
import '../widgets/skeleton_overlay.dart';
import '../widgets/pose_detection_overlay.dart';
import '../widgets/platform_camera_widget.dart' as platformCam;

class PoseDetectionScaffold extends StatelessWidget {
  final PoseDetectionController controller;
  final BuildContext buildContext;

  const PoseDetectionScaffold({
    super.key,
    required this.controller,
    required this.buildContext,
  });

  @override
  Widget build(BuildContext context) {
    if (controller._isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (controller._errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(controller._errorMessage!),
        ),
      );
    }

    return Card(
      child: Column(
        children: [platformCam.PlatformCameraWidget(controller: controller)],
      ),
    );
  }
}
