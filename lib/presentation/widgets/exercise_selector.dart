import 'package:flutter/material.dart';

import '../../domain/models/exercise_type.dart';
import '../theme/app_theme.dart';

/// Dropdown widget for selecting an exercise.
///
/// Uses a PopupMenuButton for an iOS-native feel while preserving
/// the Semantics label required by Maestro tests.
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
    final label = selectedExercise?.displayName ?? 'Select Exercise';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: 12,
        child: PopupMenuButton<ExerciseType>(
          initialValue: selectedExercise,
          onSelected: onChanged,
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          color: const Color(0xF02C2C2E),
          itemBuilder: (context) => ExerciseType.values.map((type) {
            final isSelected = type == selectedExercise;
            return PopupMenuItem<ExerciseType>(
              value: type,
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_off,
                    size: 18,
                    color: isSelected
                        ? context.fpTheme.accentGreen
                        : Colors.white54,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    type.displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
