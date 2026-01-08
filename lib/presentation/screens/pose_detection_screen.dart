import 'dart:io';

import 'package:camera/camera.dart' as mobile_camera;
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';

import '../../data/ml_kit/ml_kit_pose_detector.dart';
import '../../domain/interfaces/pose_detector.dart';
import '../../domain/models/pose.dart';
import '../widgets/skeleton_painter.dart';

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

  // UI state
  bool _isLoading = true;
  String? _errorMessage;

  // Platform-specific camera handling
  final bool _isMacOS = Platform.isMacOS;

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
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mobileCameraController?.dispose();
    _macOSCameraController?.destroy();
    _poseDetector.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _mobileCameraController?.dispose();
      _macOSCameraController?.destroy();
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

  void _processMobileCameraImage(mobile_camera.CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final rotation = _getMobileImageRotation();
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final poses = await _poseDetector.detectPoses(image, imageSize, rotation);

      if (mounted) {
        setState(() {
          _currentPose = poses.isNotEmpty ? poses.first : null;
        });
      }
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImageRotation _getMobileImageRotation() {
    if (_mobileCameraController == null) return InputImageRotation.rotation0deg;

    final camera = _mobileCameras[_selectedMobileCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotation.rotation0deg;
    }

    switch (sensorOrientation) {
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

  bool get _isFrontCamera {
    if (_isMacOS) {
      // macOS cameras are typically front-facing
      return true;
    }
    if (_mobileCameras.isEmpty) return false;
    return _mobileCameras[_selectedMobileCameraIndex].lensDirection ==
        mobile_camera.CameraLensDirection.front;
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

    if (_isMacOS) {
      return _buildMacOSCameraPreview();
    } else {
      return _buildMobileCameraPreview();
    }
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
    final aspectRatio = previewSize.height / previewSize.width;

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            mobile_camera.CameraPreview(_mobileCameraController!),

            // Skeleton overlay
            if (_currentPose != null)
              CustomPaint(
                painter: SkeletonPainter(
                  pose: _currentPose,
                  imageSize: Size(previewSize.height, previewSize.width),
                  isFrontCamera: _isFrontCamera,
                  skeletonColor: Colors.greenAccent,
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
  }
}
