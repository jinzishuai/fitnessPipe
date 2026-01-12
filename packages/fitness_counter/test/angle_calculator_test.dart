import 'package:test/test.dart';
import 'package:fitness_counter/fitness_counter.dart';

void main() {
  group('calculateShoulderAngle', () {
    test('returns 0 degrees for arms straight down (aligned with torso)', () {
      final shoulder = Landmark(x: 0.5, y: 0.3, confidence: 1.0);
      final elbow = Landmark(x: 0.5, y: 0.5, confidence: 1.0); // Straight down
      final hip = Landmark(x: 0.5, y: 0.7, confidence: 1.0);

      final angle = calculateShoulderAngle(
        shoulder: shoulder,
        elbow: elbow,
        hip: hip,
      );

      expect(angle, closeTo(0, 1.0)); // Within 1 degree
    });

    test('returns ~90 degrees for arms horizontal', () {
      final shoulder = Landmark(x: 0.5, y: 0.3, confidence: 1.0);
      final elbow = Landmark(x: 0.3, y: 0.3, confidence: 1.0); // Horizontal
      final hip = Landmark(x: 0.5, y: 0.7, confidence: 1.0);

      final angle = calculateShoulderAngle(
        shoulder: shoulder,
        elbow: elbow,
        hip: hip,
      );

      expect(angle, closeTo(90, 2.0)); // Within 2 degrees
    });

    test('returns ~45 degrees for arms halfway raised', () {
      final shoulder = Landmark(x: 0.5, y: 0.3, confidence: 1.0);
      
      // 45 degree angle: elbow is offset by same amount in x and y
      final offset = 0.1;
      final elbow = Landmark(
        x: 0.5 - offset, 
        y: 0.3 + offset, 
        confidence: 1.0,
      );
      final hip = Landmark(x: 0.5, y: 0.7, confidence: 1.0);

      final angle = calculateShoulderAngle(
        shoulder: shoulder,
        elbow: elbow,
        hip: hip,
      );

      expect(angle, closeTo(45, 5.0)); // Within 5 degrees (rough estimate)
    });

    test('handles edge case of zero-length arm vector', () {
      final shoulder = Landmark(x: 0.5, y: 0.3, confidence: 1.0);
      final elbow = Landmark(x: 0.5, y: 0.3, confidence: 1.0); // Same as shoulder
      final hip = Landmark(x: 0.5, y: 0.7, confidence: 1.0);

      final angle = calculateShoulderAngle(
        shoulder: shoulder,
        elbow: elbow,
        hip: hip,
      );

      expect(angle, equals(0.0)); // Should return 0 for invalid data
    });

    test('handles edge case of zero-length torso vector', () {
      final shoulder = Landmark(x: 0.5, y: 0.3, confidence: 1.0);
      final elbow = Landmark(x: 0.3, y: 0.3, confidence: 1.0);
      final hip = Landmark(x: 0.5, y: 0.3, confidence: 1.0); // Same as shoulder

      final angle = calculateShoulderAngle(
        shoulder: shoulder,
        elbow: elbow,
        hip: hip,
      );

      expect(angle, equals(0.0)); // Should return 0 for invalid data
    });
  });

  group('calculateAverageShoulderAngle', () {
    test('returns average when both arms visible', () {
      // Left arm at 30 degrees, right arm at 50 degrees
      final leftShoulder = Landmark(x: 0.3, y: 0.3, confidence: 1.0);
      final leftElbow = Landmark(x: 0.25, y: 0.4, confidence: 1.0);
      final leftHip = Landmark(x: 0.35, y: 0.7, confidence: 1.0);

      final rightShoulder = Landmark(x: 0.7, y: 0.3, confidence: 1.0);
      final rightElbow = Landmark(x: 0.8, y: 0.35, confidence: 1.0);
      final rightHip = Landmark(x: 0.65, y: 0.7, confidence: 1.0);

      final average = calculateAverageShoulderAngle(
        leftShoulder: leftShoulder,
        leftElbow: leftElbow,
        leftHip: leftHip,
        rightShoulder: rightShoulder,
        rightElbow: rightElbow,
        rightHip: rightHip,
      );

      // Should be average of the two angles
      expect(average, greaterThan(0));
    });

    test('returns left angle when only left arm visible', () {
      final leftShoulder = Landmark(x: 0.3, y: 0.3, confidence: 1.0);
      final leftElbow = Landmark(x: 0.15, y: 0.32, confidence: 1.0); // Nearly horizontal
      final leftHip = Landmark(x: 0.35, y: 0.7, confidence: 1.0);

      final average = calculateAverageShoulderAngle(
        leftShoulder: leftShoulder,
        leftElbow: leftElbow,
        leftHip: leftHip,
      );

      expect(average, greaterThan(70)); // Should be high angle (arm out)
    });

    test('returns right angle when only right arm visible', () {
      final rightShoulder = Landmark(x: 0.7, y: 0.3, confidence: 1.0);
      final rightElbow = Landmark(x: 0.85, y: 0.32, confidence: 1.0); // Nearly horizontal
      final rightHip = Landmark(x: 0.65, y: 0.7, confidence: 1.0);

      final average = calculateAverageShoulderAngle(
        rightShoulder: rightShoulder,
        rightElbow: rightElbow,
        rightHip: rightHip,
      );

      expect(average, greaterThan(70)); // Should be high angle (arm out)
    });

    test('returns 0 when no arms visible', () {
      final average = calculateAverageShoulderAngle();
      expect(average, equals(0.0));
    });
  });
}
