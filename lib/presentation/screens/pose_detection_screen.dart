import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart' as mobile_camera;
import 'package:camera_macos/camera_macos.dart';
import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import '../../core/adapters/pose_adapter.dart';
import '../../core/utils/camera_utils.dart';
import '../../data/ml_kit/ml_kit_pose_detector.dart';
import '../../data/services/virtual_camera_service.dart';
import '../../domain/interfaces/pose_detector.dart';
import '../../domain/models/pose.dart';
import '../widgets/exercise_selector.dart';
import '../widgets/rep_counter_overlay.dart';
import '../widgets/skeleton_painter.dart';
import '../widgets/threshold_settings_dialog.dart';

/// Main screen for pose detection with camera preview and skeleton overlay.
class PoseDetectionScreen extends StatefulWidget {
  const PoseDetectionScreen({super.key});

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen>
    with WidgetsBindingObserver {
  // Pose detection
  late final PoseDetector _poseDetector;
  Pose? _currentPose;
  bool _isDetecting = false;

  // Exercise counter
  final _poseAdapter = PoseAdapter();
  ExerciseType? _selectedExercise = ExerciseType.lateralRaise;
  LateralRaiseCounter? _lateralRaiseCounter;
  SingleSquatCounter? _singleSquatCounter;
  int _repCount = 0;
  String _phaseLabel = 'Ready';
  Color _phaseColor = Colors.grey;
  double _currentAngle = 0.0;

  // Threshold configuration
  double _topThreshold = 50.0;
  double _bottomThreshold = 25.0;
  // Squat thresholds (defaults)
  double _squatTopThreshold = 170.0;
  double _squatBottomThreshold = 160.0;

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
  VirtualCameraService? _virtualCameraService;

  // Mobile camera (iOS/Android)
  List<mobile_camera.CameraDescription> _mobileCameras = [];
  mobile_camera.CameraController? _mobileCameraController;
  int _selectedMobileCameraIndex = 0;

  // macOS camera
  CameraMacOSController? _macOSCameraController;
  List<CameraMacOSDevice>? _macOSCameras;
  int _selectedMacOSCameraIndex = 0;
  GlobalKey? _macOSCameraKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poseDetector = MLKitPoseDetector();

    // Initialize default counter
    _lateralRaiseCounter = LateralRaiseCounter(
      topThreshold: _topThreshold,
      bottomThreshold: _bottomThreshold,
      readyHoldTime: const Duration(milliseconds: 300),
    );

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mobileCameraController?.dispose();
    _macOSCameraController?.destroy();
    _virtualCameraService?.dispose();
    _poseDetector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _mobileCameraController?.dispose();
      _macOSCameraController?.destroy();
      _virtualCameraService?.stopStream();
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
    _mobileCameras = await mobile_camera.availableCameras();

    // If no cameras found on iOS, assume Simulator and try Virtual Camera
    // Note: checking if cameras is empty is a decent heuristic for Simulator on some versions,
    // but explicit platform check is better.
    if (_mobileCameras.isEmpty && Platform.isIOS) {
      await _initializeVirtualCamera();
      return;
    }

    if (_mobileCameras.isEmpty) {
      setState(() {
        _errorMessage = 'No cameras available';
        _isLoading = false;
      });
      return;
    }

    // Prefer front camera
    _selectedMobileCameraIndex = _mobileCameras.indexWhere(
      (camera) =>
          camera.lensDirection == mobile_camera.CameraLensDirection.front,
    );
    if (_selectedMobileCameraIndex < 0) _selectedMobileCameraIndex = 0;

    await _startMobileCamera(_mobileCameras[_selectedMobileCameraIndex]);
  }

  Future<void> _initializeVirtualCamera() async {
    _virtualCameraService = VirtualCameraService();
    setState(() {
      _isVirtualCamera = true;
    });

    // Start streaming
    await _virtualCameraService!.startStream(_processVirtualCameraImage);

    // Initial loading done
    setState(() {
      _isLoading = false;
    });
  }

  Size? _virtualCameraImageSize;
  File? _currentVirtualFrameFile;

  void _processVirtualCameraImage(InputImage inputImage) async {
    // Update the UI preview
    if (inputImage.filePath != null) {
      if (mounted) {
        setState(() {
          _currentVirtualFrameFile = File(inputImage.filePath!);
        });
      }

      // Calculate size once if missing
      if (_virtualCameraImageSize == null) {
        try {
          final file = File(inputImage.filePath!);
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frameInfo = await codec.getNextFrame();
          _virtualCameraImageSize = Size(
            frameInfo.image.width.toDouble(),
            frameInfo.image.height.toDouble(),
          );
        } catch (e) {
          // Ignore error, will rely on fallback
        }
      }
    }

    _processPoseDetection(inputImage);
  }

