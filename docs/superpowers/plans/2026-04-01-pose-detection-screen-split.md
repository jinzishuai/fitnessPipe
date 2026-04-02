# Pose Detection Screen Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the pose detection screen implementation into smaller focused files while preserving existing behavior.

**Architecture:** Keep the current `StatefulWidget` ownership model and `part`-based private access, but divide lifecycle, exercise, and view concerns into dedicated files. Extract input-mode metadata into a separate file so repeated UI rules become explicit and testable.

**Tech Stack:** Flutter, Dart, existing `camera`, `camera_macos`, `google_mlkit_commons`, and app presentation widgets

---

### Task 1: Extract input-mode metadata

**Files:**
- Create: `lib/presentation/screens/pose_detection_input_mode.dart`
- Test: `test/presentation/screens/pose_detection_input_mode_test.dart`

- [ ] Step 1: Write the failing test for labels and preview metadata.
- [ ] Step 2: Run the new test and verify it fails because the file/API does not exist yet.
- [ ] Step 3: Implement the enum and metadata extension with minimal behavior.
- [ ] Step 4: Re-run the new test and verify it passes.

### Task 2: Split the screen implementation by concern

**Files:**
- Modify: `lib/presentation/screens/pose_detection_screen.dart`
- Create: `lib/presentation/screens/pose_detection_state.dart`
- Create: `lib/presentation/screens/pose_detection_lifecycle.dart`
- Create: `lib/presentation/screens/pose_detection_exercise.dart`
- Create: `lib/presentation/screens/pose_detection_view.dart`

- [ ] Step 1: Move fields and computed getters into the state file.
- [ ] Step 2: Move lifecycle, camera, and frame-processing methods into the lifecycle file.
- [ ] Step 3: Move exercise, feedback, dialog, and reset methods into the exercise file.
- [ ] Step 4: Move `build` and preview composition into the view file.
- [ ] Step 5: Reuse the extracted input-mode metadata in the view and controller logic.

### Task 3: Verify the refactor

**Files:**
- Modify: `lib/presentation/screens/pose_detection_controller.dart` or remove once superseded

- [ ] Step 1: Run `dart format lib/ test/ packages/`.
- [ ] Step 2: Run `flutter analyze`.
- [ ] Step 3: Run `flutter test`.
- [ ] Step 4: Run `flutter test` in `packages/fitness_counter/`.
- [ ] Step 5: Review `git diff` for accidental behavior changes and prepare the PR.
