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

    test('complete rep cycle counts correctly', () async {
      // Use shorter timing for faster tests
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100),
        debounceTime: const Duration(milliseconds: 20),
      );

      // Get to down state
      for (int i = 0; i < 2; i++) {
        fastCounter.processPose(createArmsDownPose(timestamp: DateTime.now()));
        await Future.delayed(const Duration(milliseconds: 60));
      }
      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));

      // Complete rep: down → rising → up → falling → down
      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose());
      expect(fastCounter.state.phase, equals(LateralRaisePhase.rising));

      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsUpPose());
      expect(fastCounter.state.phase, equals(LateralRaisePhase.up));

      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose());
      expect(fastCounter.state.phase, equals(LateralRaisePhase.falling));

      await Future.delayed(
        const Duration(milliseconds: 150),
      ); // Ensure min duration
      final event = fastCounter.processPose(createArmsDownPose());

      expect(event, isA<RepCompleted>());
      expect((event as RepCompleted).totalReps, equals(1));
      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));
      expect(fastCounter.state.repCount, equals(1));
    });

    test('partial rep does not count', () async {
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 100),
      );

      // Get to down state
      for (int i = 0; i < 2; i++) {
        fastCounter.processPose(createArmsDownPose(timestamp: DateTime.now()));
        await Future.delayed(const Duration(milliseconds: 60));
      }

      // Start rising
      fastCounter.processPose(createArmsMidRaisePose());
      expect(fastCounter.state.phase, equals(LateralRaisePhase.rising));

      // Go back down without reaching top
      fastCounter.processPose(createArmsDownPose());

      // Should return to down phase without counting rep
      expect(fastCounter.state.phase, equals(LateralRaisePhase.down));
      expect(fastCounter.state.repCount, equals(0));
    });

    test('reset clears state', () async {
      final fastCounter = LateralRaiseCounter(
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100),
      );

      // Complete a rep
      for (int i = 0; i < 2; i++) {
        fastCounter.processPose(createArmsDownPose(timestamp: DateTime.now()));
        await Future.delayed(const Duration(milliseconds: 60));
      }
      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose());
      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsUpPose());
      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose());
      await Future.delayed(const Duration(milliseconds: 150));
      fastCounter.processPose(createArmsDownPose());

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
      );

      // Complete a rep
      for (int i = 0; i < 2; i++) {
        fastCounter.processPose(createArmsDownPose(timestamp: DateTime.now()));
        await Future.delayed(const Duration(milliseconds: 60));
      }
      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose());
      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsUpPose()); // This should be the peak
      await Future.delayed(const Duration(milliseconds: 50));
      fastCounter.processPose(createArmsMidRaisePose());
      await Future.delayed(const Duration(milliseconds: 150));
      final event = fastCounter.processPose(createArmsDownPose());

      expect(event, isA<RepCompleted>());
      final repEvent = event as RepCompleted;
      expect(repEvent.peakAngle, greaterThan(60)); // Should be high angle
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
      expect(frames.length, greaterThan(40), reason: 'Should have extracted enough frames');
      
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
      print('Real video angle range: ${minAngle.toStringAsFixed(1)}° - ${maxAngle.toStringAsFixed(1)}°');
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

      final avgConfidence = confidences.reduce((a, b) => a + b) / confidences.length;
      expect(avgConfidence, greaterThan(0.8), reason: 'Average confidence should be high');
      // ignore: avoid_print
      print('Average landmark confidence: ${(avgConfidence * 100).toStringAsFixed(1)}%');
    });

    test('angle progression shows clear raise pattern', () {
      final frames = realLateralRaiseFrames;
      final angles = <double>[];

      for (var frame in frames) {
        final angle = calculateAverageShoulderAngle(
          leftShoulder: frame[LandmarkId.leftShoulder],
          leftElbow: frame[LandmarkId.leftElbow],
          leftHip: frame[LandmarkId.leftHip],
          rightShoulder:  frame[LandmarkId.rightShoulder],
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
      expect(peakIndex, greaterThan(5), reason: 'Peak should not be at the very start');
      expect(peakIndex, lessThan(angles.length - 5), reason: 'Peak should not be at the very end');

     // Check that we start and end at low angles
      expect(angles.first, lessThan(25.0), reason: 'Should start with arms down');
      expect(angles.last, lessThan(25.0), reason: 'Should end with arms down');
    });
  });
}


