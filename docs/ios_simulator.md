# iOS Simulator & Virtual Camera Guide

This guide explains how to run the FitnessPipe app on the iOS Simulator, specifically addressing the requirements for Apple Silicon (M1/M2/M3) Macs and the Virtual Camera system used for testing.

## Quick Start

We provide a helper script to automatically boot the simulator in the correct mode and launch the app:

```bash
./run_rosetta.sh
```

## Architecture Overview

### 1. Rosetta Mode (x86_64) requirement
The application relies on native code plugins (specifically `google_mlkit_pose_detection` and its underlying dependencies) that, in some configurations on the Simulator, may not fully support `arm64` architecture or have specific linkage requirements.

To ensure stability and compatibility, we force the Simulator to run in **Rosetta (x86_64)** mode.
- **Why?** It ensures that the binary built for `x86_64` runs correctly on Apple Silicon machines without architecture mismatch errors during the build or runtime.
- **How?** The `run_rosetta.sh` script explicitly boots the simulator with `--arch=x86_64` and runs the flutter build command with `arch -x86_64`.

### 2. Virtual Camera Injection
The iOS Simulator does not support real camera input. To test Pose Detection logic without a physical device, we implemented a **Virtual Camera** system.

#### How it works:
1.  **Detection**: The app detects if it is running on a Simulator (or if no physical cameras are found).
2.  **Asset Streaming**: Instead of connecting to `AVFoundation`, the `VirtualCameraService` reads a sequence of JPEG images from `assets/fixtures/`.
3.  **Pose Processing**: These images are converted to `InputImage` format and fed directly into the `MLKitPoseDetector`.
4.  **Looping**: The service loops through the frames (e.g., a squat or lateral raise video converted to frames) to simulate a continuous video feed.

This allows us to test:
- Pose Detection accuracy
- Rep Counting logic
- Skeleton Overlay alignment
- Exercise state machines

All without leaving the development environment.

## Changing the Simulated Exercise

The app automatically switches the "Virtual Video" when you select different exercises in the UI. 

To add a new simulated exercise:
1.  Extract frames from a video using `packages/fitness_counter/test/fixtures/extract_poses.py --export-images`.
2.  Add the frames to `assets/fixtures/your_exercise/`.
3.  Update `VirtualCameraService.dart` to include the new exercise configuration.
