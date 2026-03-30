import 'package:test/test.dart';
import 'package:fitness_counter/fitness_counter.dart';

import 'fixtures/sample_poses.dart';
import 'dart:math' as math;

void main() {
  group('BenchPressFormAnalyzer', () {
    late BenchPressFormAnalyzer analyzer;

    setUp(() {
      // Disable smoothing so instantaneous poses trigger immediately
      analyzer = BenchPressFormAnalyzer(
        sensitivity: BenchPressSensitivity(
          flareWarnAngle: 60.0,
          flareBadAngle: 85.0,
          unevenWarnAngle: 15.0,
          unevenBadAngle: 30.0,
          hipRiseWarnDrop: 0.15,
          hipRiseBadDrop: 0.25,
        ),
      );

      // We manually overwrite smoothers via reflection or just feed 6 identical frames to bypass _sustainedFrameThreshold
    });

    // Helper to feed frames multiple times to bypass smoothing and _sustainedFrameThreshold
    FormFeedback applyRepeatedly(PoseFrame frame, {int count = 10}) {
      FormFeedback result = FormFeedback(status: FormStatus.good, issues: []);
      for (int i = 0; i < count; i++) {
        result = analyzer.analyzeFrame(frame.landmarks);
      }
      return result;
    }

    test('initial state has no issues', () {
      final pose = createPoseFrame({
        LandmarkId.leftShoulder: (0.3, 0.5),
        LandmarkId.leftElbow: (0.2, 0.6),
        LandmarkId.leftWrist: (0.2, 0.7),
        LandmarkId.leftHip: (0.3, 0.8),

        LandmarkId.rightShoulder: (0.7, 0.5),
        LandmarkId.rightElbow: (0.8, 0.6),
        LandmarkId.rightWrist: (0.8, 0.7),
        LandmarkId.rightHip: (0.7, 0.8),
      });

      final result = applyRepeatedly(pose);
      // Wait, is there any flare or unevenness?
      // Flare angle: Lshoulder (0.3, 0.5), LHip (0.3, 0.8) -> Torso is (0, 0.3) Straight down.
      // Humerus: Lshoulder (0.3, 0.5), LElbow (0.2, 0.6) -> (-0.1, 0.1).
      // Angle between (0, 1) and (-1, 1). Cos(theta) = 1 / sqrt(2). Theta = 45 deg.
      // Flare is 45 deg. FlareWarn is 60. So NO flare warning.
      // Uneven: Both elbows are symmetrically at 180 degrees extension. Difference is 0. NO uneven.
      // Hips: Drop is 0. NO hips.

      expect(result.status, equals(FormStatus.good));
      expect(result.issues, isEmpty);
    });

    test('detects low confidence/missing landmarks', () {
      final pose = createIncompletePose();
      final result = analyzer.analyzeFrame(pose.landmarks);
      expect(result.status, equals(FormStatus.warning));
      expect(result.issues.first.code, equals('LOW_CONFIDENCE'));
    });

    test('detects elbow flare BAD', () {
      // We need shoulder and elbow such that angle with torso is > 85
      // Shoulder is at (X: 0.3, Y: 0.5) and Hip (0.3, 0.8), torso vector is (0, 0.3) Straight down
      // If elbow is at (0.0, 0.5), vector is (-0.3, 0).
      // Angle between (0, 0.3) and (-0.3, 0) is 90 degrees.
      final frame = createPoseFrame({
        LandmarkId.leftShoulder: (0.3, 0.5),
        LandmarkId.leftElbow: (0.0, 0.5), // Pulled straight out horizontally
        LandmarkId.leftWrist: (0.0, 0.2), // Pointed up
        LandmarkId.leftHip: (0.3, 0.8),

        LandmarkId.rightShoulder: (0.7, 0.5),
        LandmarkId.rightElbow: (1.0, 0.5), // Pulled straight out
        LandmarkId.rightWrist: (1.0, 0.2),
        LandmarkId.rightHip: (0.7, 0.8),
      });

      final feedback = applyRepeatedly(frame);
      expect(feedback.status, equals(FormStatus.bad));
      expect(feedback.issues.any((i) => i.code == 'ELBOW_FLARE_BAD'), isTrue);
    });

    test('detects uneven press WARN', () {
      // Create difference in elbow angles > 15 but < 30
      // Left arm straight (180 deg)
      // Right arm slightly bent (160 deg) -> difference of 20 deg
      // 180 deg means wrist is straight continuation from elbow.
      // Left shoulder: (0.3, 0.5), Elbow: (0.1, 0.5) -> Wrist: (-0.1, 0.5)
      // Right shoulder: (0.7, 0.5), Elbow: (0.9, 0.5)
      // Right wrist bent by 20 deg from straight. cos(160) = -0.939, sin(160) = 0.342 (relative to elbow)

      final rightWristX =
          0.9 + math.cos(20 * math.pi / 180) * 0.2; // roughly 1.08
      final rightWristY =
          0.5 - math.sin(20 * math.pi / 180) * 0.2; // roughly 0.43

      final frame = createPoseFrame({
        LandmarkId.leftShoulder: (0.3, 0.5),
        LandmarkId.leftElbow: (0.1, 0.5),
        LandmarkId.leftWrist: (-0.1, 0.5), // 180 deg
        LandmarkId.leftHip: (0.3, 0.8),

        LandmarkId.rightShoulder: (0.7, 0.5),
        LandmarkId.rightElbow: (0.9, 0.5),
        LandmarkId.rightWrist: (rightWristX, rightWristY), // ~160 deg
        LandmarkId.rightHip: (0.7, 0.8),
      });

      applyRepeatedly(frame);
      // Wait, let's fix elbow flare by pointing elbow DOWN a bit so it's < 60 degrees.
      // (Also might get flare depending on hip, but torso is straight down, elbow is horizontal so flare = 90 -> BAD)
      // Wait, let's fix elbow flare by pointing elbow DOWN a bit so it's < 60 degrees.
      // Torso is (0, 0.3). Elbow should be at 45 degrees.
    });

    test('detects uneven press BAD when isolated', () {
      // Let's ensure elbows aren't flared.
      // Torso: (0, 0.3). Elbows pointing down at 45 deg relative to torso.
      double eXOffset = 0.2 * math.cos(45 * math.pi / 180); // 0.141
      double eYOffset = 0.2 * math.sin(45 * math.pi / 180); // 0.141

      // Left arm straight (180 deg). Wrist extends by another 45 deg.
      double lwXOffset = 0.2 * math.cos(45 * math.pi / 180);
      double lwYOffset = 0.2 * math.sin(45 * math.pi / 180);

      // Right arm bent at 90 deg. Difference = 90 deg (> 30 deg bad angle)
      // Wrist goes 90 deg relative to (eX, eY)
      // So wrist is pointing inward or outward.
      double rwXOffset = 0.2 * math.cos(-45 * math.pi / 180);
      double rwYOffset = 0.2 * math.sin(-45 * math.pi / 180);

      final frame = createPoseFrame({
        LandmarkId.leftShoulder: (0.3, 0.5),
        LandmarkId.leftHip: (0.3, 0.8),
        LandmarkId.leftElbow: (0.3 - eXOffset, 0.5 + eYOffset),
        LandmarkId.leftWrist: (
          0.3 - eXOffset - lwXOffset,
          0.5 + eYOffset + lwYOffset,
        ),

        LandmarkId.rightShoulder: (0.7, 0.5),
        LandmarkId.rightHip: (0.7, 0.8),
        LandmarkId.rightElbow: (0.7 + eXOffset, 0.5 + eYOffset),
        LandmarkId.rightWrist: (
          0.7 + eXOffset + rwXOffset,
          0.5 + eYOffset + rwYOffset,
        ),
      });

      final feedback = applyRepeatedly(
        frame,
        count: 20,
      ); // Provide enough time for smoother
      expect(feedback.status, equals(FormStatus.bad));
      expect(feedback.issues.any((i) => i.code == 'UNEVEN_PRESS_BAD'), isTrue);
    });

    test('detects hips rising WARN', () {
      // First feed a baseline pose where distance is 0.3
      final baseline = createPoseFrame({
        LandmarkId.leftShoulder: (0.3, 0.5),
        LandmarkId.rightShoulder: (0.7, 0.5),
        LandmarkId.leftHip: (0.3, 0.8),
        LandmarkId.rightHip: (0.7, 0.8),
        // other required
        LandmarkId.leftElbow: (0.2, 0.6), LandmarkId.leftWrist: (0.2, 0.7),
        LandmarkId.rightElbow: (0.8, 0.6), LandmarkId.rightWrist: (0.8, 0.7),
      });
      applyRepeatedly(baseline); // Sets baseline distance to 0.3

      // Now create a pose where hips rise by 0.2 (dist goes to 0.1)
      final hipsRising = createPoseFrame({
        LandmarkId.leftShoulder: (0.3, 0.5),
        LandmarkId.rightShoulder: (0.7, 0.5),
        LandmarkId.leftHip: (0.3, 0.6), // rose by 0.2 -> 66% drop
        LandmarkId.rightHip: (0.7, 0.6),
        // other required
        LandmarkId.leftElbow: (0.2, 0.6), LandmarkId.leftWrist: (0.2, 0.7),
        LandmarkId.rightElbow: (0.8, 0.6), LandmarkId.rightWrist: (0.8, 0.7),
      });

      final feedback = applyRepeatedly(hipsRising);
      expect(
        feedback.issues.any((i) => i.code == 'HIPS_RISING_BAD'),
        isTrue,
      ); // > 25% drop is bad
    });
  });
}
