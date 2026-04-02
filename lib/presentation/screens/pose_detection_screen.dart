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

import 'pose_detection_input_mode.dart';

import '../../core/adapters/pose_adapter.dart';
import '../../data/services/library_video_input_source.dart';
import '../../data/ml_kit/ml_kit_pose_detector.dart';
import '../../data/services/exercise_demo_service.dart';
import '../../data/services/mobile_camera_input_source.dart';
import '../../data/services/pose_input_source.dart';
import '../../data/services/virtual_camera_input_source.dart';
import '../../data/services/voice_guidance_service.dart';
import '../../domain/interfaces/pose_detector.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/pose.dart';
import '../../domain/models/pose_landmark.dart';
import '../widgets/exercise_selector.dart';
import '../widgets/form_feedback_overlay.dart';
import '../widgets/guides/exercise_guide.dart';
import '../widgets/guides/lateral_raise_guide.dart';
import '../widgets/guides/bench_press_guide.dart';
import '../widgets/guides/single_squat_guide.dart';

import '../widgets/rep_counter_overlay.dart';
import '../widgets/skeleton_painter.dart';
import '../widgets/threshold_settings_dialog.dart';
import '../widgets/exercise_demo_dialog.dart';

part 'pose_detection_controller.dart';
part 'pose_detection_camera.dart';
part 'pose_detection_exercise.dart';
part 'pose_detection_view.dart';

/// Main screen for pose detection with camera preview and skeleton overlay.
class PoseDetectionScreen extends StatefulWidget {
  const PoseDetectionScreen({super.key});

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}
