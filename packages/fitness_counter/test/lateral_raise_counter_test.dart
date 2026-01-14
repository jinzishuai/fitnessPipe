import 'package:test/test.dart';
import 'package:fitness_counter/fitness_counter.dart';

import 'fixtures/sample_poses.dart';
import 'fixtures/real_lateral_raise.dart';

void main() {
  group('LateralRaiseCounter', () {
    late LateralRaiseCounter counter;

    setUp(() {
      counter = LateralRaiseCounter();
    });

    test('initial state is waiting with 0 reps', () {
      expect(counter.state.repCount, equals(0));
      expect(counter.state.phase, equals(LateralRaisePhase.waiting));
    });

    test('requires all 6 landmarks', () {
      expect(counter.requiredLandmarks, hasLength(6));
      expect(
        counter.requiredLandmarks,
        containsAll([
          LandmarkId.leftShoulder,
          LandmarkId.rightShoulder,
          LandmarkId.leftElbow,
          LandmarkId.rightElbow,
          LandmarkId.leftHip,
          LandmarkId.rightHip,
        ]),
      );
    });

    test('skips frames with incomplete landmarks', () {
      final incompletePose = createIncompletePose();

      final event = counter.processPose(incompletePose);

      expect(event, isNull);
    });

    test('transitions from waiting to down after holding arms down', () async {
      // Use shorter hold time for testing
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 200),
      );

      // Process frames for 300ms (readyHoldTime is 200ms)
      for (int i = 0; i < 4; i++) {
        fastCounter.processPose(createArmsDownPose(timestamp: DateTime.now()));
        if (i < 3) await Future.delayed(const Duration(milliseconds: 100));
      }

      // Should transition to down
      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));
    });

    // Helper to create a pose with ~50 degrees (between 25 and 75) to trigger falling state
    PoseFrame createArmsFallingPose({DateTime? timestamp}) {
      return createPoseFrame({
        // Left side
        LandmarkId.leftShoulder: (0.3, 0.3),
        LandmarkId.leftElbow: (0.2, 0.45),
        LandmarkId.leftHip: (0.35, 0.7),

        // Right side (mirror)
        LandmarkId.rightShoulder: (0.7, 0.3),
        LandmarkId.rightElbow: (0.8, 0.45),
        LandmarkId.rightHip: (0.65, 0.7),
      }, timestamp: timestamp);
    }

    test('complete rep cycle counts correctly', () async {
      // Use shorter timing for faster tests and disable smoothing for synthetic data
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100),
        debounceTime: const Duration(milliseconds: 20),
        smoothingAlpha: 1.0, // Disable smoothing for instant pose changes
      );

      // Use incrementing timestamps to simulate time passing
      var currentTime = DateTime.now();

      // Get to down state - need to hold for readyHoldTime (100ms)
      // Frame 1 at 0ms
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));

      // Frame 2 at 60ms
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));

      // Frame 3 at 120ms - transitions to down
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));

      // Complete rep: down → rising → up → falling → down
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose(timestamp: currentTime));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.rising));

      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsUpPose(timestamp: currentTime));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.up));

      // Use falling pose (~50 degrees) which is < fallingThreshold (75)
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsFallingPose(timestamp: currentTime));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.falling));

      currentTime = currentTime.add(const Duration(milliseconds: 50));
      final event = fastCounter.processPose(
        createArmsDownPose(timestamp: currentTime),
      );

      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));
      expect(fastCounter.state.repCount, equals(1));
      expect(event, isA<RepCompleted>());
    });

    test('partial rep does not count', () async {
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100),
        debounceTime: const Duration(milliseconds: 20),
        smoothingAlpha: 1.0,
      );

      var currentTime = DateTime.now();

      // Get to down state (3 frames)
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));

      // Partial rep: down -> rising -> falling (no up) -> down
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose(timestamp: currentTime));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.rising));

      // Go back down directly (abort rep)
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));

      // Should be back to down state but rep count 0
      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));
      expect(fastCounter.state.repCount, equals(0));
    });

    test('reset clears state', () async {
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100),
        debounceTime: const Duration(milliseconds: 20),
        smoothingAlpha: 1.0,
      );

      var currentTime = DateTime.now();

      // Perform one rep
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));

      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsUpPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsFallingPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));

      expect(fastCounter.state.repCount, equals(1));

      // Reset
      fastCounter.reset();
      expect(fastCounter.state.repCount, equals(0));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.waiting));
    });

    test('tracks peak angle during rep', () async {
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100),
        debounceTime: const Duration(milliseconds: 20),
        smoothingAlpha: 1.0,
      );

      var currentTime = DateTime.now();

      // Get to down state
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 60));
      fastCounter.processPose(createArmsDownPose(timestamp: currentTime));

      // Mid raise
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose(timestamp: currentTime));

      // Up - create a custom pose with 85 degrees
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsUpPose(timestamp: currentTime));

      // Finish rep
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsFallingPose(timestamp: currentTime));
      currentTime = currentTime.add(const Duration(milliseconds: 50));
      final event = fastCounter.processPose(
        createArmsDownPose(timestamp: currentTime),
      );

      expect(event, isA<RepCompleted>());
      final completion = event as RepCompleted;
      // Peak angle should be around 85 degrees (allow some variance)
      expect(completion.peakAngle, greaterThan(80.0));
    });

    test('smoothing reduces jitter', () {
      final downPose1 = createArmsDownPose();
      final downPose2 = createArmsMidRaisePose();

      // Process alternating poses (simulating jitter)
      counter.processPose(downPose1);
      final angle1 = counter.state.smoothedAngle;

      counter.processPose(downPose2);
      final angle2 = counter.state.smoothedAngle;

      counter.processPose(downPose1);
      final angle3 = counter.state.smoothedAngle;

      // Smoothed angles should not jump as much as raw angles would
      // The third smoothed angle should be between first and second
      expect(angle3, lessThan(angle2));
      expect(angle3, greaterThan(angle1));
    });
  });

  group('LateralRaiseCounter with real video data', () {
    test('real video data is loaded correctly', () {
      final frames = realLateralRaiseFrames;
      final metadata = realLateralRaiseMetadata;

      // Verify fixture was generated
      expect(frames, isNotEmpty);
      expect(
        frames.length,
        greaterThan(40),
        reason: 'Should have extracted enough frames',
      );

      // Verify metadata
      expect(metadata['source_video'], equals('LateralRaise_One_Rep.mp4'));
      expect(metadata['duration_seconds'], greaterThan(2.5));
      expect(metadata['duration_seconds'], lessThan(4.0));
      expect(metadata['frames_with_pose'], equals(frames.length));
    });

    test('real video frames have all required landmarks', () {
      final frames = realLateralRaiseFrames;
      final requiredLandmarks = {
        LandmarkId.leftShoulder,
        LandmarkId.rightShoulder,
        LandmarkId.leftElbow,
        LandmarkId.rightElbow,
        LandmarkId.leftHip,
        LandmarkId.rightHip,
      };

      for (var i = 0; i < frames.length; i++) {
        final frame = frames[i];
        expect(
          frame.hasLandmarks(requiredLandmarks),
          isTrue,
          reason: 'Frame $i should have all required landmarks',
        );
      }
    });

    test('calculated angles match expected 10-65 degree range', () {
      final frames = realLateralRaiseFrames;
      final angles = <double>[];

      // Calculate angles for all frames
      for (var frame in frames) {
        final angle = calculateAverageShoulderAngle(
          leftShoulder: frame[LandmarkId.leftShoulder],
          leftElbow: frame[LandmarkId.leftElbow],
          leftHip: frame[LandmarkId.leftHip],
          rightShoulder: frame[LandmarkId.rightShoulder],
          rightElbow: frame[LandmarkId.rightElbow],
          rightHip: frame[LandmarkId.rightHip],
        );
        if (angle > 0) {
          angles.add(angle);
        }
      }

      expect(angles, isNotEmpty);
      final minAngle = angles.reduce((a, b) => a < b ? a : b);
      final maxAngle = angles.reduce((a, b) => a > b ? a : b);

      // Video analysis showed: 10.8° - 64.4° range
      expect(minAngle, greaterThan(5.0), reason: 'Min angle should be > 5°');
      expect(minAngle, lessThan(20.0), reason: 'Min angle should be < 20°');
      expect(maxAngle, greaterThan(55.0), reason: 'Max angle should be > 55°');
      expect(maxAngle, lessThan(75.0), reason: 'Max angle should be < 75°');

      // ignore: avoid_print
      print(
        'Real video angle range: ${minAngle.toStringAsFixed(1)}° - ${maxAngle.toStringAsFixed(1)}°',
      );
    });

    test('landmark confidence scores are high', () {
      final frames = realLateralRaiseFrames;
      final confidences = <double>[];

      for (var frame in frames) {
        for (var landmarkId in [
          LandmarkId.leftShoulder,
          LandmarkId.rightShoulder,
          LandmarkId.leftElbow,
          LandmarkId.rightElbow,
          LandmarkId.leftHip,
          LandmarkId.rightHip,
        ]) {
          final landmark = frame[landmarkId];
          if (landmark != null) {
            confidences.add(landmark.confidence);
          }
        }
      }

      final avgConfidence =
          confidences.reduce((a, b) => a + b) / confidences.length;
      expect(
        avgConfidence,
        greaterThan(0.8),
        reason: 'Average confidence should be high',
      );
      // ignore: avoid_print
      print(
        'Average landmark confidence: ${(avgConfidence * 100).toStringAsFixed(1)}%',
      );
    });

    test('angle progression shows clear raise pattern', () {
      final frames = realLateralRaiseFrames;
      final angles = <double>[];

      for (var frame in frames) {
        final angle = calculateAverageShoulderAngle(
          leftShoulder: frame[LandmarkId.leftShoulder],
          leftElbow: frame[LandmarkId.leftElbow],
          leftHip: frame[LandmarkId.leftHip],
          rightShoulder: frame[LandmarkId.rightShoulder],
          rightElbow: frame[LandmarkId.rightElbow],
          rightHip: frame[LandmarkId.rightHip],
        );
        angles.add(angle);
      }

      // Find the peak
      final maxAngle = angles.reduce((a, b) => a > b ? a : b);
      final peakIndex = angles.indexOf(maxAngle);

      // First half should generally be increasing (arms going up)
      // Second half should generally be decreasing (arms going down)
      expect(
        peakIndex,
        greaterThan(5),
        reason: 'Peak should not be at the very start',
      );
      expect(
        peakIndex,
        lessThan(angles.length - 5),
        reason: 'Peak should not be at the very end',
      );

      // Check that we start and end at low angles
      expect(
        angles.first,
        lessThan(25.0),
        reason: 'Should start with arms down',
      );
      expect(angles.last, lessThan(25.0), reason: 'Should end with arms down');
    });
  });
}
