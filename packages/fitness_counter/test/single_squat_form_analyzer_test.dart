import 'package:test/test.dart';
import 'package:fitness_counter/fitness_counter.dart';

import 'fixtures/real_single_squat.dart';

void main() {
  group('SingleSquatFormAnalyzer', () {
    late SingleSquatFormAnalyzer analyzer;

    setUp(() {
      analyzer = SingleSquatFormAnalyzer();
    });

    // ── Helper: create a landmarks map ────────────────────────────────────
    Map<LandmarkId, Landmark> _makeLandmarks({
      // Shoulder positions (for trunk lean)
      double lShoulderX = 0.56,
      double lShoulderY = 0.28,
      double rShoulderX = 0.48,
      double rShoulderY = 0.28,
      // Hip positions
      double lHipX = 0.55,
      double lHipY = 0.50,
      double rHipX = 0.50,
      double rHipY = 0.50,
      // Knee positions
      double lKneeX = 0.57,
      double lKneeY = 0.68,
      double rKneeX = 0.49,
      double rKneeY = 0.68,
      // Ankle positions
      double lAnkleX = 0.59,
      double lAnkleY = 0.84,
      double rAnkleX = 0.47,
      double rAnkleY = 0.84,
    }) {
      return {
        LandmarkId.leftShoulder: Landmark(
          x: lShoulderX,
          y: lShoulderY,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.rightShoulder: Landmark(
          x: rShoulderX,
          y: rShoulderY,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.leftHip: Landmark(
          x: lHipX,
          y: lHipY,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.rightHip: Landmark(
          x: rHipX,
          y: rHipY,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.leftKnee: Landmark(
          x: lKneeX,
          y: lKneeY,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.rightKnee: Landmark(
          x: rKneeX,
          y: rKneeY,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.leftAnkle: Landmark(
          x: lAnkleX,
          y: lAnkleY,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.rightAnkle: Landmark(
          x: rAnkleX,
          y: rAnkleY,
          z: 0,
          confidence: 0.99,
        ),
      };
    }

    // ── Good Form Tests ──────────────────────────────────────────────────

    test('returns good status for proper form', () {
      // Good form: upright trunk, knees over toes, straight legs
      final landmarks = _makeLandmarks();
      final feedback = analyzer.analyzeFrame(landmarks);
      expect(feedback.status, equals(FormStatus.good));
      expect(feedback.issues, isEmpty);
    });

    test('returns warning for missing landmarks', () {
      final feedback = analyzer.analyzeFrame({});
      expect(feedback.status, equals(FormStatus.warning));
      expect(feedback.issues.first.code, equals('LOW_CONFIDENCE'));
    });

    test('returns warning for low-confidence landmarks', () {
      final landmarks = {
        LandmarkId.leftShoulder: Landmark(
          x: 0.5,
          y: 0.3,
          z: 0,
          confidence: 0.3,
        ),
        LandmarkId.rightShoulder: Landmark(
          x: 0.5,
          y: 0.3,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.leftHip: Landmark(
          x: 0.5,
          y: 0.5,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.rightHip: Landmark(
          x: 0.5,
          y: 0.5,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.leftKnee: Landmark(
          x: 0.5,
          y: 0.7,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.rightKnee: Landmark(
          x: 0.5,
          y: 0.7,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.leftAnkle: Landmark(
          x: 0.5,
          y: 0.9,
          z: 0,
          confidence: 0.99,
        ),
        LandmarkId.rightAnkle: Landmark(
          x: 0.5,
          y: 0.9,
          z: 0,
          confidence: 0.99,
        ),
      };
      final feedback = analyzer.analyzeFrame(landmarks);
      expect(feedback.status, equals(FormStatus.warning));
      expect(feedback.issues.first.code, equals('LOW_CONFIDENCE'));
    });

    // ── Knee Valgus Tests ────────────────────────────────────────────────

    test('detects knee valgus warning after sustained frames', () {
      // hipDist = |0.55 - 0.50| = 0.05
      // For warnRatio = 0.08: kneeDist must be < 0.05 * (1-0.08) = 0.046
      // lKnee=0.523, rKnee=0.497 → kneeDist = 0.026 → ratio = 1-0.026/0.05 = 0.48 → BAD
      // For milder: lKnee=0.535, rKnee=0.49 → dist = 0.045 → ratio = 1-0.045/0.05 = 0.10 → WARN
      final landmarks = _makeLandmarks(lKneeX: 0.535, rKneeX: 0.49);

      // Need sustained frames (6+) to trigger warning
      FormFeedback feedback = const FormFeedback(status: FormStatus.good);
      for (int i = 0; i < 10; i++) {
        feedback = analyzer.analyzeFrame(landmarks);
      }

      expect(
        feedback.issues.any((i) => i.code == 'KNEE_VALGUS_WARN'),
        isTrue,
        reason: 'Should warn about knee valgus after sustained frames',
      );
    });

    test('detects knee valgus bad immediately', () {
      // hipDist = 0.05
      // For badRatio = 0.15: kneeDist must be < 0.05 * (1-0.15) = 0.0425
      // lKnee=0.52, rKnee=0.50 → dist = 0.02 → ratio = 1-0.02/0.05 = 0.60 → BAD
      final landmarks = _makeLandmarks(lKneeX: 0.52, rKneeX: 0.50);

      // Feed multiple frames so smoother converges
      FormFeedback feedback = const FormFeedback(status: FormStatus.good);
      for (int i = 0; i < 10; i++) {
        feedback = analyzer.analyzeFrame(landmarks);
      }

      expect(
        feedback.issues.any((i) => i.code == 'KNEE_VALGUS_BAD'),
        isTrue,
        reason: 'Should flag bad knee valgus for extreme inward collapse',
      );
    });

    test('no knee valgus warning for good alignment', () {
      // Knees tracking nicely over ankles
      final landmarks = _makeLandmarks(lKneeX: 0.59, rKneeX: 0.47);
      FormFeedback feedback = const FormFeedback(status: FormStatus.good);
      for (int i = 0; i < 10; i++) {
        feedback = analyzer.analyzeFrame(landmarks);
      }

      expect(
        feedback.issues.any(
          (i) =>
              i.code == 'KNEE_VALGUS_WARN' || i.code == 'KNEE_VALGUS_BAD',
        ),
        isFalse,
        reason: 'Should not flag valgus when knees are over ankles',
      );
    });

    // ── Trunk Lean Tests ─────────────────────────────────────────────────

    test('detects trunk lean warning after sustained frames', () {
      // Create trunk lean of ~35°:
      // tan(35°) = 0.700 → dx = 0.700 * dy
      // dy = |0.28 - 0.50| = 0.22 → dx = 0.154
      // shoulder centerX = 0.525 + 0.154 = 0.679
      // lShoulder = 0.719, rShoulder = 0.639 → center = 0.679
      final landmarks = _makeLandmarks(
        lShoulderX: 0.72,
        rShoulderX: 0.64,
      );

      FormFeedback feedback = const FormFeedback(status: FormStatus.good);
      for (int i = 0; i < 25; i++) {
        feedback = analyzer.analyzeFrame(landmarks);
      }

      expect(
        feedback.issues.any((i) => i.code == 'TRUNK_LEAN_WARN'),
        isTrue,
        reason: 'Should warn about trunk lean at ~35°',
      );
    });

    test('detects trunk lean bad for extreme lean', () {
      // trunkLeanBadAngle = 45° → tan(45°) = 1.0 → dx = dy
      // dy = |0.28 - 0.50| = 0.22, so dx = 0.22
      // shoulder centerX = 0.525 + 0.22 = 0.745, hip centerX = 0.525
      // lShoulder X = 0.745 + 0.04 = 0.785, rShoulder X = 0.745 - 0.04 = 0.705
      // But we need > 45°, so use even more lean
      // dx = 0.30 → atan2(0.30, 0.22) = 53.7° > 45°
      // shoulder centerX = 0.525 + 0.30 = 0.825
      // lShoulder 0.865, rShoulder 0.785 → center = 0.825
      final landmarks = _makeLandmarks(
        lShoulderX: 0.865,
        rShoulderX: 0.785,
      );

      FormFeedback feedback = const FormFeedback(status: FormStatus.good);
      for (int i = 0; i < 25; i++) {
        feedback = analyzer.analyzeFrame(landmarks);
      }

      expect(
        feedback.issues.any((i) => i.code == 'TRUNK_LEAN_BAD'),
        isTrue,
        reason: 'Should flag bad trunk lean at ~54°',
      );
    });

    test('no trunk lean issue for upright posture', () {
      // Default landmarks have very upright posture
      final landmarks = _makeLandmarks();
      FormFeedback feedback = const FormFeedback(status: FormStatus.good);
      for (int i = 0; i < 10; i++) {
        feedback = analyzer.analyzeFrame(landmarks);
      }

      expect(
        feedback.issues.any(
          (i) =>
              i.code == 'TRUNK_LEAN_WARN' || i.code == 'TRUNK_LEAN_BAD',
        ),
        isFalse,
        reason: 'Should not flag trunk lean for upright posture',
      );
    });

    // ── Depth Tests ──────────────────────────────────────────────────────

    test('detects shallow depth warning on ascent', () {
      final analyzer = SingleSquatFormAnalyzer(
        sensitivity: const SingleSquatSensitivity(
          kneeValgusWarnRatio: 0.08,
          kneeValgusBadRatio: 0.15,
          trunkLeanWarnAngle: 30.0,
          trunkLeanBadAngle: 45.0,
          depthWarnAngle: 120.0,
          depthGoodAngle: 100.0,
        ),
      );

      // Phase 1: Standing (straight legs, knee angle ~175°)
      for (int i = 0; i < 5; i++) {
        analyzer.analyzeFrame(_makeLandmarks());
      }

      // Phase 2: Shallow descent
      // Create a moderate bend: hip-knee-ankle angle ~130-140°
      // hip (0.55, 0.58), knee (0.60, 0.76), ankle (0.59, 0.84)
      // This gives a clear knee bend but above 120° (warn threshold)
      for (int i = 0; i < 40; i++) {
        analyzer.analyzeFrame(
          _makeLandmarks(
            lHipY: 0.58,
            rHipY: 0.58,
            lKneeX: 0.61,
            rKneeX: 0.45,
            lKneeY: 0.76,
            rKneeY: 0.76,
          ),
        );
      }

      // Phase 3: Ascend (return to standing) — should trigger depth warning
      // on one of these frames
      bool depthWarnSeen = false;
      for (int i = 0; i < 15; i++) {
        final fb = analyzer.analyzeFrame(_makeLandmarks());
        if (fb.issues.any((i) => i.code == 'DEPTH_WARN')) {
          depthWarnSeen = true;
        }
      }

      expect(
        depthWarnSeen,
        isTrue,
        reason: 'Should warn about insufficient depth during ascent',
      );
    });

    // ── Reset Tests ──────────────────────────────────────────────────────

    test('reset clears all state', () {
      // Feed some bad data
      for (int i = 0; i < 10; i++) {
        analyzer.analyzeFrame(_makeLandmarks(lKneeX: 0.58));
      }

      analyzer.reset();

      // After reset, good data should produce good feedback
      final feedback = analyzer.analyzeFrame(_makeLandmarks());
      // May still be good or have minor issues from one frame, but should
      // not have accumulated valgus warnings.
      expect(
        feedback.issues.any((i) => i.code == 'KNEE_VALGUS_WARN'),
        isFalse,
        reason: 'Reset should clear accumulated valgus warning frames',
      );
    });

    // ── Sensitivity Update Tests ─────────────────────────────────────────

    test('updateSensitivity changes thresholds', () {
      final newSensitivity = const SingleSquatSensitivity(
        kneeValgusWarnRatio: 0.70,
        kneeValgusBadRatio: 0.90,
        trunkLeanWarnAngle: 80.0,
        trunkLeanBadAngle: 89.0,
        depthWarnAngle: 170.0,
        depthGoodAngle: 160.0,
      );

      analyzer.updateSensitivity(newSensitivity);

      // With very lenient thresholds, even bad form should pass
      final landmarks = _makeLandmarks(lKneeX: 0.52, rKneeX: 0.50);
      FormFeedback feedback = const FormFeedback(status: FormStatus.good);
      for (int i = 0; i < 10; i++) {
        feedback = analyzer.analyzeFrame(landmarks);
      }

      expect(
        feedback.issues.any(
          (i) =>
              i.code == 'KNEE_VALGUS_WARN' || i.code == 'KNEE_VALGUS_BAD',
        ),
        isFalse,
        reason: 'Very lenient thresholds should not trigger valgus',
      );
    });

    // ── Metrics Tests ────────────────────────────────────────────────────

    test('debug metrics are populated', () {
      final landmarks = _makeLandmarks();
      final feedback = analyzer.analyzeFrame(landmarks);
      expect(feedback.debugMetrics, isNotNull);
      expect(feedback.debugMetrics!, contains('trunk_lean'));
      expect(feedback.debugMetrics!, contains('valgus_left'));
      expect(feedback.debugMetrics!, contains('valgus_right'));
      expect(feedback.debugMetrics!, contains('knee_angle'));
    });
  });

  group('SingleSquatSensitivity', () {
    test('defaults have valid values', () {
      const s = SingleSquatSensitivity.defaults();
      expect(s.kneeValgusWarnRatio, greaterThan(0));
      expect(s.kneeValgusBadRatio, greaterThan(s.kneeValgusWarnRatio));
      expect(s.trunkLeanWarnAngle, greaterThan(0));
      expect(s.trunkLeanBadAngle, greaterThan(s.trunkLeanWarnAngle));
      expect(s.depthWarnAngle, greaterThan(s.depthGoodAngle));
    });

    test('copyWith preserves unset fields', () {
      const s = SingleSquatSensitivity.defaults();
      final s2 = s.copyWith(kneeValgusWarnRatio: 0.10);
      expect(s2.kneeValgusWarnRatio, equals(0.10));
      expect(s2.kneeValgusBadRatio, equals(s.kneeValgusBadRatio));
      expect(s2.trunkLeanWarnAngle, equals(s.trunkLeanWarnAngle));
    });

    test('resetToDefaults returns defaults', () {
      final s = const SingleSquatSensitivity(
        kneeValgusWarnRatio: 0.50,
        kneeValgusBadRatio: 0.90,
        trunkLeanWarnAngle: 80.0,
        trunkLeanBadAngle: 89.0,
        depthWarnAngle: 170.0,
        depthGoodAngle: 160.0,
      );
      final reset = s.resetToDefaults();
      final defaults = const SingleSquatSensitivity.defaults();
      expect(reset.kneeValgusWarnRatio, equals(defaults.kneeValgusWarnRatio));
      expect(reset.trunkLeanWarnAngle, equals(defaults.trunkLeanWarnAngle));
      expect(reset.depthWarnAngle, equals(defaults.depthWarnAngle));
    });

    test('hysteresis exit ratios are computed correctly', () {
      const s = SingleSquatSensitivity.defaults();
      expect(s.kneeValgusWarnExitRatio, equals(s.kneeValgusWarnRatio - 0.03));
      expect(s.trunkLeanWarnExitAngle, equals(s.trunkLeanWarnAngle - 5.0));
    });
  });

  group('SingleSquatFormAnalyzer with real fixture data', () {
    test('real squat video shows good form (no warnings)', () {
      // The fixture video data was captured from a front-facing camera showing
      // a squat with good form — upright trunk, knees tracking over toes.
      // We use lenient defaults to confirm no false positives.
      final analyzer = SingleSquatFormAnalyzer();

      final frames = realSingleSquatFrames;
      int warningCount = 0;
      int badCount = 0;

      for (var frame in frames) {
        final feedback = analyzer.analyzeFrame(frame.landmarks);
        if (feedback.status == FormStatus.warning) warningCount++;
        if (feedback.status == FormStatus.bad) badCount++;
      }

      // The demo video shows mostly good form.
      expect(badCount, equals(0), reason: 'Good form should have no BAD issues');
      // Allow depth warnings since the demo is a shallow squat
      expect(
        warningCount,
        lessThan(15),
        reason: 'Good form should have relatively few warnings',
      );
    });

    test('real data produces expected metrics range', () {
      final analyzer = SingleSquatFormAnalyzer();

      final frames = realSingleSquatFrames;
      double maxTrunkLean = 0;

      for (var frame in frames) {
        final feedback = analyzer.analyzeFrame(frame.landmarks);
        final trunkLean = feedback.debugMetrics?['trunk_lean'] ?? 0.0;
        if (trunkLean > maxTrunkLean) maxTrunkLean = trunkLean;
      }

      // From manual analysis, the demo video has very upright trunk (~0.5-5°)
      expect(
        maxTrunkLean,
        lessThan(15.0),
        reason: 'Demo video trunk lean should stay small',
      );
    });
  });
}