  Future<void> _startMobileCamera(
    mobile_camera.CameraDescription camera,
  ) async {
    await _mobileCameraController?.dispose();

    _mobileCameraController = mobile_camera.CameraController(
      camera,
      mobile_camera.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? mobile_camera.ImageFormatGroup.nv21
          : mobile_camera.ImageFormatGroup.bgra8888,
    );

    try {
      await _mobileCameraController!.initialize();
      await _mobileCameraController!.startImageStream(
        _processMobileCameraImage,
      );

      setState(() {
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

  Future<void> _switchCamera() async {
    if (_isMacOS) {
      if (_macOSCameras == null || _macOSCameras!.length < 2) return;
      _selectedMacOSCameraIndex =
          (_selectedMacOSCameraIndex + 1) % _macOSCameras!.length;
      _macOSCameraKey = GlobalKey(); // Force rebuild
      setState(() {});
    } else {
      if (_mobileCameras.length < 2) return;
      _selectedMobileCameraIndex =
          (_selectedMobileCameraIndex + 1) % _mobileCameras.length;
      await _mobileCameraController?.stopImageStream();
      await _startMobileCamera(_mobileCameras[_selectedMobileCameraIndex]);
    }
  }

  void _processMobileCameraImage(mobile_camera.CameraImage image) {
    final rotation = _getMobileImageRotation();
    final inputImage = CameraUtils.convertCameraImage(image, rotation);
    if (inputImage != null) {
      _processPoseDetection(inputImage);
    }
  }

  void _processPoseDetection(InputImage inputImage) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final poses = await _poseDetector.detectPoses(inputImage);

      if (mounted) {
        setState(() {
          if (inputImage.metadata?.size != null) {
            _cameraImageSize = inputImage.metadata!.size;
          } else if (_virtualCameraImageSize != null) {
            _cameraImageSize = _virtualCameraImageSize;
          } else if (_isVirtualCamera) {
            // Fallback for virtual camera if calc fails
            _cameraImageSize = const Size(720, 1280);
          } else {
            _cameraImageSize = const Size(1, 1);
          }

          _currentPose = poses.isNotEmpty ? poses.first : null;

          debugPrint(
            'Pose detected: cameraImageSize=$_cameraImageSize, sensorOrientation=$_sensorOrientation, poseLandmarks=${_currentPose?.landmarks.length ?? 0}',
          );

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
      }
    });

    // Handle events
    if (event is RepCompleted) {
      // Provide haptic feedback on rep completion
      HapticFeedback.mediumImpact();
    }
  }

  void _onExerciseSelected(ExerciseType? type) {
    setState(() {
      _selectedExercise = type;
      _lateralRaiseCounter = null;
      _singleSquatCounter = null;
      _repCount = 0;
      _phaseLabel = 'Ready';
      _phaseColor = Colors.grey;
      _currentAngle = 0.0;

      if (type == ExerciseType.lateralRaise) {
        _lateralRaiseCounter = LateralRaiseCounter(
          topThreshold: _topThreshold,
          bottomThreshold: _bottomThreshold,
          readyHoldTime: const Duration(milliseconds: 300),
        );
      } else if (type == ExerciseType.singleSquat) {
        _singleSquatCounter = SingleSquatCounter(
          topThreshold: _squatTopThreshold,
          bottomThreshold: _squatBottomThreshold,
        );
      }

      // Update virtual camera video if active
      if (_isVirtualCamera && type != null) {
        _virtualCameraService?.setExercise(type);
        _virtualCameraImageSize =
            null; // Force recalculation of image size for new video
        _currentPose = null; // Clear old pose to prevent flashing during switch
      }
    });
  }

  Future<void> _showThresholdSettings() async {
    // Determine which thresholds to show based on selected exercise
    if (_selectedExercise == null) return;

    double currentTop;
    double currentBottom;
    if (_selectedExercise == ExerciseType.lateralRaise) {
      currentTop = _topThreshold;
      currentBottom = _bottomThreshold;
    } else {
      currentTop = _squatTopThreshold;
      currentBottom = _squatBottomThreshold;
    }

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => ThresholdSettingsDialog(
        initialTopThreshold: currentTop,
        initialBottomThreshold: currentBottom,
      ),
    );

    if (result != null) {
      setState(() {
        final newTop = result['top']!;
        final newBottom = result['bottom']!;

        // Update appropriate thresholds and recreate counter
        if (_selectedExercise == ExerciseType.lateralRaise) {
          _topThreshold = newTop;
          _bottomThreshold = newBottom;
          _lateralRaiseCounter = LateralRaiseCounter(
            topThreshold: _topThreshold,
            bottomThreshold: _bottomThreshold,
            readyHoldTime: const Duration(milliseconds: 300),
          );
        } else if (_selectedExercise == ExerciseType.singleSquat) {
          _squatTopThreshold = newTop;
          _squatBottomThreshold = newBottom;
          _singleSquatCounter = SingleSquatCounter(
            topThreshold: _squatTopThreshold,
            bottomThreshold: _squatBottomThreshold,
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
      _repCount = 0;
      _phaseLabel = 'Ready';
      _phaseColor = Colors.grey;
      _currentAngle = 0.0;
    });
  }

  InputImageRotation _getMobileImageRotation() {
    if (_mobileCameraController == null) return InputImageRotation.rotation0deg;

    final camera = _mobileCameras[_selectedMobileCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

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

  int get _cameraCount {
    if (_isMacOS) {
      return _macOSCameras?.length ?? 0;
    }
    return _mobileCameras.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('FitnessPipe'),
        backgroundColor: Colors.black87,
        actions: [
          if (_cameraCount > 1)
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: _switchCamera,
              tooltip: 'Switch Camera',
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

    if (_isVirtualCamera) {
      return _buildVirtualCameraPreview();
    } else if (_isMacOS) {
      return _buildMacOSCameraPreview();
    } else {
      return _buildMobileCameraPreview();
    }
  }

  Widget _buildVirtualCameraPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_currentVirtualFrameFile == null) {
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
                  _currentVirtualFrameFile!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // Prevents flickering
                ),

                // Skeleton overlay
                if (_currentPose != null)
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: CustomPaint(
                      painter: SkeletonPainter(
                        pose: _currentPose,
                        rotationDegrees: 0, // Virtual is always 0
                        imageSize:
                            null, // Use stretch-to-fill like real iOS for consistency
                        inputsAreRotated: false,
                        skeletonColor: Colors.greenAccent,
                      ),
                    ),
                  ),

                // Overlay Widgets (Reuse specific widgets or duplicate structure?)
                // Let's copy the structure from Mobile for consistency.

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
                      if (_selectedExercise == ExerciseType.lateralRaise) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showThresholdSettings,
                          icon: const Icon(Icons.settings, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black87,
                          ),
                          tooltip: 'Adjust Thresholds',
                        ),
                      ],
                    ],
                  ),
                ),

                // Rep counter overlay
                if (_selectedExercise != null)
                  RepCounterOverlay(
                    repCount: _repCount,
                    phaseLabel: _phaseLabel,
                    phaseColor: _phaseColor,
                    currentAngle: _currentAngle,
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
                              ? 'Virtual Pose: ${(_currentPose!.confidence * 100).toStringAsFixed(0)}%'
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

                // Simulator Badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.redAccent,
                    child: const Text(
                      'SIMULATOR MODE',
                      style: TextStyle(
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
    if (_mobileCameraController == null ||
        !_mobileCameraController!.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final previewSize = _mobileCameraController!.value.previewSize!;

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
                  mobile_camera.CameraPreview(_mobileCameraController!),

                  // Skeleton overlay
                  if (_currentPose != null)
                    AspectRatio(
                      aspectRatio: aspectRatio,
                      child: CustomPaint(
                        painter: SkeletonPainter(
                          pose: _currentPose,
                          rotationDegrees: 0, // Virtual is always 0
                          imageSize:
                              _cameraImageSize, // Use actual image size for proper scaling
                          inputsAreRotated: false,
                          skeletonColor: Colors.greenAccent,
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
                        if (_selectedExercise == ExerciseType.lateralRaise) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _showThresholdSettings,
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black87,
                            ),
                            tooltip: 'Adjust Thresholds',
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Rep counter overlay (when exercise selected)
                  if (_selectedExercise != null)
                    RepCounterOverlay(
                      repCount: _repCount,
                      phaseLabel: _phaseLabel,
                      phaseColor: _phaseColor,
                      currentAngle: _currentAngle,
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
                      if (_mobileCameraController == null ||
                          !_mobileCameraController!.value.isInitialized) {
                        return const SizedBox.shrink();
                      }
                      return mobile_camera.CameraPreview(
                        _mobileCameraController!,
                      );
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
                      if (_selectedExercise == ExerciseType.lateralRaise) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showThresholdSettings,
                          icon: const Icon(Icons.settings, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black87,
                          ),
                          tooltip: 'Adjust Thresholds',
                        ),
                      ],
                    ],
                  ),
                ),

                // Rep counter overlay (when exercise selected)
                if (_selectedExercise != null)
                  RepCounterOverlay(
                    repCount: _repCount,
                    phaseLabel: _phaseLabel,
                    phaseColor: _phaseColor,
                    currentAngle: _currentAngle,
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
