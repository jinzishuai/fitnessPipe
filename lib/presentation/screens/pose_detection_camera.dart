part of 'pose_detection_screen.dart';

extension _PoseDetectionScreenCamera on _PoseDetectionScreenState {
  void _initializeScreen() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    _poseDetector = MLKitPoseDetector();
    _voiceGuidanceService = VoiceGuidanceService();
    _mobileInputSource = MobileCameraInputSource(
      rotationProvider: _getMobileImageRotation,
    );
    _libraryVideoInputSource = LibraryVideoInputSource();

    _initializeCamera();
  }

  void _disposeScreen() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    _mobileInputSource?.dispose();
    _macOSCameraController?.destroy();
    _virtualInputSource?.dispose();
    _libraryVideoInputSource?.dispose();
    _voiceGuidanceService.dispose();
    _feedbackClearTimer?.cancel();
    _poseDetector.dispose();
  }

  void _handleAppLifecycleStateChange(AppLifecycleState state) {
    if (_isPickingLibraryVideo) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _updateState(() {
        _isLoading = true;
      });
      _mobileInputSource?.dispose();
      _macOSCameraController?.destroy();
      _virtualInputSource?.stop();
      _libraryVideoInputSource?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    _updateState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _poseDetector.initialize(
        const PoseDetectorConfig(mode: PoseDetectionMode.stream),
      );

      if (_isMacOS) {
        await _initializeMacOSCamera();
      } else {
        await _initializeMobileCamera();
      }
    } catch (e) {
      _updateState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeMobileCamera() async {
    final mobileInputSource = _mobileInputSource!;
    await mobileInputSource.initialize();

    if (_currentInputMode == PoseDetectionInputMode.libraryVideo) {
      await _startLibraryVideo();
      return;
    }

    if (mobileInputSource.shouldUseVirtualFallback && Platform.isIOS) {
      _currentInputMode ??= PoseDetectionInputMode.simulatorFixtures;
      await _initializeVirtualCamera();
      return;
    }

    if (!mobileInputSource.hasCameras) {
      _updateState(() {
        _errorMessage = 'No cameras available';
        _isLoading = false;
      });
      return;
    }

    final preferredMode =
        _currentInputMode ??
        (mobileInputSource.hasLensDirection(
              mobile_camera.CameraLensDirection.front,
            )
            ? PoseDetectionInputMode.frontCamera
            : PoseDetectionInputMode.backCamera);
    _currentInputMode = preferredMode;

    if (_currentInputMode == PoseDetectionInputMode.backCamera &&
        mobileInputSource.hasLensDirection(
          mobile_camera.CameraLensDirection.back,
        )) {
      mobileInputSource.selectLensDirection(
        mobile_camera.CameraLensDirection.back,
      );
    } else {
      _currentInputMode = PoseDetectionInputMode.frontCamera;
      mobileInputSource.selectPreferredCamera();
    }
    await _startMobileCamera();
  }

  Future<void> _initializeVirtualCamera() async {
    await _mobileInputSource?.stop();
    await _libraryVideoInputSource?.stop();
    await _virtualInputSource?.dispose();

    _virtualInputSource = VirtualCameraInputSource(
      initialExercise: _selectedExercise ?? ExerciseType.lateralRaise,
    );

    _updateState(() {
      _isVirtualCamera = true;
    });

    await _virtualInputSource!.start(_processInputFrame);

    _updateState(() {
      _isLoading = false;
    });
  }

  Future<void> _startLibraryVideo({bool repick = false}) async {
    await _mobileInputSource?.stop();
    await _virtualInputSource?.stop();

    final needsPick =
        repick || !(_libraryVideoInputSource?.hasSelectedVideo ?? false);
    bool selected = true;
    if (needsPick) {
      _isPickingLibraryVideo = true;
      try {
        selected = await _libraryVideoInputSource!.pickVideo(forcePick: repick);
      } finally {
        _isPickingLibraryVideo = false;
      }
    }

    if (!selected) {
      throw const LibraryVideoSelectionCanceled();
    }

    await _libraryVideoInputSource!.start(_processInputFrame);
    _updateState(() {
      _isVirtualCamera = false;
      _isLoading = false;
    });
  }

  void _processInputFrame(PoseInputFrame frame) async {
    if (frame.previewFile != null && mounted) {
      final now = DateTime.now();
      if (now.difference(_lastPreviewFrameUpdate).inMilliseconds >= 100) {
        _lastPreviewFrameUpdate = now;
        _updateState(() {
          _currentPreviewFrameFile = frame.previewFile;
        });
      } else {
        _currentPreviewFrameFile = frame.previewFile;
      }
    }

    _processPoseDetection(frame.inputImage, previewSize: frame.previewSize);
  }

  Future<void> _startMobileCamera() async {
    try {
      await _virtualInputSource?.stop();
      await _libraryVideoInputSource?.stop();
      await _mobileInputSource!.start(_processInputFrame);

      _updateState(() {
        _isVirtualCamera = false;
        _isLoading = false;
      });
    } on mobile_camera.CameraException catch (e) {
      _updateState(() {
        _errorMessage = 'Camera error: ${e.description}';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeMacOSCamera() async {
    try {
      final cameras = await CameraMacOS.instance.listDevices(
        deviceType: CameraMacOSDeviceType.video,
      );

      if (cameras.isEmpty) {
        _updateState(() {
          _errorMessage = 'No cameras available on macOS';
          _isLoading = false;
        });
        return;
      }

      _macOSCameras = cameras;
      _selectedMacOSCameraIndex = 0;
      _macOSCameraKey = GlobalKey();

      _updateState(() {
        _isLoading = false;
      });
    } catch (e) {
      _updateState(() {
        _errorMessage = 'Failed to initialize macOS camera: $e';
        _isLoading = false;
      });
    }
  }

  void _onMacOSCameraInitialized(CameraMacOSController controller) {
    _macOSCameraController = controller;
    debugPrint('macOS camera initialized');
  }

  Future<void> _handleInputModeSelection(PoseDetectionInputMode mode) async {
    final previousMode = _currentInputMode;
    final repick =
        mode == PoseDetectionInputMode.libraryVideo &&
        previousMode == PoseDetectionInputMode.libraryVideo;

    _updateState(() {
      _errorMessage = null;
      _isLoading = true;
      _currentPose = null;
      _cameraImageSize = null;
      if (mode != PoseDetectionInputMode.libraryVideo) {
        _currentPreviewFrameFile = null;
      }
    });

    try {
      if (_isMacOS) {
        return;
      }

      if (mode == PoseDetectionInputMode.frontCamera) {
        _currentInputMode = mode;
        _mobileInputSource?.selectLensDirection(
          mobile_camera.CameraLensDirection.front,
        );
        await _startMobileCamera();
      } else if (mode == PoseDetectionInputMode.backCamera) {
        _currentInputMode = mode;
        _mobileInputSource?.selectLensDirection(
          mobile_camera.CameraLensDirection.back,
        );
        await _startMobileCamera();
      } else if (mode == PoseDetectionInputMode.libraryVideo) {
        _currentInputMode = mode;
        await _startLibraryVideo(repick: repick);
      } else if (mode == PoseDetectionInputMode.simulatorFixtures) {
        _currentInputMode = mode;
        await _initializeVirtualCamera();
      }
    } on LibraryVideoSelectionCanceled {
      _updateState(() {
        _currentInputMode = previousMode;
        _isLoading = false;
      });
    } catch (error) {
      _updateState(() {
        _currentInputMode = previousMode;
        _errorMessage = 'Failed to switch input: $error';
        _isLoading = false;
      });
    }
  }

  void _processPoseDetection(InputImage inputImage, {Size? previewSize}) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final poses = await _poseDetector.detectPoses(inputImage);

      if (mounted) {
        _updateState(() {
          if (inputImage.metadata?.size != null) {
            _cameraImageSize = inputImage.metadata!.size;
          } else if (previewSize != null) {
            _cameraImageSize = previewSize;
          } else {
            _cameraImageSize = const Size(1, 1);
          }

          _currentPose = poses.isNotEmpty ? poses.first : null;

          if (_currentPose != null) {
            _processPoseWithCounter(_currentPose!);
          }
        });
      }
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImageRotation _getMobileImageRotation() {
    final sensorOrientation = _mobileInputSource?.sensorOrientation ?? 0;
    if (sensorOrientation == 0) return InputImageRotation.rotation0deg;

    _sensorOrientation = sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotation.rotation0deg;
    }

    final effectiveDeviceRotation = _deviceRotation == 180
        ? 0
        : _deviceRotation;
    final rotation = (sensorOrientation - effectiveDeviceRotation + 360) % 360;

    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  bool get _isFilePreviewMode => _currentInputMode?.isFilePreviewMode ?? false;

  bool get _canShowInputSelector {
    if (_isMacOS) return false;
    return _availableInputModes.length > 1;
  }

  List<PoseDetectionInputMode> get _availableInputModes {
    if (_isMacOS) return const [];

    final modes = <PoseDetectionInputMode>[];
    final mobileInputSource = _mobileInputSource;
    final hasFront =
        mobileInputSource?.hasLensDirection(
          mobile_camera.CameraLensDirection.front,
        ) ??
        false;
    final hasBack =
        mobileInputSource?.hasLensDirection(
          mobile_camera.CameraLensDirection.back,
        ) ??
        false;

    if (hasFront) modes.add(PoseDetectionInputMode.frontCamera);
    if (hasBack) modes.add(PoseDetectionInputMode.backCamera);
    if (Platform.isIOS) {
      modes.add(PoseDetectionInputMode.libraryVideo);
    }
    if (_isVirtualCamera ||
        (Platform.isIOS &&
            (mobileInputSource?.shouldUseVirtualFallback ?? false))) {
      modes.add(PoseDetectionInputMode.simulatorFixtures);
    }
    return modes;
  }

  String get _filePreviewPoseLabel =>
      _currentInputMode?.poseLabel ??
      PoseDetectionInputMode.frontCamera.poseLabel;

  String get _filePreviewBadgeLabel => _currentInputMode?.badgeLabel ?? '';

  Color? get _filePreviewBadgeColor => _currentInputMode?.badgeColor;
}
