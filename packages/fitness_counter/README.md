# fitness_counter

A pure Dart package for exercise rep counting using pose landmark data.

## Features

- **Exercise-agnostic architecture**: Base classes for any exercise type
- **Lateral Raise Counter**: MVP implementation with state machine-based rep detection
- **Signal processing**: EMA smoothing for noisy pose data
- **Geometric utilities**: Angle calculation from landmarks

## Usage

```dart
import 'package:fitness_counter/fitness_counter.dart';

// Create counter
final counter = LateralRaiseCounter();

// Process pose frames
final event = counter.processPose(poseFrame);
if (event is RepCompleted) {
  print('Rep completed! Total: ${event.totalReps}');
}

// Get current state
print('Reps: ${counter.state.repCount}');
print('Phase: ${counter.state.phase}');
```

## Architecture

This package is independent of any pose detection provider. The main app is responsible for converting provider-specific pose data to the `PoseFrame` format expected by this package.
