# Adding a New Exercise

This guide documents the process of adding support for a new exercise to FitnessPipe, based on the implementation workflow of the **Single Squat** counter.

The process involves work in two main areas:
1.  **`packages/fitness_counter`**: The core logic, state management, and unit tests.
2.  **`lib/presentation`**: The UI integration, settings, and visualization.

---

## Part 1: Logic & Core Implementation (`packages/fitness_counter`)

### 1. Analysis & Preparation
Before writing code, analyze the movement to understand the biomechanics and required landmarks.

1.  **Obtain a Reference Video**: Get a video of the exercise being performed correctly. Save it to `packages/fitness_counter/test/fixtures/[exercise_name].mp4`.
2.  **Extract & Analyze Data**:
    *   Create a copy of `test/fixtures/extract_poses.py` (e.g., `extract_[exercise]_poses.py`).
    *   Modify it to extract relevant landmarks and calculate specific angles (e.g., knee angle, hip angle).
    *   Run the script to generate a Dart fixture file (e.g., `real_[exercise_name].dart`).
    *   **Analyze the output**: Look at the minimum/maximum angles during the rep to determine safe and effective **Top** and **Bottom** thresholds.

### 2. Update Core Helpers
If the exercise utilizes a joint angle not currently calculated (e.g., Knee Angle), add it to the helper.

*   **File**: `lib/src/core/angle_calculator.dart`
*   **Action**: Add functions like `calculateKneeAngle` or `calculateHipAngle`.

### 3. Define State Models
Define the phases of the movement and the state object.

*   **File**: `lib/src/models/counter_state.dart`
*   **Action**:
    *   Add an `ForExamplePhase` enum (e.g., `waiting`, `descending`, `bottom`, `ascending`).
    *   Add an `ForExampleState` class matching the pattern of `LateralRaiseState`. Ensure it has:
        *   `repCount`
        *   `phase`
        *   `currentAngle` (raw)
        *   `smoothedAngle` (processed)

### 4. Implement the Counter
Create the main logic class.

*   **File**: `lib/src/exercises/[exercise_name]_counter.dart`
*   **Action**: Create a class extending `ExerciseCounter<ForExampleState>`.
    *   **Constructor**: distinct thresholds, hold times.
    *   **`processPose`**:
        *   Check for required landmarks.
        *   Calculate angles.
        *   Apply smoothing (EMA).
        *   Run state machine logic (`_processStateMachine`).
    *   **State Machine**: Implement the transitions between phases based on the thresholds determined in Step 1.

### 5. Export the Counter
Make the new class available to the app.

*   **File**: `lib/fitness_counter.dart`
*   **Action**: Add `export 'src/exercises/[exercise_name]_counter.dart';`.

---

## Part 2: Testing

Robust testing is crucial for ensuring the counter works across different speeds and camera angles.

### 1. Create Unit Tests
*   **File**: `test/[exercise_name]_counter_test.dart`
*   **Tests needed**:
    *   **Initial State**: Verify starts at 0 reps and correct waiting phase.
    *   **Leg/Arm Integrity**: Verify it respects required landmarks.
    *   **Synthetic Flow**: Create manual `PoseFrame` sequences (using `createPoseFrame` helper) to simulate a perfect rep and verify state transitions.
    *   **Real Data Validation**: Iterate through the fixture data created in Part 1 (`real_[exercise_name].dart`) and assert that the counter detects the expected number of reps.

---

## Part 3: UI Integration (`lib`)

### 1. Update Exercise Selection
*   **File**: `lib/presentation/widgets/exercise_selector.dart`
*   **Action**: Add a new case to the `ExerciseType` enum.

### 2. Update Main Screen Logic
*   **File**: `lib/presentation/screens/pose_detection_screen.dart`
*   **Action**:
    1.  **State Variables**: Add a nullable variable for the counter (e.g., `SingleSquatCounter? _singleSquatCounter`) and its specific thresholds.
    2.  **Selection Logic (`_onExerciseSelected`)**: Initialize the specific counter when selected, and dispose/nullify others.
    3.  **Processing Loop (`_processPoseWithCounter`)**:
        *   Add a branch for the new exercise type.
        *   Call `processPose`.
        *   **UI Mapping**: Map the counter's specific `Phase` enum to a generic UI string label (e.g., "Descending") and Color (e.g., `Colors.orange`).
    4.  **Settings Dialog (`_showThresholdSettings`)**: Ensure the settings dialog reads from and updates the correct threshold variables for the active exercise.
    5.  **Reset Logic**: Ensure `_resetCounter` calls reset on the new counter instance.

---

## Checklist Summary
- [ ] Reference video & Data extraction
- [ ] `AngleCalculator` updated
- [ ] `CounterState` (Enum & Class) created
- [ ] `[Name]Counter` class implemented
- [ ] Exported in `fitness_counter.dart`
- [ ] Unit tests (Synthetic + Real Data) passed
- [ ] `ExerciseType` enum updated
- [ ] `PoseDetectionScreen` logic integrated
