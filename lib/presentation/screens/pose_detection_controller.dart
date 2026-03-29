part of 'pose_detection_screen.dart';

class _PoseDetectionScreenState extends State<PoseDetectionScreen>
    with WidgetsBindingObserver {
  // Pose detection
  late final PoseDetector _poseDetector;
  Pose? _currentPose;
  bool _isDetecting = false;

  // Exercise counter
  final _poseAdapter = PoseAdapter();
  ExerciseType? _selectedExercise;
  LateralRaiseCounter? _lateralRaiseCounter;
  LateralRaiseFormAnalyzer? _lateralRaiseFormAnalyzer;
  SingleSquatCounter? _singleSquatCounter;
  BenchPressCounter? _benchPressCounter;
  BenchPressFormAnalyzer? _benchPressFormAnalyzer;
  int _repCount = 0;
  String _phaseLabel = 'Ready';
  Color _phaseColor = Colors.grey;
  double _currentAngle = 0.0;
  FormFeedback? _currentFeedback;
  FilteredFeedback? _displayedFeedback;

  // Voice guidance and feedback throttling
  late final VoiceGuidanceService _voiceGuidanceService;
  FeedbackCooldownManager? _feedbackCooldownManager;
  Timer? _feedbackClearTimer;

  // Exercise demo tracking
  final ExerciseDemoService _exerciseDemoService = ExerciseDemoService();
  bool _isDemoShowing = false;

  // Threshold configuration
  double _topThreshold = 70.0;
  double _bottomThreshold = 25.0;
  // Squat thresholds (defaults)
  double _squatTopThreshold = 170.0;
  double _squatBottomThreshold = 160.0;
  // Form sensitivity (lateral raise)
  LateralRaiseSensitivity _currentSensitivity =
      const LateralRaiseSensitivity.defaults();

  // Bench Press
  double _benchPressTopThreshold = 150.0;
  double _benchPressBottomThreshold = 90.0;
  final BenchPressSensitivity _benchPressSensitivity =
      const BenchPressSensitivity.defaults();

  // UI state
  bool _isLoading = true;
  String? _errorMessage;
  Size? _cameraImageSize;
  int _sensorOrientation = 0;
  int _deviceRotation =
      0; // 0=portrait, 90=landscape left, 180=portrait upside down, 270=landscape right

  // Platform-specific camera handling
  final bool _isMacOS = Platform.isMacOS;
  // Check for simulator (simple heuristics for now, or device_info in future)
  // Platform.isIOS is true on generic iOS.
  // We can use the deviceInfo plugin, but maybe we can just try/catch camera init or use a flag?
  // Let's assume we need to import device_info_plus or similar if we want robust checks.
  // Actually, `Platform.environment` might have info? Or checking if cameras are empty on iOS?
  // `availableCameras()` returns empty list on Simulator usually.

  bool _isVirtualCamera = false;
  MobileCameraInputSource? _mobileInputSource;
  VirtualCameraInputSource? _virtualInputSource;
  LibraryVideoInputSource? _libraryVideoInputSource;
  _PoseInputMode? _currentInputMode;
  bool _isPickingLibraryVideo = false;

  // macOS camera
  CameraMacOSController? _macOSCameraController;
  List<CameraMacOSDevice>? _macOSCameras;
  int _selectedMacOSCameraIndex = 0;
  GlobalKey? _macOSCameraKey;

  /// Get the visible landmarks for the current exercise (null = show all).
  Set<LandmarkType>? get _visibleLandmarks {
    if (_selectedExercise == null) return null;
    return PoseAdapter.toLandmarkTypeSet(
      _selectedExercise!.config.visibleLandmarks,
    );
  }

  /// Get the visible bone connections for the current exercise (null = show all).
  List<(LandmarkType, LandmarkType)>? get _visibleBones {
    if (_selectedExercise == null) return null;
    return PoseAdapter.toBoneConnections(
      _selectedExercise!.config.visibleBones,
    );
  }

  /// Get the visual guide for the current exercise.
  ExerciseGuide? get _currentGuide {
    if (_selectedExercise == ExerciseType.lateralRaise &&
        _lateralRaiseCounter != null) {
      return LateralRaiseGuide(
        topThreshold: _topThreshold,
        bottomThreshold: _bottomThreshold,
        currentPhase: _lateralRaiseCounter!.state.phase,
      );
    } else if (_selectedExercise == ExerciseType.benchPress &&
        _benchPressCounter != null) {
      return BenchPressGuide(currentPhase: _benchPressCounter!.state.phase);
    }
    // Other exercises don't have guides yet
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    _poseDetector = MLKitPoseDetector();
    _voiceGuidanceService = VoiceGuidanceService();
    _mobileInputSource = MobileCameraInputSource(
      rotationProvider: _getMobileImageRotation,
    );
    _libraryVideoInputSource = LibraryVideoInputSource();

    // Counter will be initialized when user selects an exercise

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    _mobileInputSource?.dispose();
    _macOSCameraController?.destroy();
    _virtualInputSource?.dispose();
    _libraryVideoInputSource?.dispose();
    _voiceGuidanceService.dispose();
    _feedbackClearTimer?.cancel();
    _poseDetector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPickingLibraryVideo) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      setState(() {
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Initialize pose detector
      await _poseDetector.initialize(
        const PoseDetectorConfig(mode: PoseDetectionMode.stream),
      );

      if (_isMacOS) {
        await _initializeMacOSCamera();
      } else {
        await _initializeMobileCamera();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeMobileCamera() async {
    final mobileInputSource = _mobileInputSource!;
    await mobileInputSource.initialize();

    if (_currentInputMode == _PoseInputMode.libraryVideo) {
      await _startLibraryVideo();
      return;
    }

    // If no cameras found on iOS, assume Simulator and try Virtual Camera
    // Note: checking if cameras is empty is a decent heuristic for Simulator on some versions,
    // but explicit platform check is better.
    if (mobileInputSource.shouldUseVirtualFallback && Platform.isIOS) {
      _currentInputMode ??= _PoseInputMode.simulatorFixtures;
      await _initializeVirtualCamera();
      return;
    }

    if (!mobileInputSource.hasCameras) {
      setState(() {
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
            ? _PoseInputMode.frontCamera
            : _PoseInputMode.backCamera);
    _currentInputMode = preferredMode;

    if (_currentInputMode == _PoseInputMode.backCamera &&
        mobileInputSource.hasLensDirection(
          mobile_camera.CameraLensDirection.back,
        )) {
      mobileInputSource.selectLensDirection(
        mobile_camera.CameraLensDirection.back,
      );
    } else {
      _currentInputMode = _PoseInputMode.frontCamera;
      mobileInputSource.selectPreferredCamera();
    }
    await _startMobileCamera();
  }

  Future<void> _initializeVirtualCamera() async {
    // Dispose any existing service to prevent multiple timers (issue #42)
    await _mobileInputSource?.stop();
    await _libraryVideoInputSource?.stop();
    await _virtualInputSource?.dispose();

    // Initialize with the currently selected exercise to avoid state reset
    _virtualInputSource = VirtualCameraInputSource(
      initialExercise: _selectedExercise ?? ExerciseType.lateralRaise,
    );

    setState(() {
      _isVirtualCamera = true;
    });

    // Start streaming
    await _virtualInputSource!.start(_processInputFrame);

    // Initial loading done
    setState(() {
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
    setState(() {
      _isVirtualCamera = false;
      _isLoading = false;
    });
  }

  File? _currentPreviewFrameFile;
  DateTime _lastPreviewFrameUpdate = DateTime(0);

  void _processInputFrame(PoseInputFrame frame) async {
    // Update the UI preview, throttled to ~10fps to allow the iOS
    // accessibility tree to stabilize (fixes Maestro element discovery, #50).
    if (frame.previewFile != null && mounted) {
      final now = DateTime.now();
      if (now.difference(_lastPreviewFrameUpdate).inMilliseconds >= 100) {
        _lastPreviewFrameUpdate = now;
        setState(() {
          _currentPreviewFrameFile = frame.previewFile;
        });
      } else {
        // Still update the file reference for pose detection without setState
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

      setState(() {
        _isVirtualCamera = false;
        _isLoading = false;
      });
    } on mobile_camera.CameraException catch (e) {
      setState(() {
        _errorMessage = 'Camera error: ${e.description}';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeMacOSCamera() async {
    try {
      // Get available cameras
      final cameras = await CameraMacOS.instance.listDevices(
        deviceType: CameraMacOSDeviceType.video,
      );

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available on macOS';
          _isLoading = false;
        });
        return;
      }

      _macOSCameras = cameras;
      _selectedMacOSCameraIndex = 0;
      _macOSCameraKey = GlobalKey();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize macOS camera: $e';
        _isLoading = false;
      });
    }
  }

  void _onMacOSCameraInitialized(CameraMacOSController controller) {
    _macOSCameraController = controller;
    // Note: camera_macos doesn't support image streaming for ML processing
    // We'll show just the camera preview for now
    debugPrint('macOS camera initialized');
  }

  Future<void> _handleInputModeSelection(_PoseInputMode mode) async {
    final previousMode = _currentInputMode;
    final repick =
        mode == _PoseInputMode.libraryVideo &&
        previousMode == _PoseInputMode.libraryVideo;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _currentPose = null;
      _cameraImageSize = null;
      if (mode != _PoseInputMode.libraryVideo) {
        _currentPreviewFrameFile = null;
      }
    });

    try {
      if (_isMacOS) {
        return;
      }

      if (mode == _PoseInputMode.frontCamera) {
        _currentInputMode = mode;
        _mobileInputSource?.selectLensDirection(
          mobile_camera.CameraLensDirection.front,
        );
        await _startMobileCamera();
      } else if (mode == _PoseInputMode.backCamera) {
        _currentInputMode = mode;
        _mobileInputSource?.selectLensDirection(
          mobile_camera.CameraLensDirection.back,
        );
        await _startMobileCamera();
      } else if (mode == _PoseInputMode.libraryVideo) {
        _currentInputMode = mode;
        await _startLibraryVideo(repick: repick);
      } else if (mode == _PoseInputMode.simulatorFixtures) {
        _currentInputMode = mode;
        await _initializeVirtualCamera();
      }
    } on LibraryVideoSelectionCanceled {
      setState(() {
        _currentInputMode = previousMode;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
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
        setState(() {
          if (inputImage.metadata?.size != null) {
            _cameraImageSize = inputImage.metadata!.size;
          } else if (previewSize != null) {
            _cameraImageSize = previewSize;
          } else {
            _cameraImageSize = const Size(1, 1);
          }

          _currentPose = poses.isNotEmpty ? poses.first : null;

          // Process pose through counter if exercise selected
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

  void _processPoseWithCounter(Pose pose) {
    if (_selectedExercise == null) return;
    if (_isDemoShowing) return;

    final poseFrame = _poseAdapter.convert(pose);
    RepEvent? event;

    // Update UI state - MUST use setState to trigger rebuild
    setState(() {
      if (_selectedExercise == ExerciseType.lateralRaise &&
          _lateralRaiseCounter != null) {
        event = _lateralRaiseCounter!.processPose(poseFrame);
        final state = _lateralRaiseCounter!.state;
        _repCount = state.repCount;
        _currentAngle = state.smoothedAngle;

        // Form Analysis
        if (_lateralRaiseFormAnalyzer != null) {
          _currentFeedback = _lateralRaiseFormAnalyzer!.analyzeFrame(
            poseFrame.landmarks,
          );

          // Throttle feedback for both visual and voice
          if (_currentFeedback != null && _feedbackCooldownManager != null) {
            final filtered = _feedbackCooldownManager!.processFeedback(
              _currentFeedback!,
            );
            if (filtered != null) {
              _displayedFeedback = filtered;
              _voiceGuidanceService.speak(filtered);
              // Auto-clear visual feedback after 3 seconds
              _feedbackClearTimer?.cancel();
              _feedbackClearTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _displayedFeedback = null;
                  });
                }
              });
            }
          }
        }

        // Map LateralRaisePhase to UI
        final (label, color) = switch (state.phase) {
          LateralRaisePhase.waiting => ('Ready...', Colors.grey),
          LateralRaisePhase.down => ('Down', Colors.blue),
          LateralRaisePhase.rising => ('Rising ↑', Colors.orange),
          LateralRaisePhase.up => ('Up!', Colors.green),
          LateralRaisePhase.falling => ('Lowering ↓', Colors.orange),
        };
        _phaseLabel = label;
        _phaseColor = color;
      } else if (_selectedExercise == ExerciseType.singleSquat &&
          _singleSquatCounter != null) {
        // Reset specific feedback for other exercises or extend later
        _currentFeedback = null;

        event = _singleSquatCounter!.processPose(poseFrame);
        final state = _singleSquatCounter!.state;
        _repCount = state.repCount;
        _currentAngle = state.smoothedAngle;

        // Map SingleSquatPhase to UI
        final (label, color) = switch (state.phase) {
          SingleSquatPhase.waiting => ('Ready...', Colors.grey),
          SingleSquatPhase.standing => ('Standing', Colors.blue),
          SingleSquatPhase.descending => ('Descending ↓', Colors.orange),
          SingleSquatPhase.bottom => ('Bottom!', Colors.green),
          SingleSquatPhase.ascending => ('Ascending ↑', Colors.orange),
        };
        _phaseLabel = label;
        _phaseColor = color;
      } else if (_selectedExercise == ExerciseType.benchPress &&
          _benchPressCounter != null) {
        event = _benchPressCounter!.processPose(poseFrame);
        final state = _benchPressCounter!.state;
        _repCount = state.repCount;
        _currentAngle = state.smoothedAngle;

        // Form Analysis
        if (_benchPressFormAnalyzer != null) {
          _currentFeedback = _benchPressFormAnalyzer!.analyzeFrame(
            poseFrame.landmarks,
          );

          if (_currentFeedback != null && _feedbackCooldownManager != null) {
            final filtered = _feedbackCooldownManager!.processFeedback(
              _currentFeedback!,
            );
            if (filtered != null) {
              _displayedFeedback = filtered;
              _voiceGuidanceService.speak(filtered);
              _feedbackClearTimer?.cancel();
              _feedbackClearTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _displayedFeedback = null;
                  });
                }
              });
            }
          }
        }

        final (label, color) = switch (state.phase) {
          BenchPressPhase.waiting => ('Ready...', Colors.grey),
          BenchPressPhase.up => (
            'Down ↓',
            Colors.blue,
          ), // Starting down from up
          BenchPressPhase.falling => ('Lowering...', Colors.orange),
          BenchPressPhase.down => ('Up ↑', Colors.green),
          BenchPressPhase.rising => ('Pressing...', Colors.orange),
        };
        _phaseLabel = label;
        _phaseColor = color;
      }
    });

    // Handle events
    if (event is RepCompleted) {
      // Provide haptic feedback on rep completion
      HapticFeedback.mediumImpact();
    }

    // TTS: speak start-position prompt when exercise is in waiting phase
    if (_phaseColor == Colors.grey && _selectedExercise != null) {
      _voiceGuidanceService.speakStartPrompt(
        _selectedExercise!.config.startPositionPrompt,
      );
    }
  }

  void _onExerciseSelected(ExerciseType? type) {
    setState(() {
      _selectedExercise = type;
      _lateralRaiseCounter = null;
      _lateralRaiseFormAnalyzer = null;
      _singleSquatCounter = null;
      _benchPressCounter = null;
      _benchPressFormAnalyzer = null;
      _repCount = 0;
      _currentFeedback = null;
      _displayedFeedback = null;
      _phaseLabel = 'Ready';
      _phaseColor = Colors.grey;
      _currentAngle = 0.0;

      // Reset and reconfigure feedback cooldown for new exercise
      _feedbackCooldownManager?.reset();
      _feedbackClearTimer?.cancel();
      _voiceGuidanceService.resetStartPromptCooldown();
      if (type != null) {
        _feedbackCooldownManager = FeedbackCooldownManager(
          perCodeCooldown: type.config.feedbackCooldown,
        );
      } else {
        _feedbackCooldownManager = null;
      }

      if (type == ExerciseType.lateralRaise) {
        _lateralRaiseCounter = LateralRaiseCounter(
          topThreshold: _topThreshold,
          bottomThreshold: _bottomThreshold,
        );
        _lateralRaiseFormAnalyzer = LateralRaiseFormAnalyzer(
          sensitivity: _currentSensitivity,
        );
      } else if (type == ExerciseType.singleSquat) {
        _singleSquatCounter = SingleSquatCounter(
          topThreshold: _squatTopThreshold,
          bottomThreshold: _squatBottomThreshold,
        );
      } else if (type == ExerciseType.benchPress) {
        _benchPressCounter = BenchPressCounter(
          topThreshold: _benchPressTopThreshold,
          bottomThreshold: _benchPressBottomThreshold,
        );
        _benchPressFormAnalyzer = BenchPressFormAnalyzer(
          sensitivity: _benchPressSensitivity,
        );
      }

      // Update virtual camera video if active
      if (_isVirtualCamera && type != null) {
        _virtualInputSource?.setExercise(type);
      }
    });

    // Show demo popup if this is the first time the user selects this exercise
    if (type != null) {
      unawaited(_showDemoIfFirstTime(type));
    }
  }

  /// Centralized demo playback — sets [_isDemoShowing] so pose processing
  /// is paused while the video is on screen.
  Future<void> _showExerciseDemo(
    ExerciseType type, {
    bool autoClose = false,
  }) async {
    if (!mounted) return;

    setState(() => _isDemoShowing = true);
    _voiceGuidanceService.stop(); // Silence any in-progress TTS immediately

    try {
      await showDialog(
        context: context,
        builder: (_) =>
            ExerciseDemoDialog(exerciseType: type, autoClose: autoClose),
      );
    } finally {
      if (mounted) {
        setState(() => _isDemoShowing = false);
      }
    }
  }

  Future<void> _showDemoIfFirstTime(ExerciseType type) async {
    final hasSeen = await _exerciseDemoService.hasSeenDemo(type);
    if (!hasSeen && mounted && _selectedExercise == type) {
      await _showExerciseDemo(type, autoClose: true);
      if (mounted) {
        await _exerciseDemoService.markDemoSeen(type);
      }
    }
  }

  Future<void> _showThresholdSettings() async {
    // Determine which thresholds to show based on selected exercise
    if (_selectedExercise == null) return;

    // Show settings dialog for all exercises (threshold sliders are
    // conditionally visible inside the dialog based on hasThresholds).

    double currentTop;
    double currentBottom;
    if (_selectedExercise == ExerciseType.lateralRaise) {
      currentTop = _topThreshold;
      currentBottom = _bottomThreshold;
    } else if (_selectedExercise == ExerciseType.singleSquat) {
      currentTop = _squatTopThreshold;
      currentBottom = _squatBottomThreshold;
    } else {
      currentTop = _benchPressTopThreshold;
      currentBottom = _benchPressBottomThreshold;
    }

    final exerciseType = _selectedExercise!;
    final result = await showDialog<ThresholdDialogResult>(
      context: context,
      builder: (context) => ThresholdSettingsDialog(
        initialTopThreshold: currentTop,
        initialBottomThreshold: currentBottom,
        exerciseType: exerciseType,
        initialSensitivity: exerciseType == ExerciseType.lateralRaise
            ? _currentSensitivity
            : null,
        onShowDemo: () => _showExerciseDemo(exerciseType),
      ),
    );

    if (result != null) {
      setState(() {
        final newTop = result.topThreshold;
        final newBottom = result.bottomThreshold;

        // Update appropriate thresholds and recreate counter
        if (_selectedExercise == ExerciseType.lateralRaise) {
          _topThreshold = newTop;
          _bottomThreshold = newBottom;
          _lateralRaiseCounter = LateralRaiseCounter(
            topThreshold: _topThreshold,
            bottomThreshold: _bottomThreshold,
          );

          // Apply sensitivity changes
          if (result.sensitivity != null) {
            _currentSensitivity = result.sensitivity!;
            _lateralRaiseFormAnalyzer?.updateSensitivity(_currentSensitivity);
          }
        } else if (_selectedExercise == ExerciseType.singleSquat) {
          _squatTopThreshold = newTop;
          _squatBottomThreshold = newBottom;
          _singleSquatCounter = SingleSquatCounter(
            topThreshold: _squatTopThreshold,
            bottomThreshold: _squatBottomThreshold,
          );
        } else if (_selectedExercise == ExerciseType.benchPress) {
          _benchPressTopThreshold = newTop;
          _benchPressBottomThreshold = newBottom;
          _benchPressCounter = BenchPressCounter(
            topThreshold: _benchPressTopThreshold,
            bottomThreshold: _benchPressBottomThreshold,
          );
        }

        // Reset state
        _repCount = 0;
        _phaseLabel = 'Ready';
        _phaseColor = Colors.grey;
        _currentAngle = 0.0;
      });
    }
  }

  void _resetCounter() {
    setState(() {
      _lateralRaiseCounter?.reset();
      _singleSquatCounter?.reset();
      _benchPressCounter?.reset();
      _feedbackCooldownManager?.reset();
      _feedbackClearTimer?.cancel();
      _repCount = 0;
      _displayedFeedback = null;
      _phaseLabel = 'Ready';
      _phaseColor = Colors.grey;
      _currentAngle = 0.0;
    });
  }

  InputImageRotation _getMobileImageRotation() {
    final sensorOrientation = _mobileInputSource?.sensorOrientation ?? 0;
    if (sensorOrientation == 0) return InputImageRotation.rotation0deg;

    // Store sensor orientation for skeleton painter
    _sensorOrientation = sensorOrientation;

    // On iOS, we force 0 degrees to rely on legacy manual rotation handling in Painter
    // This matches the behavior that was working correctly before the cross-platform unification
    if (Platform.isIOS) {
      return InputImageRotation.rotation0deg;
    }

    // On Android, calculate the rotation needed based on device orientation
    // The rotation tells ML Kit how to interpret the image coordinates.
    // Formula: rotation = (sensorOrientation - deviceRotation + 360) % 360
    // This accounts for the difference between sensor orientation and current device orientation.
    //
    // Special case: For portrait upside-down (180°), treat it like normal portrait (0°)
    // so that both preview and skeleton appear upside-down but aligned with each other.
    // This is acceptable since: 1) this orientation is rarely used, 2) the skeleton still
    // aligns with the person in the preview.
    final effectiveDeviceRotation = (_deviceRotation == 180)
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

  bool get _isFilePreviewMode =>
      _currentInputMode == _PoseInputMode.libraryVideo ||
      _currentInputMode == _PoseInputMode.simulatorFixtures;

  bool get _canShowInputSelector {
    if (_isMacOS) return false;
    return _availableInputModes.length > 1;
  }

  List<_PoseInputMode> get _availableInputModes {
    if (_isMacOS) return const [];

    final modes = <_PoseInputMode>[];
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

    if (hasFront) modes.add(_PoseInputMode.frontCamera);
    if (hasBack) modes.add(_PoseInputMode.backCamera);
    if (Platform.isIOS) {
      modes.add(_PoseInputMode.libraryVideo);
    }
    if (_isVirtualCamera ||
        (Platform.isIOS &&
            (mobileInputSource?.shouldUseVirtualFallback ?? false))) {
      modes.add(_PoseInputMode.simulatorFixtures);
    }
    return modes;
  }

  String get _filePreviewPoseLabel {
    return switch (_currentInputMode) {
      _PoseInputMode.libraryVideo => 'Video Pose',
      _PoseInputMode.simulatorFixtures => 'Virtual Pose',
      _ => 'Pose',
    };
  }

  String get _filePreviewBadgeLabel {
    return switch (_currentInputMode) {
      _PoseInputMode.libraryVideo => 'VIDEO REPLAY',
      _PoseInputMode.simulatorFixtures => 'SIMULATOR MODE',
      _ => '',
    };
  }

  /// Builds the settings action button next to the exercise selector.
  Widget _buildExerciseActionButton() {
    return IconButton(
      onPressed: _showThresholdSettings,
      icon: const Icon(Icons.settings, color: Colors.white),
      style: IconButton.styleFrom(backgroundColor: Colors.black87),
      tooltip: 'Settings',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('FitnessPipe'),
        backgroundColor: Colors.black87,
        actions: [
          if (_canShowInputSelector)
            PopupMenuButton<_PoseInputMode>(
              initialValue: _currentInputMode,
              icon: const Icon(Icons.cameraswitch),
              tooltip: 'Switch Input',
              onSelected: _handleInputModeSelection,
              itemBuilder: (context) => _availableInputModes
                  .map(
                    (mode) => PopupMenuItem<_PoseInputMode>(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(
                            _currentInputMode == mode
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(mode.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            icon: Icon(
              _currentPose != null ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {},
            tooltip: _currentPose != null ? 'Pose Detected' : 'No Pose',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFilePreviewMode) {
      return _buildFilePreview();
    } else if (_isMacOS) {
      return _buildMacOSCameraPreview();
    } else {
      return _buildMobileCameraPreview();
    }
  }

  Widget _buildFilePreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_currentPreviewFrameFile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Calculate aspect ratio from the image or use default
        final double aspectRatio = _cameraImageSize != null
            ? _cameraImageSize!.width / _cameraImageSize!.height
            : 16 / 9;

        return Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Virtual Camera Preview
                Image.file(
                  _currentPreviewFrameFile!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // Prevents flickering
                  excludeFromSemantics: true,
                ),

                // Skeleton overlay
                if (_currentPose != null)
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: CustomPaint(
                      painter: SkeletonPainter(
                        pose: _currentPose,
                        rotationDegrees: 0, // Virtual is always 0
                        imageSize: _cameraImageSize,
                        inputsAreRotated: false,
                        skeletonColor: Colors.greenAccent,
                        visibleLandmarks: _visibleLandmarks,
                        visibleBones: _visibleBones,
                        guide: _currentGuide,
                      ),
                    ),
                  ),

                // Exercise selector (top left)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Row(
                    children: [
                      ExerciseSelectorDropdown(
                        selectedExercise: _selectedExercise,
                        onChanged: _onExerciseSelected,
                      ),
                      if (_selectedExercise != null) ...[
                        const SizedBox(width: 8),
                        _buildExerciseActionButton(),
                      ],
                    ],
                  ),
                ),

                // Rep counter overlay
                if (_selectedExercise != null)
                  RepCounterOverlay(
                    isActive: _phaseColor != Colors.grey,
                    repCount: _repCount,
                    phaseLabel: _phaseLabel,
                    phaseColor: _phaseColor,
                    currentAngle: _currentAngle,
                    startPrompt:
                        _selectedExercise?.config.startPositionPrompt ?? '',
                  ),

                // Reset button
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _resetCounter,
                      backgroundColor: Colors.black87,
                      child: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ),

                // Pose confidence
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPose != null
                                ? Colors.greenAccent
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentPose != null
                              ? '$_filePreviewPoseLabel: ${(_currentPose!.confidence * 100).toStringAsFixed(0)}%'
                              : 'No pose detected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Form Feedback Overlay (throttled)
                if (_displayedFeedback != null)
                  FormFeedbackOverlay(
                    feedback: FormFeedback(
                      status: _displayedFeedback!.status,
                      issues: [_displayedFeedback!.issue],
                    ),
                  ),

                // Voice Guidance Toggle (simulator/virtual camera view)
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 80,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        setState(() {
                          _voiceGuidanceService.setEnabled(
                            !_voiceGuidanceService.isEnabled,
                          );
                        });
                      },
                      backgroundColor: Colors.black87,
                      child: Icon(
                        _voiceGuidanceService.isEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                        color: Colors.white,
                      ),
                    ),
                  ),

                if (_filePreviewBadgeLabel.isNotEmpty)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: _currentInputMode == _PoseInputMode.libraryVideo
                          ? Colors.blueAccent
                          : Colors.redAccent,
                      child: Text(
                        _filePreviewBadgeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacOSCameraPreview() {
    if (_macOSCameras == null || _macOSCameras!.isEmpty) {
      return const Center(
        child: Text(
          'No macOS cameras available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final selectedCamera = _macOSCameras![_selectedMacOSCameraIndex];

    return Stack(
      children: [
        // Camera preview
        Center(
          child: CameraMacOSView(
            key: _macOSCameraKey,
            deviceId: selectedCamera.deviceId,
            fit: BoxFit.contain,
            cameraMode: CameraMacOSMode.video,
            onCameraInizialized: _onMacOSCameraInitialized,
            onCameraDestroyed: () {
              _macOSCameraController = null;
              return const SizedBox.shrink();
            },
          ),
        ),

        // Info banner for macOS
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Camera: ${selectedCamera.localizedName ?? selectedCamera.deviceId}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Pose detection requires iOS/Android device. '
                  'macOS shows camera preview only.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCameraPreview() {
    final controller = _mobileInputSource?.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final previewSize = controller.value.previewSize!;

    // Camera sensor outputs dimensions (may be landscape: w > h)
    // Calculate the portrait aspect ratio (< 1) for portrait mode
    final double portraitAspectRatio = (previewSize.height < previewSize.width)
        ? previewSize.height / previewSize.width
        : previewSize.width / previewSize.height;

    // Landscape aspect ratio is the inverse (> 1)
    final double landscapeAspectRatio = 1 / portraitAspectRatio;

    // Platform-specific orientation handling:
    // - iOS: Use simple LayoutBuilder (existing working logic)
    // - Android: Use NativeDeviceOrientationReader for precise landscape-left vs landscape-right detection

    if (Platform.isIOS) {
      // iOS: Use LayoutBuilder with existing rotation logic (already working)
      return LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final double aspectRatio = isLandscape
              ? landscapeAspectRatio
              : portraitAspectRatio;

          return Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera preview
                  mobile_camera.CameraPreview(controller),

                  // Skeleton overlay
                  if (_currentPose != null)
                    AspectRatio(
                      aspectRatio: aspectRatio,
                      child: CustomPaint(
                        painter: SkeletonPainter(
                          pose: _currentPose,
                          rotationDegrees: _sensorOrientation,
                          imageSize: null, // iOS uses legacy stretch-to-fill
                          inputsAreRotated: false,
                          skeletonColor: Colors.greenAccent,
                          visibleLandmarks: _visibleLandmarks,
                          visibleBones: _visibleBones,
                          guide: _currentGuide,
                        ),
                      ),
                    ),

                  // Exercise selector (top left)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Row(
                      children: [
                        ExerciseSelectorDropdown(
                          selectedExercise: _selectedExercise,
                          onChanged: _onExerciseSelected,
                        ),
                        if (_selectedExercise != null) ...[
                          const SizedBox(width: 8),
                          _buildExerciseActionButton(),
                        ],
                      ],
                    ),
                  ),

                  // Rep counter overlay (when exercise selected)
                  if (_selectedExercise != null)
                    RepCounterOverlay(
                      isActive: _phaseColor != Colors.grey,
                      repCount: _repCount,
                      phaseLabel: _phaseLabel,
                      phaseColor: _phaseColor,
                      currentAngle: _currentAngle,
                      startPrompt:
                          _selectedExercise?.config.startPositionPrompt ?? '',
                    ),

                  // Form Feedback Overlay (throttled)
                  if (_displayedFeedback != null)
                    FormFeedbackOverlay(
                      feedback: FormFeedback(
                        status: _displayedFeedback!.status,
                        issues: [_displayedFeedback!.issue],
                      ),
                    ),

                  // Voice Guidance Toggle
                  if (_selectedExercise != null)
                    Positioned(
                      bottom: 16,
                      right: 80,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          setState(() {
                            _voiceGuidanceService.setEnabled(
                              !_voiceGuidanceService.isEnabled,
                            );
                          });
                        },
                        backgroundColor: Colors.black87,
                        child: Icon(
                          _voiceGuidanceService.isEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Reset button (bottom right)
                  if (_selectedExercise != null)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _resetCounter,
                        backgroundColor: Colors.black87,
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ),

                  // Pose confidence indicator
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPose != null
                                  ? Colors.greenAccent
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentPose != null
                                ? 'Pose: ${(_currentPose!.confidence * 100).toStringAsFixed(0)}%'
                                : 'No pose detected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Instruction Overlay
                ],
              ),
            ),
          );
        },
      );
    }

    // Android: Use NativeDeviceOrientationReader for precise device orientation
    // This is essential for correctly handling landscape-left vs landscape-right
    return NativeDeviceOrientationReader(
      useSensor: true,
      builder: (context) {
        final nativeOrientation = NativeDeviceOrientationReader.orientation(
          context,
        );

        // Convert native orientation to rotation degrees
        int newDeviceRotation;
        bool isLandscape;
        switch (nativeOrientation) {
          case NativeDeviceOrientation.portraitUp:
            newDeviceRotation = 0;
            isLandscape = false;
            break;
          case NativeDeviceOrientation.landscapeLeft:
            newDeviceRotation = 90;
            isLandscape = true;
            break;
          case NativeDeviceOrientation.portraitDown:
            newDeviceRotation = 180;
            isLandscape = false;
            break;
          case NativeDeviceOrientation.landscapeRight:
            newDeviceRotation = 270;
            isLandscape = true;
            break;
          default:
            newDeviceRotation = 0;
            isLandscape = false;
        }

        final double aspectRatio = isLandscape
            ? landscapeAspectRatio
            : portraitAspectRatio;

        // Update device rotation state for image processing
        // Use addPostFrameCallback to avoid setState during build
        if (_deviceRotation != newDeviceRotation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _deviceRotation = newDeviceRotation;
              });
            }
          });
        }
        // On Android, the camera preview appears upside-down for landscape-right (270°)
        // because the Android camera plugin doesn't handle this orientation correctly.
        // We apply a 180° rotation to compensate.
        final needsRotation = newDeviceRotation == 270;

        Widget previewWidget = Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Camera preview - wrapped in Builder to catch any disposal errors during rebuild
                Builder(
                  builder: (context) {
                    try {
                      final activeController = _mobileInputSource?.controller;
                      if (activeController == null ||
                          !activeController.value.isInitialized) {
                        return const SizedBox.shrink();
                      }
                      return mobile_camera.CameraPreview(activeController);
                    } catch (e) {
                      // Camera might be disposed during orientation change
                      return const SizedBox.shrink();
                    }
                  },
                ),

                // Skeleton overlay
                if (_currentPose != null)
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: CustomPaint(
                      painter: SkeletonPainter(
                        pose: _currentPose,
                        // Treat 180° (portrait upside-down) as 0° so skeleton aligns with preview
                        rotationDegrees:
                            (_sensorOrientation -
                                (newDeviceRotation == 180
                                    ? 0
                                    : newDeviceRotation) +
                                360) %
                            360,
                        imageSize: _cameraImageSize,
                        inputsAreRotated:
                            _getMobileImageRotation() !=
                            InputImageRotation.rotation0deg,
                        skeletonColor: Colors.greenAccent,
                        visibleLandmarks: _visibleLandmarks,
                        visibleBones: _visibleBones,
                        guide: _currentGuide,
                      ),
                    ),
                  ),

                // Exercise selector (top left)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Row(
                    children: [
                      ExerciseSelectorDropdown(
                        selectedExercise: _selectedExercise,
                        onChanged: _onExerciseSelected,
                      ),
                      if (_selectedExercise != null) ...[
                        const SizedBox(width: 8),
                        _buildExerciseActionButton(),
                      ],
                    ],
                  ),
                ),

                // Rep counter overlay (when exercise selected)
                if (_selectedExercise != null)
                  RepCounterOverlay(
                    isActive: _phaseColor != Colors.grey,
                    repCount: _repCount,
                    phaseLabel: _phaseLabel,
                    phaseColor: _phaseColor,
                    currentAngle: _currentAngle,
                    startPrompt:
                        _selectedExercise?.config.startPositionPrompt ?? '',
                  ),

                // Form Feedback Overlay (throttled) — Android view
                if (_displayedFeedback != null)
                  FormFeedbackOverlay(
                    feedback: FormFeedback(
                      status: _displayedFeedback!.status,
                      issues: [_displayedFeedback!.issue],
                    ),
                  ),

                // Reset button (bottom right)
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _resetCounter,
                      backgroundColor: Colors.black87,
                      child: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ),

                // Voice Guidance Toggle
                if (_selectedExercise != null)
                  Positioned(
                    bottom: 16,
                    right: 80,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        setState(() {
                          _voiceGuidanceService.setEnabled(
                            !_voiceGuidanceService.isEnabled,
                          );
                        });
                      },
                      backgroundColor: Colors.black87,
                      child: Icon(
                        _voiceGuidanceService.isEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Pose confidence indicator
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPose != null
                                ? Colors.greenAccent
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentPose != null
                              ? 'Pose: ${(_currentPose!.confidence * 100).toStringAsFixed(0)}%'
                              : 'No pose detected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        // Apply 180° rotation for landscape-right on Android
        if (needsRotation) {
          return Transform.rotate(
            angle: 3.14159265359, // pi radians = 180 degrees
            child: previewWidget,
          );
        }
        return previewWidget;
      },
    );
  }
}
