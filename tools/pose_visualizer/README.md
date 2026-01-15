# Pose Data Visualizer

A Flutter tool to visualize pose landmark data from test fixtures, specifically designed to help understand and debug the lateral raise counter tests.

## Overview

This tool displays:
- **Skeleton visualization** - Real-time rendering of pose landmarks as a stick figure
- **Angle progression graph** - Shows how shoulder angle changes across all frames
- **Playback controls** - Play/pause, frame scrubbing, and frame-by-frame navigation
- **Live metrics** - Current frame, angle, and overall angle range

## Quick Start

```bash
cd tools/pose_visualizer
flutter run -d macos
```

Or use other platforms:
```bash
flutter run -d chrome    # Web browser
flutter run -d windows   # Windows
flutter run -d linux     # Linux
```

## What You'll See

The app displays the `real_lateral_raise.dart` test fixture data with:

1. **Top panel**: Stick figure showing the pose
   - Green lines = skeleton connections
   - Red dots = individual landmarks
   
2. **Middle panel**: Angle graph
   - Blue line = shoulder angle progression
   - Red vertical line = current frame marker
   
3. **Bottom panel**: Controls
   - Slider to scrub through frames
   - Play/pause button for animation
   - Frame counter and angle display

## Select Exercise

You can switch between different exercise data sets (e.g., **Lateral Raise**, **Single Squat**) using the dropdown menu in the top right corner of the app bar.

## Modifying the Data Source

To add new pose data:

1. Add your fixture file to `lib/` (e.g., `real_new_exercise.dart`).
2. Import it in `lib/main.dart`.
3. Add a new `ExerciseData` entry to the `exercises` list in `_PoseVisualizerPageState.initState`.
4. Hot reload/restart.

## Development

The app consists of three main components:

- `PosePainter` - Renders the skeleton visualization
- `AngleGraphPainter` - Draws the angle progression chart  
- `PoseVisualizerPage` - Manages state and playback controls

## Use Cases

- **Debugging test failures** - Visualize exactly what pose data the tests are using
- **Understanding movement patterns** - See how angles change during exercises
- **Validating test fixtures** - Ensure extracted pose data looks realistic
- **Creating new tests** - Explore real video data before writing test assertions
