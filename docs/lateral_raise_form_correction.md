# Lateral Raise Form Correction Implementation

This document details the rule-based form correction logic implemented for the Lateral Raise exercise. The system analyzes pose landmarks frame-by-frame to detect common biomechanical errors and provide real-time feedback.

## Architecture

The form correction logic is decoupled from the Rep Counter.
-   **Component**: `LateralRaiseFormAnalyzer` (`packages/fitness_counter/lib/src/form_analyzers/lateral_raise_form_analyzer.dart`)
-   **Input**: `Map<LandmarkId, Landmark>` (Current frame's pose)
-   **Output**: `FormFeedback` object containing overall `FormStatus` and a list of `FormIssue`s.

## Biomechanical Rules

The analyzer checks three primary form components every frame.

### 1. Straight Arms (Elbow Extension) - **IMPROVED**
Ensures the user maintains a "soft bend" in the elbows without excessively bending them. Now features per-arm smoothing and robust gating.

*   **Metric**: Minimum of Smoothed Left/Right Elbow Angles.
*   **Logic**:
    1.  **Phase Gating**: Elbows are *only* evaluated during the **Active Phase** (Wrists > 5% above hip center).
    2.  **Smoothing**: Per-arm EMA smoothing (alpha=0.2) reduces jitter.
    3.  **Hysteresis**: Warnings require entering < 155° and only clear when > 158°.
    4.  **Sustained**: Warnings must persist for 6 frames (~0.2s) to trigger.
*   **Thresholds**:
    *   **Good**: > 155° (or > 145° if not sustained)
    *   **Warning** (`ELBOW_SOFT`): 145° - 155° (sustained)
    *   **Bad** (`ELBOW_BENT`): < 145° (immediate)

### 2. Trunk Stability (Core Control)
Ensures the user is standing upright and not swinging or leaning to cheat the movement.

*   **Metric A: Trunk Lean**
    *   **Calculation**: Angle deviation of the `ShoulderCenter -> HipCenter` vector from the vertical Y-axis.
    *   **Thresholds**:
        *   **Good**: < 8°
        *   **Warning** (`TRUNK_LEAN`): 8° - 15°
        *   **Bad** (`TRUNK_LEAN`): > 15°

*   **Metric B: Lateral Shift**
    *   **Calculation**: Horizontal distance between `ShoulderCenter.x` and `HipCenter.x`, normalized by `ShoulderWidth`.
    *   **Thresholds**:
        *   **Good**: < 0.10 (10% of shoulder width)
        *   **Warning** (`TRUNK_SHIFT`): 0.10 - 0.18
        *   **Bad** (`TRUNK_SHIFT`): > 0.18

### 3. No Shrugging (Scapular Depression) - **IMPROVED**
Ensures the user keeps their shoulders down and doesn't lift with their traps. Now features enhanced robustness against noise and head movement.

*   **Metric**: Normalized Neck Length (smoothed).
*   **Calculation**: Average distance of `(LeftEar -> LeftShoulder)` and `(RightEar -> RightShoulder)`, normalized by `ShoulderWidth`.
*   **Metrics**:
    *   `neck_length_smoothed`: EMA smoothed neck length (alpha=0.2).
    *   `neck_baseline`: Calibrated "neutral" neck length.
*   **Logic**:
    1.  **Baseline Calibration**: Baseline is *only* learned when the user is in the **Inactive Phase** (Arms down / Wrists below hips). This prevents learning a shrugged posture as normal.
    2.  **Phase Gating**: Shrugging is *only* evaluated during the **Active Phase** (Wrists lifted > 5% above hip center). This ignores noise during setup or rest.
    3.  **Sustained Detection**: A "BAD" status for shrugging requires the condition to persist for **8 consecutive frames** (~0.25s) to avoid flickering errors.
    4.  **Drop Calculation**: % decrease from baseline.
*   **Thresholds**:
    *   **Good**: Drop < 10%
    *   **Warning** (`SHRUGGING`): Drop 10% - 28%
    *   **Bad** (`SHRUGGING`): Drop > 28% (sustained 8+ frames)

## Feedback Codes

The Analyzer emits the following issue codes:

| Code | Message | Severity | Trigger |
| :--- | :--- | :--- | :--- |
| `LOW_CONFIDENCE` | "Ensure full body is visible" | Warning | Missing required landmarks |
| `ELBOW_BENT` | "Keep your elbows straighter" | Bad | Elbow angle < 145° |
| `ELBOW_SOFT` | "Straighten arms slightly" | Warning | Elbow angle 145°-155° (sustained) |
| `TRUNK_LEAN` | "Avoid leaning your torso" | Bad | Trunk lean > 15° |
| `TRUNK_LEAN` | "Stand straighter" | Warning | Trunk lean 8°-15° |
| `TRUNK_SHIFT` | "Core is shifting - brace tight" | Bad | Lateral shift > 0.18 |
| `TRUNK_SHIFT` | "Keep hips stable" | Warning | Lateral shift 0.10-0.18 |
| `SHRUGGING` | "Don't shrug—shoulders down" | Bad | Neck length drop > 28% (sustained) |
| `SHRUGGING` | "Relax your shoulders" | Warning | Neck length drop 10%-28% |

## UI Integration

*   **Widget**: `FormFeedbackOverlay`
*   **Location**: Top-Right corner of `PoseDetectionScreen` (to avoid collision with the Rep Counter on the Top-Left).
*   **Behavior**:
    *   **Good Form**: Displays a subtle green checkmark.
    *   **Warning/Bad**: Displays a box with an icon (Orange/Red) and a list of specific text messages.
