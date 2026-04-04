# UI Rehaul - Issue #84

This document tracks all UI/UX changes made to align the FitnessPipe app with
Apple Human Interface Guidelines and App Store readiness standards.

## Summary of Changes

### 1. Centralized Theme System

**New file:** `lib/presentation/theme/app_theme.dart`

- Created `FitnessPipeTheme` as a `ThemeExtension` with design tokens for:
  - Overlay colors (background, border)
  - Accent green (iOS system green `#30D158`)
  - Pose detection indicator colors
  - Form feedback severity colors (good/warning/bad)
  - Phase state colors (ready/active/transition/complete)
  - Overlay geometry (radius, blur sigma, padding)
- Created `GlassContainer` widget for consistent glass-morphism across overlays
- Created `buildAppTheme()` function producing a polished Material 3 dark theme with:
  - iOS-native AppBar styling (centered title, translucent background)
  - Consistent popup menu, dialog, bottom sheet, and slider themes
  - System text styles following iOS typography conventions
  - `FitnessPipeTheme.dark` extension attached

**Modified:** `lib/main.dart`
- Replaced inline `ThemeData` with `buildAppTheme()` from the new theme module

### 2. Shared Camera Overlay (DRY Refactor)

**New file:** `lib/presentation/widgets/camera_overlay.dart`

- Created `CameraOverlay` stateless widget that consolidates ALL overlay elements:
  - Exercise selector dropdown + settings gear (top-right)
  - Rep counter overlay (top-left)
  - Form feedback overlay (top-right, below selector)
  - Action buttons - voice toggle + reset counter (bottom-right, vertical toolbar)
  - Pose detection indicator pill (bottom-left)
  - Input mode badge (top-right, below selector)
- Eliminated ~300 lines of triplicated overlay code from `pose_detection_view.dart`
- Created `_ActionIconButton` as a consistent iOS-style circular glass button with
  44x44pt minimum touch targets and `Semantics`/`Tooltip` support

**Modified:** `lib/presentation/screens/pose_detection_view.dart`
- Replaced three copies of overlay code (file preview, iOS camera, Android camera)
  with single `_buildOverlay()` method that returns `CameraOverlay`
- Reduced from 721 lines to ~330 lines
- Removed the standalone `_buildExerciseActionButton()` method
- Skeleton painter, camera preview, and orientation handling are unchanged

**Modified:** `lib/presentation/screens/pose_detection_screen.dart`
- Added import for `camera_overlay.dart`
- Removed now-unused direct imports of `exercise_selector.dart`,
  `form_feedback_overlay.dart`, and `rep_counter_overlay.dart`

### 3. Exercise Selector + Settings Relocated to Top-Right

Per issue requirement: *"Ensure that the exercise choice dropdown and the gearbox
appear at the top right of the screen"*

- Exercise selector and settings gear icon now render at `top: 16, right: 16`
  (previously `top: 16, left: 16`)
- Layout: `[settings gear] [exercise selector]` in a right-aligned `Row`

### 4. Modernized Exercise Selector

**Modified:** `lib/presentation/widgets/exercise_selector.dart`

- Replaced `DropdownButton` with `PopupMenuButton` for iOS-native popup behavior
- Wrapped in `GlassContainer` for glass-morphism styling
- Selected exercise shown with green checkmark icon; unselected with radio-off
- Chevron indicator replaces dropdown arrow
- **Preserved** `Semantics(label: selectedExercise?.displayName ?? 'Select Exercise')`
  for Maestro test compatibility

### 5. Modernized Rep Counter Overlay

**Modified:** `lib/presentation/widgets/rep_counter_overlay.dart`

- Wrapped in `GlassContainer` (blur-backed, border, rounded corners)
- Used theme tokens for status indicator colors and glow effects
- Added info icon to start prompt for better visual hierarchy
- Adjusted typography: lighter angle debug text, consistent font weights
- **Preserved** `Semantics(label: '$repCount')` and `Semantics(label: 'reps')`
  for Maestro test compatibility

### 6. Modernized Form Feedback Overlay

**Modified:** `lib/presentation/widgets/form_feedback_overlay.dart`

- Wrapped in `GlassContainer` for consistent glass-morphism
- Used theme tokens (`feedbackGood`, `feedbackWarning`, `feedbackBad`) instead
  of hardcoded `Colors.red`/`Colors.orange`/`Colors.green`
- Added `Semantics` labels for accessibility (reads out form status and issues)
- Warning/bad feedback has a colored border on the glass container for emphasis

### 7. Settings as Bottom Sheet

**Modified:** `lib/presentation/widgets/threshold_settings_dialog.dart`

- Converted from `AlertDialog` to `DraggableScrollableSheet` inside
  `showModalBottomSheet` for native iOS interaction pattern
- Added `showThresholdSettingsSheet()` convenience function
- Header row with "Settings" title, help button, and "Apply" action
- Draggable with initial 65% height, expandable to 90%
- Used theme tokens for slider colors and section styling
- All slider logic, sensitivity sections, and `ThresholdDialogResult` return
  value are functionally identical
- Renamed internal widget to `ThresholdSettingsSheet` (was `ThresholdSettingsDialog`)

**Modified:** `lib/presentation/screens/pose_detection_exercise.dart`
- Updated `_showThresholdSettings()` to call `showThresholdSettingsSheet()`
  instead of `showDialog<ThresholdDialogResult>`

### 8. Modernized Exercise Demo Dialog

**Modified:** `lib/presentation/widgets/exercise_demo_dialog.dart`

