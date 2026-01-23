#!/bin/bash
set -e

# Set ANDROID_HOME for Homebrew installation
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/opt/homebrew/bin

echo "Installing Android System Image (this may take a while)..."
yes | sdkmanager "system-images;android-34;google_apis;arm64-v8a"

echo "Creating Android Virtual Device 'TestingAVD'..."
# Check if AVD exists, if not create it
if ! avdmanager list avd | grep -q "TestingAVD"; then
    echo "no" | avdmanager create avd -n TestingAVD -k "system-images;android-34;google_apis;arm64-v8a" -d "pixel_6" --force
    echo "AVD 'TestingAVD' created."
else
    echo "AVD 'TestingAVD' already exists."
fi

echo "Setup complete. You can now run ./launch_emulator.sh"
