#!/bin/bash

# Configuration
# Use explicit ID if valid, otherwise fallback to "iPhone 17 Rosetta" default.
# Can be overridden by env var SIMULATOR_ID or first argument.
DEFAULT_ID="AB7CA7A8-6217-4CE9-995B-3E4B72C343C1"
SIMULATOR_ID="${1:-${SIMULATOR_ID:-$DEFAULT_ID}}"

echo "Booting Simulator ($SIMULATOR_ID) in Rosetta mode..."
# Boot the simulator with x86_64 architecture. 
# We ignore errors in case it's already booted (or if we need to shutdown first).
# Note: Changing arch of an already booted simulator usually requires shutdown.
# But if it's already booted as x86_64, this does nothing.
xcrun simctl boot "$SIMULATOR_ID" --arch=x86_64 2>/dev/null

# If BOOT_ONLY is set, exit here
if [ "$BOOT_ONLY" = "true" ]; then
  echo "Simulator booted. Exiting because BOOT_ONLY=true."
  exit 0
fi

echo "Launching Flutter app..."
# Run flutter using arch -x86_64 to force the host process to run as Intel,
# which communicates properly with the Rosetta simulator.
arch -x86_64 flutter run -d "$SIMULATOR_ID"
