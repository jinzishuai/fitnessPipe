#!/bin/bash

# Run Maestro tests in headless mode and generate JUnit report
# Requires maestro to be installed and in PATH

mkdir -p maestro-report

echo "Running Maestro tests..."
maestro test maestro-test/ios-flow.yaml

# Check exit code
if [ $? -eq 0 ]; then
  echo "Maestro tests passed!"
  exit 0
else
  echo "Maestro tests failed!"
  exit 1
fi
