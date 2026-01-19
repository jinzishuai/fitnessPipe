import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../../presentation/widgets/exercise_selector.dart';

/// Service that mimics a camera by streaming images from assets.
class VirtualCameraService {
  Timer? _timer;
  bool _isStreaming = false;
  int _currentFrameIndex = 0;

  // Configuration
  // Configuration
  static const Map<ExerciseType, Map<String, dynamic>> _exerciseConfig = {
    ExerciseType.lateralRaise: {
      'prefix': 'assets/fixtures/lateral_raise/frame_',
      'count': 52,
      'fps': 24,
      'width': 1280.0,
      'height': 720.0,
    },
    ExerciseType.singleSquat: {
      'prefix': 'assets/fixtures/single_squat/frame_',
      'count': 68,
      'fps': 30, // Assuming 30fps for squat video
      'width': 1920.0,
      'height': 1080.0,
    },
  };

  ExerciseType _currentExercise;

  int _startDelayFrames = 0; // Number of frames to hold at start

  VirtualCameraService({
    ExerciseType initialExercise = ExerciseType.lateralRaise,
  }) : _currentExercise = initialExercise;

  Size get currentImageSize {
    final config = _exerciseConfig[_currentExercise]!;
    return Size(config['width'] as double, config['height'] as double);
  }

  void setExercise(ExerciseType type) {
    if (_currentExercise == type) return;
    _currentExercise = type;
    _currentFrameIndex = 0; // Reset loop
    _startDelayFrames =
        60; // Hold start frame for ~2 seconds (33ms * 60 = 1980ms)
  }

  /// Start streaming images.
  ///
  /// [onImage] callback is called with each new frame.
  Future<void> startStream(Function(InputImage) onImage) async {
    if (_isStreaming) return;
    _isStreaming = true;
    _currentFrameIndex = 0;
    _startDelayFrames = 60; // Hold start frame on initial launch too

    // Simulate camera FPS (throttled to 24-30fps)
    // We can dynamically adjust this if needed, but 30ms (~33fps) is safe for both
    const interval = Duration(milliseconds: 33);

    _timer = Timer.periodic(interval, (timer) async {
      if (!_isStreaming) {
        timer.cancel();
        return;
      }

      try {
        final config = _exerciseConfig[_currentExercise]!;
        final prefix = config['prefix'] as String;
        final count = config['count'] as int;

        final inputImage = await _loadFrame(_currentFrameIndex, prefix);
        if (inputImage != null) {
          onImage(inputImage);
        }

        // Hold frame 0 if we are in the start delay phase
        if (_startDelayFrames > 0) {
          _startDelayFrames--;
          _currentFrameIndex = 0;
        } else {
          _currentFrameIndex = (_currentFrameIndex + 1) % count;
        }
      } catch (e) {
        debugPrint('Virtual Camera Error: $e');
      }
    });
  }

  /// Stop the stream.
  Future<void> stopStream() async {
    _isStreaming = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await stopStream();
  }

  Future<InputImage?> _loadFrame(int index, String prefix) async {
    final assetPath = '$prefix$index.jpg';
    try {
      // Check cache first
      if (_tempFileCache.containsKey(assetPath)) {
        return InputImage.fromFilePath(_tempFileCache[assetPath]!);
      }

      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      // Sanitize path for filename
      final fileName = assetPath.replaceAll('/', '_');
      final tempFile = File('${tempDir.path}/$fileName');

      if (!await tempFile.exists()) {
        await tempFile.writeAsBytes(bytes);
      }

      _tempFileCache[assetPath] = tempFile.path;
      return InputImage.fromFilePath(tempFile.path);
    } catch (e) {
      debugPrint('Error loading virtual frame $assetPath: $e');
      return null;
    }
  }

  // Cache for temp files
  final Map<String, String> _tempFileCache = {};
}
