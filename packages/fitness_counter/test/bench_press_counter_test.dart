import 'package:test/test.dart';
import 'package:fitness_counter/fitness_counter.dart';

import 'dart:math' as math;

import 'fixtures/real_bench_press.dart';
import 'fixtures/sample_poses.dart';

void main() {
  group('BenchPressCounter', () {
    late BenchPressCounter counter;

    setUp(() {
      counter = BenchPressCounter(
        topThreshold: 160.0,
        bottomThreshold: 100.0,
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100),
        debounceTime: const Duration(milliseconds: 20),
        smoothingAlpha: 1.0, // Disable smoothing for instant pose changes
      );
    });

    // Helper to create a bench press pose
    PoseFrame createBenchPressPose(double elbowAngle, {DateTime? timestamp}) {
      final double sX = 0.3, sY = 0.5;
      final double eX = 0.1, eY = 0.5;

      // Calculate wrist position to create exact elbowAngle
      final radian = elbowAngle * math.pi / 180.0;

      // upperArm vector (shoulder - elbow) is (0.2, 0), so it points strictly right.
      // To get `elbowAngle` between upperArm and foreArm, foreArm (wrist - elbow)
      // should point at `radian` relative to the upperArm.
      final wX = eX + math.cos(radian) * 0.2;
      final wY = eY - math.sin(radian) * 0.2;

      return createPoseFrame({
        LandmarkId.leftShoulder: (sX, sY),
        LandmarkId.leftElbow: (eX, eY),
        LandmarkId.leftWrist: (wX, wY),
        LandmarkId.rightShoulder: (1.0 - sX, sY),
        LandmarkId.rightElbow: (1.0 - eX, eY),
        LandmarkId.rightWrist: (1.0 - wX, wY),
      }, timestamp: timestamp);
    }

    test('initial state is waiting with 0 reps', () {
      expect(counter.state.repCount, equals(0));
      expect(counter.state.phase, equals(BenchPressPhase.waiting));
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
          LandmarkId.leftWrist,
          LandmarkId.rightWrist,
        ]),
      );
    });

    test('skips frames with incomplete landmarks', () {
      final incompletePose = createIncompletePose();
      final event = counter.processPose(incompletePose);
      expect(event, isNull);
    });

    test('complete rep cycle counts correctly (phase transitions)', () {
      final counter = BenchPressCounter(
        topThreshold: 160.0,
        bottomThreshold: 100.0,
        readyHoldTime: const Duration(milliseconds: 100),
        minRepDuration: const Duration(milliseconds: 100), // very short
        debounceTime: const Duration(milliseconds: 10),
        smoothingAlpha: 1.0, // Disabled smoothing
        smoothingWarmupFrames: 0, // Disable warmup
      );

      var time = DateTime.fromMillisecondsSinceEpoch(1000000);

      // Phase 1: waiting -> up (needs arms high for 100ms)
      counter.processPose(
        createBenchPressPose(170.0, timestamp: time),
      ); // High angle, starts hold
      time = time.add(const Duration(milliseconds: 150));
      counter.processPose(
        createBenchPressPose(170.0, timestamp: time),
      ); // Exceeds readyHoldTime

      expect(counter.state.phase, equals(BenchPressPhase.up));

      // Phase 2: up -> falling
      time = time.add(const Duration(milliseconds: 50));
      counter.processPose(
        createBenchPressPose(150.0, timestamp: time),
      ); // Drops below 155 (fallingThreshold is top - 5 = 155)
      expect(counter.state.phase, equals(BenchPressPhase.falling));

      // Phase 3: falling -> down
      time = time.add(const Duration(milliseconds: 50));
      counter.processPose(
        createBenchPressPose(90.0, timestamp: time),
      ); // Reaches bottom (100)
      expect(counter.state.phase, equals(BenchPressPhase.down));

      // Phase 4: down -> rising
      time = time.add(const Duration(milliseconds: 50));
      counter.processPose(
        createBenchPressPose(110.0, timestamp: time),
      ); // Rises above 105 (risingThreshold is bottom + 5 = 105)
      expect(counter.state.phase, equals(BenchPressPhase.rising));

      // Phase 5: rising -> up (COMPLETES REP)
      time = time.add(const Duration(milliseconds: 50));
      final event = counter.processPose(
        createBenchPressPose(170.0, timestamp: time),
      ); // Back to top

      expect(event, isA<RepCompleted>());
      expect(counter.state.repCount, equals(1));
      expect(counter.state.phase, equals(BenchPressPhase.up));
    });
  });

  group('BenchPressCounter with real video data', () {
    test('real video data timestamps do not break phase changes', () {
      final counter = BenchPressCounter(
        topThreshold: 160.0,
        bottomThreshold: 100.0,
      );
      final frames = realBenchPressFrames.map((frame) {
        final newLandmarks = Map<LandmarkId, Landmark>.from(frame.landmarks);
        for (final id in counter.requiredLandmarks) {
          if (newLandmarks.containsKey(id)) {
            final l = newLandmarks[id]!;
            newLandmarks[id] = Landmark(
              x: l.x,
              y: l.y,
              z: l.z,
              confidence: 1.0,
            );
          }
        }
        return frame.copyWith(landmarks: newLandmarks);
      }).toList();

      for (var frame in frames) {
        counter.processPose(frame);
      }

      // Should have successfully moved out of 'waiting' because the video features active pressing
      expect(counter.state.phase, isNot(equals(BenchPressPhase.waiting)));
    });
  });
}
