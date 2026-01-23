#!/bin/bash

# Set ANDROID_HOME for Homebrew installation
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:/opt/homebrew/bin

echo "Detected Webcams:"
emulator -avd TestingAVD -webcam-list || echo "Could not list webcams (emulator running?)"

echo "---------------------------------------------------"
echo "Launching Emulator 'TestingAVD' with camera-back=webcam1..."
echo "If this is still the wrong camera, edit this file to try 'webcam2'."
echo "---------------------------------------------------"

emulator -avd TestingAVD -camera-back webcam2
