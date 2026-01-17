#!/bin/bash

# Run Maestro tests in headless mode and generate JUnit report
# Requires maestro to be installed and in PATH

mkdir -p maestro-report

echo "Running Maestro tests..."
# --format junit writes the report to the specified output file
# standard output still shows progress
CMD="maestro test --format junit --output maestro-report/report.xml"

# If SIMULATOR_ID is set (e.g. from CI), target that specific device
if [ -n "$SIMULATOR_ID" ]; then
    echo "Targeting specific device: $SIMULATOR_ID"
    CMD="$CMD --device $SIMULATOR_ID"
fi

# Increase driver startup timeout for CI/Rosetta environments (default is 15000ms)
export MAESTRO_DRIVER_STARTUP_TIMEOUT=60000

$CMD maestro-test/ios-flow.yaml

# Check exit code
if [ $? -eq 0 ]; then
  echo "Maestro tests passed!"
  exit 0
else
  echo "Maestro tests failed!"
  exit 1
fi
