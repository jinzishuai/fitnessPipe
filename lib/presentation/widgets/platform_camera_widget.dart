// PlatformCameraWidget - Cross-platform camera feed wrapper

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as mobile_camera;
import 'package:camera_macos/camera_macos.dart';
import '../../controllers/pose_detection_controller.dart';

/// Camera feed widget for different platforms
/// Handles the static nature of native widgets in Flutter
class PlatformCameraWidget extends StatefulWidget {
  final PoseDetectionController controller;

  const PlatformCameraWidget({
    super.key,
    required this.controller,
  });

  @override
  State<PlatformCameraWidget> createState() => _PlatformCameraWidgetState();
}

class _PlatformCameraWidgetState extends State<PlatformCameraWidget>
    with WidgetsBindingObserver {
  bool _initialized = false;
  List<CameraMacOSDevice>? _macOSCameras;
  int _selectedCameraIndex = 0;
  MobileCameraInputSource? _inputSource;
  virtual bool _isVirtual = false;

  String? _startError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  void _initializeCamera() async {
    try {
      await widget.controller._poseDetector.initialize(
        const PoseDetectorConfig(mode: PoseDetectionMode.stream),
      );

      final isMacOS = Platform.isMacOS;

      if (isMacOS) {
        await _initializeMacOSScreen('Screen 0', null);
      } else {
        await _initializeMobileCamera();
      }
    } catch (e) {
      setState(() {
        _startError = e.toString();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _startError = 'Application not running';
    }
  }
}
