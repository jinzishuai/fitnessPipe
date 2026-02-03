#!/bin/bash

# Use Java 17 for the build (compatible with Gradle)
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

echo "Using JAVA_HOME: $JAVA_HOME"
java -version

echo "Starting Flutter App..."
flutter run
