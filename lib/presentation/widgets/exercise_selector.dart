import 'package:flutter/material.dart';

/// Exercise types available for rep counting.
enum ExerciseType {
  lateralRaise('Lateral Raise'),
  singleSquat('Single Squat');

  final String displayName;
  const ExerciseType(this.displayName);
}

/// Dropdown widget for selecting an exercise.
class ExerciseSelectorDropdown extends StatelessWidget {
  final ExerciseType? selectedExercise;
  final ValueChanged<ExerciseType?> onChanged;

  const ExerciseSelectorDropdown({
    super.key,
    required this.selectedExercise,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButton<ExerciseType>(
        value: selectedExercise,
        hint: const Text(
          'Select Exercise',
          style: TextStyle(color: Colors.white70),
        ),
        dropdownColor: Colors.black87,
        underline: const SizedBox.shrink(), // Remove default underline
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        items: ExerciseType.values.map((type) {
          return DropdownMenuItem<ExerciseType>(
            value: type,
            child: Text(
              type.displayName,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
