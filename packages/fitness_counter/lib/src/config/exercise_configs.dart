import 'exercise_config.dart';
import 'lateral_raise_config.dart';
import 'single_squat_config.dart';
import 'bench_press_config.dart';

/// Registry providing exercise configurations by type name.
///
/// Use [forName] to get the config for a specific exercise.
class ExerciseConfigs {
  ExerciseConfigs._(); // Prevent instantiation

  static const LateralRaiseConfig lateralRaise = LateralRaiseConfig();
  static const SingleSquatConfig singleSquat = SingleSquatConfig();
  static const BenchPressConfig benchPress = BenchPressConfig();

  /// Get the configuration for an exercise by name.
  ///
  /// Returns null if the exercise name is not recognized.
  static ExerciseConfig? forName(String name) {
    switch (name) {
      case 'lateralRaise':
        return lateralRaise;
      case 'singleSquat':
        return singleSquat;
      case 'benchPress':
        return benchPress;
      default:
        return null;
    }
  }

  /// All available exercise configurations.
  static List<ExerciseConfig> get all => const [
    lateralRaise,
    singleSquat,
    benchPress,
  ];
}
