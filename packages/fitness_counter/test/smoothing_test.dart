import 'package:test/test.dart';
import 'package:fitness_counter/fitness_counter.dart';

void main() {
  group('AngleSmoother', () {
    test('first value initializes without smoothing', () {
      final smoother = AngleSmoother(alpha: 0.3);
      
      final result = smoother.smooth(45.0);
      
      expect(result, equals(45.0));
      expect(smoother.value, equals(45.0));
      expect(smoother.isInitialized, isTrue);
    });

    test('applies EMA formula correctly', () {
      final smoother = AngleSmoother(alpha: 0.5);
      
      smoother.smooth(40.0); // Initialize with 40
      final result = smoother.smooth(60.0); // Apply smoothing
      
      // With alpha=0.5: smoothed = 0.5 * 60 + 0.5 * 40 = 50
      expect(result, closeTo(50.0, 0.01));
    });

    test('reduces variance in noisy signal', () {
      final smoother = AngleSmoother(alpha: 0.3);
      
      // Simulate noisy input around 45 degrees
      final rawValues = [45.0, 48.0, 44.0, 46.0, 45.0, 43.0, 47.0];
      final smoothedValues = <double>[];
      
      for (final value in rawValues) {
        smoothedValues.add(smoother.smooth(value));
      }
      
      // Calculate variance
      final rawVariance = _variance(rawValues);
      final smoothedVariance = _variance(smoothedValues);
      
      // Smoothed variance should be lower
      expect(smoothedVariance, lessThan(rawVariance));
    });

    test('converges toward input over time', () {
      final smoother = AngleSmoother(alpha: 0.3);
      
      // Initialize with 0
      smoother.smooth(0.0);
      
      // Feed constant value of 100
      double lastSmoothed = 0.0;
      for (int i = 0; i < 50; i++) {
        lastSmoothed = smoother.smooth(100.0);
      }
      
      // Should converge close to 100
      expect(lastSmoothed, closeTo(100.0, 0.1));
    });

    test('reset clears state', () {
      final smoother = AngleSmoother(alpha: 0.3);
      
      smoother.smooth(45.0);
      expect(smoother.isInitialized, isTrue);
      
      smoother.reset();
      
      expect(smoother.isInitialized, isFalse);
      expect(smoother.value, equals(0.0));
    });

    test('higher alpha is more responsive', () {
      final fastSmoother = AngleSmoother(alpha: 0.8);
      final slowSmoother = AngleSmoother(alpha: 0.2);
      
      // Initialize both with same value
      fastSmoother.smooth(40.0);
      slowSmoother.smooth(40.0);
      
      // Apply new value
      final fastResult = fastSmoother.smooth(60.0);
      final slowResult = slowSmoother.smooth(60.0);
      
      // Fast smoother should be closer to 60
      expect(fastResult, greaterThan(slowResult));
      expect(fastResult, closeTo(56.0, 1.0)); // 0.8 * 60 + 0.2 * 40 = 56
      expect(slowResult, closeTo(44.0, 1.0)); // 0.2 * 60 + 0.8 * 40 = 44
    });

    test('throws on invalid alpha', () {
      expect(() => AngleSmoother(alpha: -0.1), throwsArgumentError);
      expect(() => AngleSmoother(alpha: 1.1), throwsArgumentError);
    });
  });
}

/// Calculate variance of a list of values.
double _variance(List<double> values) {
  if (values.isEmpty) return 0.0;
  
  final mean = values.reduce((a, b) => a + b) / values.length;
  final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
  return squaredDiffs.reduce((a, b) => a + b) / values.length;
}
