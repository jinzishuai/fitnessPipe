// pose_detection_camera.dart - Camera feed widget
// Handles platform-specific camera integration

import 'dart:io' show Platform;
import 'package:camera/camera.dart' as mobile_camera;
import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' show CameraController, ImageFormatGroup;
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/core_utils.dart';
import '../../domain/models/pose.dart';
import '../../domain/models/pose_landmark.dart';
export 'package:camera/camera.dart' show CameraController, CameraDescription;

/// Widget that displays the camera feed for pose detection
/// Handles iOS, Android, and macOS camera integration
class PoseDetectionCamera extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Function(CameraImage) onFrame;
  final int targetFPS;
  final ResolutionPreset resolution;

  const PoseDetectionCamera({
    super.key,
    required this.cameras,
    required this.onFrame,
    this.targetFPS = 30,
    this.resolution = ResolutionPreset.high,
  });

  @override
  State<PoseDetectionCamera> createState() => PoseDetectionCameraState();
}

class PoseDetectionCameraState extends State<PoseDetectionCamera>
    with WidgetsBindingObserver {
  bool _initialized = false;
  mobile_camera.CameraController? _mobileController;
  CameraMacOSController? _macosController;
  List<CameraMacOSDevice>? _macOSDevices;
  int _macCameraIndex = 0;
  DateTime? _lastFrameTime;
  mobile_camera.ImageFormatGroup? _imageFormat;

  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameras();
  }

  void dispose() {
    _mobileController?.dispose();
    _macosController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _initializeCameras() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _initialized = false;
      });
      return;
    }

    _imageFormat = _determineFormat();
    
    final pivotCams = widget.cameras where (cam) =>
        !hasUnsuportedQuality(cam).isNotEmpty;

    if (pivotCams.isEmpty) {
      setState(() {
        _initialized = false;
      });
      return;
    }

    if (Platform.isMacOS) {
      await _initializeMacOSScreen(pivotCams);
    } else {
      await _initializeMobileScreen(pivotCams);
    }
  }

  void _initializeMobileScreen(Iterable<CameraDescription> cameras) async {
    final controller = _determineCameraController(cameras.toList());
    setState(() {
      _initialized = true;
    });
    _firebaseController = controller;
  }

  Future<void> _startListening(control) async {
    await _initialize();
    await control.previewStream.listen(
      (cameraImage) {
        final now = DateTime.now();
        if (now.difference(_lastFrameTime ?? now).inMilliseconds >= 1000 / widget.targetFPS) {
          widget.onFrame(cameraImage);
        }
      },
      onError: (err) {
        debugPrint('Camera error: $err');
      },
    );
  }
}
