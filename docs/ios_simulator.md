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

#### 1.1 Required on Apple Sillicon Mac: Install "Universal" iOS SDK

ref: https://github.com/jinzishuai/fitnessPipe/issues/1

Check `Xcode -> Settings -> Components -> iOS 26.0 info symbol`, we need to ensure we see

<img width="582" height="454" alt="Image" src="https://github.com/user-attachments/assets/b10f1434-9c5d-4f46-9f17-f6ce6fa6276b" />

If you see "Apple Sillicon", you have to delete it and then download the "Universal" version with command:

```
xcodebuild -downloadPlatform iOS -architectureVariant universal
```

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

## Adding a New Rosetta Simulator

If you want to test on a different device (e.g., **iPhone 16**), you can create a new simulator instance and boot it in Rosetta mode.

### 1. Identify Device Type and Runtime
List the available device types and runtimes:
```bash
xcrun simctl list devicetypes | grep "iPhone"
# Example Output: iPhone 16 (com.apple.CoreSimulator.SimDeviceType.iPhone-16)

xcrun simctl list runtimes
# Example Output: iOS 26.2 (26.2 - 23C54) - com.apple.CoreSimulator.SimRuntime.iOS-26-2
```

### 2. Create the Simulator
Matches the identifier found above. For example, to create an "iPhone 16 Rosetta":

```bash
xcrun simctl create "iPhone 16 Rosetta" "com.apple.CoreSimulator.SimDeviceType.iPhone-16" "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
```
This returns a UUID (e.g., `A1B2C3D4-....`).

### 3. Boot in Rosetta Mode
Use the UUID returned from the create command (or find it via `xcrun simctl list devices`):

```bash
xcrun simctl boot <UUID> --arch=x86_64
```

> [!IMPORTANT]
> **The name "Rosetta" is just a label.**
> Creating a simulator named "iPhone 16 Rosetta" does NOT automatically make it x86_64.
>
> While you successfully observed `x86_64` via UI launch (likely due to your Universal SDK or Simulator.app configuration), this is not guaranteed on all Apple Silicon setups.
> **Always verify with step 4.** If `uname -m` returns `arm64`, you MUST shutdown and boot via the command line with `--arch=x86_64`.

### 4. Verify Architecture

To verify that your simulator is actually running in Rosetta (x86_64) mode, you can run a command "inside" the simulator:

```bash
xcrun simctl spawn booted /usr/bin/uname -m
```

*   **Result `x86_64`**: Success! You are in Rosetta mode.
*   **Result `arm64`**: You are in native mode. Shutdown and reboot with `--arch=x86_64`.

### 4. Update Helper Script (Optional)
If you want to use this new simulator with the `run_rosetta.sh` script, update the `SIMULATOR_ID` variable in that file:

```bash
SIMULATOR_ID="<YOUR-NEW-UUID>" # iPhone 16 Rosetta
```
