# Android Emulator Testing with OBS Virtual Camera

This guide explains how to configure the Android Emulator to use OBS Studio as a virtual camera input. This is useful for testing camera-based features (like Pose Detection) with consistent, static, or pre-recorded video feeds.

## Prerequisites

1.  **Android Studio** and **Android SDK Command-line Tools**.
2.  **OBS Studio** installed on your machine.
    *   macOS: `brew install --cask obs`
3.  **Android Application** configured effectively.

## Step 1: Configure Android Application

By default, some Android configurations might prevent the app from installing or running on an emulator if it strictly requires camera hardware.

1.  Open `android/app/src/main/AndroidManifest.xml`.
2.  Ensure the camera feature is not marked as required if you want to be safe, though modern emulators often handle this.
    ```xml
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    ```

## Step 2: Configure OBS Studio

1.  Open **OBS Studio**.
2.  Create a **Scene**.
3.  Add a **Source** (e.g., Image, Media Source/Video).
    *   *Tip: Use an aspect ratio that matches the phone sensor if possible, e.g., 720x1280 or 1280x720 depending on testing needs.*
4.  Click **Start Virtual Camera** in the controls dock.

## Step 3: Identify Virtual Camera Webcam ID

The Android emulator sees the computer's cameras (physical and virtual) as `webcam0`, `webcam1`, etc. Usually, if you have no physical webcam, the OBS Virtual Camera might be `webcam0`. If you have a built-in webcam, OBS might be `webcam1`.

To list available webcams for the emulator:

```bash
~/Library/Android/sdk/emulator/emulator -avd <Your_AVD_Name> -webcam-list
```

## Step 4: Launch Emulator with Virtual Camera

You need to launch the emulator from the command line to explicitly map the camera.

1.  List your available AVDs (Android Virtual Devices):
    ```bash
    ~/Library/Android/sdk/emulator/emulator -list-avds
    ```
    *Example Output: `Medium_Phone_API_36`*

2.  Launch the emulator mapping the back camera to the OBS source (usually `webcam0` or `webcam1`):
    ```bash
    ~/Library/Android/sdk/emulator/emulator -avd <AVD_NAME> -camera-back webcam0
    ```
    *   Replace `<AVD_NAME>` with your actual AVD name.
    *   If `webcam0` is your physical camera, try `webcam1`.

**Note:** You must keep the terminal window open, or run it in the background/detached.

## Troubleshooting

### Camera output is black or green
*   Ensure OBS Virtual Camera is actually **Started**.
*   Check macOS Permissions: System Settings -> Privacy & Security -> Camera (or Screen Recording if capturing screen). OBS needs permission.
*   Restart the emulator after starting the OBS Virtual Camera.

### App fails to install "User rejected permissions"
*   This usually refers to runtime permissions. Ensure you accept the Camera permission dialog in the Android app.

### Orientation Issues
*   Android emulator cameras are often "mounted" in landscape (90 degrees sensor orientation).
*   If your image appears sideways, you may need to rotate your source in OBS or adjust your application's coordinate handling (as handled in `SkeletonPainter` for this project).
