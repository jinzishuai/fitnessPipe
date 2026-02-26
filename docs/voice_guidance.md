# Voice Guidance for Form Correction

> **Issue**: [#47 — Voice warnings/messages for form correction](https://github.com/jinzishuai/fitnessPipe/issues/47)

## Overview

Voice guidance supplements the existing visual `FormFeedbackOverlay` by speaking short form-correction phrases aloud. This allows hands-free, eyes-free coaching during exercise.

## Architecture

### Data Flow

```
Camera Frame
  → _processPoseDetection()
  → _processPoseWithCounter()
  → FormAnalyzer.analyzeFrame()          // produces FormFeedback
  → FeedbackCooldownManager.process()    // throttles visual + voice
  ├→ FormFeedbackOverlay (visual)
  └→ VoiceGuidanceService (audio)        // flutter_tts
```

### Components

#### `FeedbackCooldownManager`
**Location**: `packages/fitness_counter/lib/src/form_analyzers/feedback_cooldown_manager.dart`

Pure Dart class that throttles **both visual and voice** feedback. Prevents overwhelming the user with corrections they haven't had time to act on.

| Parameter | Default | Description |
|---|---|---|
| `globalCooldown` | 2 seconds | Minimum gap between **any** feedback |
| `perCodeCooldown` | Per-exercise (see config) | Same issue code won't repeat until this elapses |

**Priority**: `FormStatus.bad` always wins over `FormStatus.warning`. Within the same severity, the first-detected issue wins.

#### `VoiceGuidanceService`
**Location**: `lib/data/services/voice_guidance_service.dart`

Wraps `flutter_tts` with:
- **Message map**: `FormIssue.code` → short voice phrase (2–5 words)
- **Interruption (Option B)**: `bad` messages call `stop()` then `speak()`, cleanly cutting off any in-progress `warning`
- **Queue depth**: 1 — only the latest highest-priority message matters
- **Enable/disable toggle**: user-facing mute control
- **Silent on good form**: no positive feedback

#### Voice Phrases

| Issue Code | Severity | Voice Phrase |
|---|---|---|
| `ELBOW_BENT` | bad | "Keep your arms straight" |
| `ELBOW_SOFT` | warning | "Extend your elbows more" |
| `TRUNK_LEAN` | bad/warning | "Keep your torso upright" |
| `TRUNK_SHIFT` | bad/warning | "Keep your hips centered" |
| `SHRUGGING` | bad/warning | "Relax your shoulders away from ears" |
| `LOW_CONFIDENCE` | warning | *(silent)* |

### Exercise Config Extension

Each exercise config exposes a `feedbackCooldown` duration:

```dart
// In ExerciseConfig (base class)
Duration get feedbackCooldown => const Duration(seconds: 3);
```

This allows per-exercise tuning — e.g., a fast exercise might use 2s, a slow exercise 4s.

## TTS Engine

**`flutter_tts`** — uses native platform TTS:
- **iOS/macOS**: `AVSpeechSynthesizer` (Apple neural voices on iOS 17+)
- **Android**: Android TTS engine (Google Neural2 preferred)

| Metric | Value |
|---|---|
| Latency | ~50–200ms for short phrases |
| Offline | ✅ (with installed language packs) |
| Platforms | iOS, Android, macOS |

TTS runs **asynchronously** — it never blocks the pose detection pipeline.

### Voice Selection

1. Query available voices for device locale (e.g. `en-US`)
2. Prefer enhanced/premium neural voices when available
3. Fallback to device default
4. Speech rate: slightly elevated (~1.1x); pitch: neutral

## Adding Voice Guidance for a New Exercise

1. Create a `FormAnalyzer` for the exercise (produces `FormFeedback` with `FormIssue` objects)
2. Add code→phrase mappings to `VoiceGuidanceService._voicePhrases`
3. Optionally override `feedbackCooldown` in the exercise config

No changes needed to `FeedbackCooldownManager` or the integration code.

## Testing

### Unit Tests (`feedback_cooldown_manager_test.dart`)
- First feedback passes immediately
- Same code blocked within per-code cooldown
- Same code allowed after cooldown expires
- Different code blocked within global cooldown
- `bad` severity preempts `warning`
- `reset()` clears all cooldown state

### Manual Testing
- Deploy to device → exercise with bad form → verify voice plays
- Hold bad form → confirm throttled (not every frame)
- Trigger multiple issues → confirm priority ordering