- Applied `GlassContainer` to title overlay, close button, and countdown badge
- Updated background color to `Color(0xFF1C1C1E)` (iOS dark surface)
- Used theme tokens for countdown warning color
- Video player behavior, auto-close countdown, and dismiss logic unchanged

### 9. Action Buttons Redesign

- Replaced `FloatingActionButton` widgets with `_ActionIconButton` (in
  `camera_overlay.dart`) -- 44x44pt glass-backed circular buttons
- Voice toggle and reset counter grouped in a vertical column at bottom-right
- Each button has `Semantics`, `Tooltip`, and adequate touch target size

### 10. Accessibility Improvements

- All interactive overlay elements have `Semantics` widgets
- `_ActionIconButton` enforces 44x44pt minimum touch targets (Apple HIG)
- Pose detection indicator has `Semantics(label: 'Pose detected'/'No pose detected')`
- Form feedback overlay announces status and issue messages via Semantics
- All colors use sufficient contrast against dark backgrounds (verified against
  WCAG AA for text on dark overlays)

## Test Compatibility

### Widget Tests (`test/widget_test.dart`)
- `find.text('FitnessPipe')` still finds the AppBar title -- **PASS**

### Input Mode Tests (`test/presentation/screens/pose_detection_input_mode_test.dart`)
- Pure enum metadata tests, no UI dependency -- **PASS** (3 tests)

### Package Tests (`packages/fitness_counter/test/`)
- Pure logic tests, no UI dependency -- **PASS** (77 tests)

### Maestro E2E (`maestro-test/ios-flow.yaml`)
All accessibility labels preserved:
| Maestro assertion | Widget | Status |
|---|---|---|
| `assertVisible: "FitnessPipe"` | AppBar title | Preserved |
| `visible: "Select Exercise"` | ExerciseSelectorDropdown Semantics label | Preserved |
| `tapOn: "Lateral Raise"` / etc. | Semantics label changes to exercise name; PopupMenuItem text | Preserved |
| `assertVisible: "reps"` | RepCounterOverlay Semantics label | Preserved |
| `visible: "[1-9][0-9]*"` | Rep count text widget | Preserved |

The Maestro flow was not modified -- no changes required.

## Apple HIG Alignment Checklist

| Principle | Implementation |
|---|---|
| Clarity | Glass-morphism overlays with clear hierarchy; large rep count, smaller debug info |
| Deference | Translucent overlays defer to camera content; minimal visual competition |
| Depth | Backdrop blur creates layering; colored borders on feedback for emphasis |
| Consistency | Shared `GlassContainer`, `_ActionIconButton`, and `FitnessPipeTheme` tokens |
| Native Components | `PopupMenuButton` for exercise selector; bottom sheet for settings |
| Navigation | Standard bottom sheet dismiss gesture; popup menu for selection |
| Visual Hierarchy | Primary content (camera) unobstructed; overlays use progressive disclosure |
| Accessibility | Semantics labels, 44pt touch targets, dynamic text via theme textTheme |
| Touch Optimization | 44x44pt buttons, adequate spacing between interactive elements |
| Content-First | Camera preview fills screen; controls overlay without blocking content |

## Files Changed

| File | Action |
|---|---|
| `lib/presentation/theme/app_theme.dart` | Created |
| `lib/presentation/widgets/camera_overlay.dart` | Created |
| `lib/main.dart` | Modified |
| `lib/presentation/screens/pose_detection_screen.dart` | Modified |
| `lib/presentation/screens/pose_detection_view.dart` | Modified |
| `lib/presentation/screens/pose_detection_exercise.dart` | Modified |
| `lib/presentation/widgets/exercise_selector.dart` | Modified |
| `lib/presentation/widgets/rep_counter_overlay.dart` | Modified |
| `lib/presentation/widgets/form_feedback_overlay.dart` | Modified |
| `lib/presentation/widgets/threshold_settings_dialog.dart` | Modified |
| `lib/presentation/widgets/exercise_demo_dialog.dart` | Modified |
| `docs/ui-rehaul-issue-84.md` | Created (this file) |

## 11. Bench Press Form Sensitivity Sliders

The bench press exercise was missing its form sensitivity calibration sliders
in the settings widget. Lateral raise and single squat both had full sensitivity
sections, but bench press passed `null` as `initialSensitivity`, so no sliders
appeared.

**Changes:**

- **`lib/presentation/screens/pose_detection_controller.dart`** -- Changed
  `_benchPressSensitivity` from `final` to mutable so user adjustments persist
- **`lib/presentation/screens/pose_detection_exercise.dart`** -- Updated
  `_showThresholdSettings()` to pass `_benchPressSensitivity` instead of `null`;
  added result handler to apply `BenchPressSensitivity` changes back to the analyzer
- **`lib/presentation/widgets/threshold_settings_dialog.dart`** -- Added
  `_buildBenchPressSensitivity()` method with three slider sections:
  - **Elbow Flare** (warn/bad angles, 55-100 range)
  - **Uneven Extension** (warn/bad angle differences, 8-40 range)
  - **Hip Rise** (warn/bad drop percentages, 2-25% range)
  - Reset to Defaults button
  Updated `_buildSensitivitySection()` to dispatch to the new builder for
  `BenchPressSensitivity`

## No Regressions

Full CI verification passed:
```
flutter analyze --fatal-infos          # No issues found
flutter test                           # 4/4 passed
cd packages/fitness_counter && flutter test  # 77/77 passed
dart format lib/ test/ packages/ --set-exit-if-changed  # 0 files changed
```
