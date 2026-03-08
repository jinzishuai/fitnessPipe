import 'package:camera/camera.dart' as mobile_camera;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../../core/utils/camera_utils.dart';
import 'pose_input_source.dart';

/// Wraps the mobile camera plugin behind the shared input source contract.
class MobileCameraInputSource implements PoseInputSource {
  MobileCameraInputSource({
    required InputImageRotation Function() rotationProvider,
  }) : _rotationProvider = rotationProvider;

  final InputImageRotation Function() _rotationProvider;

  List<mobile_camera.CameraDescription> _cameras = [];
  mobile_camera.CameraController? _controller;
  int _selectedCameraIndex = 0;

  mobile_camera.CameraController? get controller => _controller;

  int get sensorOrientation {
    if (_cameras.isEmpty) return 0;
    return _cameras[_selectedCameraIndex].sensorOrientation;
  }

  @override
  int get sourceCount => _cameras.length;

  @override
  bool get usesFilePreview => false;

  Future<void> initialize() async {
    _cameras = await mobile_camera.availableCameras();
    if (_cameras.isEmpty) return;
    if (_selectedCameraIndex >= _cameras.length) {
      _selectedCameraIndex = _preferredFrontCameraIndex();
    }
  }

  bool get hasCameras => _cameras.isNotEmpty;

  bool get shouldUseVirtualFallback => _cameras.isEmpty;

  void selectPreferredCamera() {
    if (_cameras.isEmpty) return;
    _selectedCameraIndex = _preferredFrontCameraIndex();
  }

  @override
  Future<void> start(PoseInputFrameCallback onFrame) async {
    if (_cameras.isEmpty) {
      await initialize();
    }

    if (_cameras.isEmpty) {
      throw const _NoCamerasException();
    }

    await _startSelectedCamera(onFrame);
  }

  int _preferredFrontCameraIndex() {
    final index = _cameras.indexWhere(
      (camera) =>
          camera.lensDirection == mobile_camera.CameraLensDirection.front,
    );
    return index >= 0 ? index : 0;
  }

  Future<void> _startSelectedCamera(PoseInputFrameCallback onFrame) async {
    await _controller?.dispose();

    final camera = _cameras[_selectedCameraIndex];
    _controller = mobile_camera.CameraController(
      camera,
      mobile_camera.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? mobile_camera.ImageFormatGroup.nv21
          : mobile_camera.ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    await _controller!.startImageStream((image) {
      final inputImage = CameraUtils.convertCameraImage(
        image,
        _rotationProvider(),
      );
      if (inputImage != null) {
        onFrame(PoseInputFrame(inputImage: inputImage));
      }
    });
  }

  @override
  Future<void> switchSource() async {
    if (_cameras.length < 2) return;
    await _controller?.stopImageStream();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
  }

  @override
  Future<void> stop() async {
    await _controller?.stopImageStream();
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

class _NoCamerasException implements Exception {
  const _NoCamerasException();

  @override
  String toString() => 'No cameras available';
}
