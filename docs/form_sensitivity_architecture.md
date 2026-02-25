# Form Correction & Sensitivity Architecture

How real-time form analysis, voice guidance, and user-adjustable sensitivity work — and how to extend them for new exercises.

---

## System Overview

```
┌─────────────────────────┐     ┌──────────────────────────┐
│  LateralRaiseFormAnalyzer│────▶│  FeedbackCooldownManager │
│  (or future XyzAnalyzer) │     │  (global + per-code      │
│                         │     │   cooldown throttle)      │
│  reads from:            │     └──────────┬───────────────┘
│  LateralRaiseSensitivity│                │
└─────────────────────────┘                ▼
                                ┌──────────────────────────┐
                                │  FilteredFeedback        │
                                │  (single highest-priority │
                                │   issue per cooldown)     │
                                └─────┬──────────┬─────────┘
                                      │          │
                             ┌────────▼──┐  ┌────▼──────────┐
                             │ Visual    │  │ Voice         │
                             │ Overlay   │  │ Guidance      │
                             │ (3s auto- │  │ (TTS with     │
                             │  clear)   │  │  interruption) │
                             └───────────┘  └───────────────┘
```

## Key Components

| Component | Location | Purpose |
|---|---|---|
| `FormSensitivityConfig` | `fitness_counter/lib/src/config/form_sensitivity_config.dart` | Base class for sensitivity configs |
| `LateralRaiseSensitivity` | Same file | 6 adjustable thresholds for lateral raise |
| `LateralRaiseFormAnalyzer` | `fitness_counter/lib/src/form_analyzers/` | Frame-by-frame form analysis reading from sensitivity config |
| `FeedbackCooldownManager` | Same directory | Throttles feedback output (2s global, per-code cooldown) |
| `VoiceGuidanceService` | `lib/data/services/voice_guidance_service.dart` | TTS with priority interruption |
| `ThresholdSettingsDialog` | `lib/presentation/widgets/threshold_settings_dialog.dart` | UI dialog with angle + sensitivity sliders |

## Data Flow

1. **Analyzer** produces `FormFeedback` (list of `FormIssue` objects) each frame
2. **CooldownManager** filters to one `FilteredFeedback` per cooldown window, prioritizing `bad` over `warning`
3. **Visual overlay** displays the filtered issue for 3 seconds then auto-clears
4. **VoiceGuidanceService** speaks a short phrase, using priority-based interruption

---

## Adding Form Correction for a New Exercise

### Step 1: Create a Sensitivity Config

```dart
// fitness_counter/lib/src/config/form_sensitivity_config.dart

class BicepCurlSensitivity extends FormSensitivityConfig {
  final double swingWarnAngle;   // torso swing threshold
  final double wristCurlWarnAngle;

  const BicepCurlSensitivity({
    required this.swingWarnAngle,
    required this.wristCurlWarnAngle,
  });

  const factory BicepCurlSensitivity.defaults() = BicepCurlSensitivity._;
  const BicepCurlSensitivity._()
      : swingWarnAngle = 10.0,
        wristCurlWarnAngle = 145.0;

  BicepCurlSensitivity copyWith({...}) => BicepCurlSensitivity(...);

  @override
  BicepCurlSensitivity resetToDefaults() =>
      const BicepCurlSensitivity.defaults();
}
```

### Step 2: Create the Form Analyzer

```dart
// fitness_counter/lib/src/form_analyzers/bicep_curl_form_analyzer.dart

class BicepCurlFormAnalyzer {
  BicepCurlSensitivity _sensitivity;

  BicepCurlFormAnalyzer({BicepCurlSensitivity? sensitivity})
      : _sensitivity = sensitivity ?? const BicepCurlSensitivity.defaults();

  void updateSensitivity(BicepCurlSensitivity s) => _sensitivity = s;

  FormFeedback analyzeFrame(Map<LandmarkId, Landmark> landmarks) {
    // Use _sensitivity.swingWarnAngle, etc.
  }
}
```

### Step 3: Wire Into Exercise Config

```dart
// In BicepCurlConfig:
@override
FormSensitivityConfig get defaultFormSensitivity =>
    const BicepCurlSensitivity.defaults();
```

### Step 4: Add Voice Phrases

```dart
// In VoiceGuidanceService._voicePhrases:
'TORSO_SWING': 'Keep your torso still',
'WRIST_CURL': 'Keep wrists neutral',
```

### Step 5: Export & Integrate

1. Export new classes from `fitness_counter.dart`
2. In `pose_detection_screen.dart`:
   - Instantiate the analyzer when the exercise is selected
   - Pass sensitivity to the analyzer and dialog
   - Apply returned sensitivity via `updateSensitivity()`

### Step 6: Update the Settings Dialog

The `ThresholdSettingsDialog` auto-shows the sensitivity section when `initialSensitivity` is non-null. Add a new branch in `_buildSensitivitySection()` to render the exercise-specific sliders, or create a widget per exercise and select based on the config type:

```dart
if (sensitivity is LateralRaiseSensitivity) {
  return _buildLateralRaiseSliders(sensitivity);
} else if (sensitivity is BicepCurlSensitivity) {
  return _buildBicepCurlSliders(sensitivity);
}
```

---

## Design Principles

- **Direct thresholds** — each slider shows real physical units (degrees, %) rather than abstract multipliers
- **Constraint enforcement** — sliders prevent invalid states (e.g., warn > bad threshold)
- **Reset to Defaults** — one-tap restore to tuned factory values
- **Auto-hide** — sensitivity section hidden for exercises without form analysis
- **Non-blocking voice** — TTS uses `awaitSpeakCompletion(false)` with iOS audio session configured to coexist with camera
