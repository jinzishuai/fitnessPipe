import 'package:fitness_counter/fitness_counter.dart';

/// Exercise types available for rep counting.
enum ExerciseType {
  lateralRaise('Lateral Raise'),
  singleSquat('Single Squat');

  final String displayName;
  const ExerciseType(this.displayName);

  /// Get the configuration for this exercise type.
  ExerciseConfig get config {
    switch (this) {
      case ExerciseType.lateralRaise:
        return ExerciseConfigs.lateralRaise;
      case ExerciseType.singleSquat:
        return ExerciseConfigs.singleSquat;
    }
  }
}
