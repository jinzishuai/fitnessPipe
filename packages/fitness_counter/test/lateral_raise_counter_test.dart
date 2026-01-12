import 'package:test/test.dart';
import 'package:fitness_counter/fitness_counter.dart';

import 'fixtures/sample_poses.dart';

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
      final downPose = createArmsDownPose();
      
      // Process frames for 300ms (readyHoldTime is 200ms)
      for (int i = 0; i < 4; i++) {
        fastCounter.processPose(createArmsDownPose(
          timestamp: DateTime.now(),
        ));
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
      
      await Future.delayed(const Duration(milliseconds: 150)); // Ensure min duration
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
}
