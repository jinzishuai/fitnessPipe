// Generated from pose_detection_screen.dart refactoring
// Issue #71: Split large file into focused modules
// This is the controller class with business logic and state management

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' as mobile_camera;
import 'package:camera_macos/camera_macos.dart';
import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/adapters/pose_adapter.dart';
import '../../domain/interfaces/pose_detector.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/pose.dart';
import '../../domain/models/pose_landmark.dart';
import '../widgets/form_feedback_overlay.dart';
import '../widgets/lateral_raise_guide.dart';
import '../widgets/rep_counter_overlay.dart';
import '../widgets/skeleton_painter.dart';
import '../widgets/threshold_settings_dialog.dart';
import '../widgets/exercise_selector.dart';
import '../../data/services/library_video_input_source.dart';
import '../../data/services/mobile_camera_input_source.dart';
import '../../data/services/virtual_camera_input_source.dart';
import '../../data/services/exercise_demo_service.dart';
import '../../data/services/voice_guidance_service.dart';
import '../../presentation/widgets/chosen_exercise_tile.dart';
import '../../domain/interfaces/form_analyzer.dart';
import '../../presentation/widgets/guides/exercise_guide.dart';

/// Controller for pose detection functionality
/// Handles camera initialization, pose detection, and exercise counting
class PoseDetectionController {
  // Pose detection
  late final PoseDetector _poseDetector;
  Pose? _currentPose;
  bool _isDetecting = false;

  // Exercise counter
  late final PoseAdapter _poseAdapter;
  ExerciseType? _selectedExercise;
  LateralRaiseCounter? _lateralRaiseCounter;
  LateralRaiseFormAnalyzer? _lateralRaiseFormAnalyzer;
  SingleSquatCounter? _singleSquatCounter;
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

  // UI state
  bool _isLoading = true;
  String? _errorMessage;
  Size? _cameraImageSize;
  int _sensorOrientation = 0;
  int _deviceRotation = 0;

  // Platform-specific camera handling
  final bool _isMacOS = Platform.isMacOS;
  bool _isVirtualCamera = false;
  MobileCameraInputSource? _mobileInputSource;
  VirtualCameraInputSource? _virtualInputSource;
  LibraryVideoInputSource? _libraryVideoInputSource;
  _PoseInputMode? _currentInputMode;
  bool _isPickingLibraryVideo = false;

  PoseDetectionController()
      : _poseDetector = MLKitPoseDetector(),
        _poseAdapter = PoseAdapter(),
        _voiceGuidanceService = VoiceGuidanceService() {
    _isVirtualCamera = false;
  }

  void dispose() {
    _mobileInputSource?.dispose();
    _virtualInputSource?.dispose();
    _libraryVideoInputSource?.dispose();
    _voiceGuidanceService.dispose();
    _feedbackClearTimer?.cancel();
    _poseDetector.dispose();
    _feedbackClearTimer?.cancel();
  }
}

enum _PoseInputMode {
  frontCamera('Front Camera'),
  backCamera('Back Camera'),
  libraryVideo('Library Video'),
  simulatorFixtures('Simulator Fixtures');

  const _PoseInputMode(this.label);

  final String label;
}
