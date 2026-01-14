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
