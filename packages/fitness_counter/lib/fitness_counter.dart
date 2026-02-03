/// Exercise rep counter package with pose-based tracking.
///
/// This package provides:
/// - Provider-agnostic models for pose data
/// - Exercise counters with state machines
/// - Signal processing utilities
///
/// Example:
/// ```dart
/// import 'package:fitness_counter/fitness_counter.dart';
///
/// // Create a counter
/// final counter = LateralRaiseCounter();
///
/// // Process poses
/// final event = counter.processPose(poseFrame);
/// if (event is RepCompleted) {
///   print('Rep ${event.totalReps} completed!');
/// }
/// ```
library;

// Models
export 'src/models/counter_event.dart';
export 'src/models/counter_state.dart';
export 'src/models/landmark.dart';
export 'src/models/pose_frame.dart';

// Core
export 'src/core/angle_calculator.dart';
export 'src/core/exercise_counter.dart';
export 'src/core/smoothing.dart';

// Exercises
export 'src/exercises/lateral_raise_counter.dart';
export 'src/exercises/single_squat_counter.dart';
export 'src/form_analyzers/lateral_raise_form_analyzer.dart';

// Exercise Configs
export 'src/config/exercise_config.dart';
export 'src/config/exercise_configs.dart';
export 'src/config/lateral_raise_config.dart';
export 'src/config/single_squat_config.dart';
