# Pose Detection Screen Split Design

**Issue:** `#71`

## Goal

Reduce the cognitive and token load of the pose detection presentation code by
splitting the current monolithic screen implementation into smaller,
single-purpose files without changing runtime behavior.

## Constraints

- Preserve existing camera, preview, rep counting, form feedback, and dialog
  behavior.
- Keep the presentation layer using the existing `PoseDetector` abstraction.
- Avoid broad architectural changes such as introducing a new state management
  framework.

## Chosen Approach

Keep `PoseDetectionScreen` as the owning `StatefulWidget`, but divide the
implementation into focused files:

- `pose_detection_screen.dart`
  Holds imports, public widget entry point, and part declarations.
- `pose_detection_input_mode.dart`
  Defines input-mode metadata in a dedicated file.
- `pose_detection_state.dart`
  Holds state fields and computed getters.
- `pose_detection_lifecycle.dart`
  Holds initialization, disposal, camera startup, and frame processing logic.
- `pose_detection_exercise.dart`
  Holds exercise selection, counters, feedback, demos, threshold settings, and
  reset behavior.
- `pose_detection_view.dart`
  Holds `build`, scaffold/body selection, and preview composition.

## Notes

- Shared preview metadata moves out of ad hoc switch statements and into the
  input mode definition so it can be tested directly.
- The split is intentionally incremental: one screen, same behavior, smaller
  files.
