import '../models/counter_event.dart';
import '../models/landmark.dart';
import '../models/pose_frame.dart';

/// Abstract base class for exercise counters.
///
/// Each exercise (lateral raise, squat, etc.) implements this interface
/// to provide rep counting and state tracking.
abstract class ExerciseCounter {
  /// The landmarks this exercise requires to function.
  ///
  /// The counter will skip frames that don't have all required landmarks.
  Set<LandmarkId> get requiredLandmarks;

  /// Process a pose frame and return an event if state changed.
  ///
  /// Returns:
  /// - `RepCompleted` when a rep is finished
  /// - `PhaseChanged` when movement phase changes
  /// - `ExerciseStarted` when tracking begins
  /// - `null` if no significant change occurred
  RepEvent? processPose(PoseFrame frame);

  /// Get the current state of the counter.
  ///
  /// The state type is exercise-specific.
  dynamic get state;

  /// Reset the counter to initial state.
  ///
  /// Clears rep count and returns to waiting/idle phase.
  void reset();
}
