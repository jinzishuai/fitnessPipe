import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';

import '../../domain/models/exercise_type.dart';
import '../theme/app_theme.dart';
import 'exercise_selector.dart';
import 'form_feedback_overlay.dart';
import 'rep_counter_overlay.dart';

/// Shared overlay rendered on top of every camera/file preview mode.
///
/// Consolidates the exercise selector, rep counter, form feedback, action
/// buttons, pose indicator, and mode badge that were previously duplicated
/// across the file-preview, iOS camera, and Android camera builders.
class CameraOverlay extends StatelessWidget {
  final ExerciseType? selectedExercise;
  final ValueChanged<ExerciseType?> onExerciseSelected;
  final VoidCallback onShowSettings;
  final VoidCallback onReset;
  final VoidCallback onToggleVoice;
  final bool voiceEnabled;
  final bool isActive;
  final int repCount;
  final String phaseLabel;
  final Color phaseColor;
  final double currentAngle;
  final String startPrompt;
  final FilteredFeedback? displayedFeedback;
  final bool hasPose;
  final double? poseConfidence;
  final String poseLabel;
  final String badgeLabel;
  final Color? badgeColor;

  const CameraOverlay({
    super.key,
    required this.selectedExercise,
    required this.onExerciseSelected,
    required this.onShowSettings,
    required this.onReset,
    required this.onToggleVoice,
    required this.voiceEnabled,
    required this.isActive,
    required this.repCount,
    required this.phaseLabel,
    required this.phaseColor,
    required this.currentAngle,
    required this.startPrompt,
    required this.displayedFeedback,
    required this.hasPose,
    this.poseConfidence,
    this.poseLabel = 'Pose',
    this.badgeLabel = '',
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.fpTheme;

    return Stack(
      children: [
        // Top-right: exercise selector + settings gear
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedExercise != null) ...[
                _ActionIconButton(
                  icon: Icons.settings,
                  onPressed: onShowSettings,
                  tooltip: 'Settings',
                ),
                const SizedBox(width: 8),
              ],
              ExerciseSelectorDropdown(
                selectedExercise: selectedExercise,
                onChanged: onExerciseSelected,
              ),
            ],
          ),
        ),

        // Left side: rep counter
        if (selectedExercise != null)
          RepCounterOverlay(
            isActive: isActive,
            repCount: repCount,
            phaseLabel: phaseLabel,
            phaseColor: phaseColor,
            currentAngle: currentAngle,
            startPrompt: startPrompt,
          ),

        // Right side: form feedback
        if (displayedFeedback != null)
          FormFeedbackOverlay(
            feedback: FormFeedback(
              status: displayedFeedback!.status,
              issues: [displayedFeedback!.issue],
            ),
          ),

        // Bottom-right: action button toolbar
        if (selectedExercise != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionIconButton(
                  icon: voiceEnabled ? Icons.volume_up : Icons.volume_off,
                  onPressed: onToggleVoice,
                  tooltip: voiceEnabled ? 'Mute voice' : 'Enable voice',
                ),
                const SizedBox(height: 12),
                _ActionIconButton(
                  icon: Icons.refresh,
                  onPressed: onReset,
                  tooltip: 'Reset counter',
                  size: 48,
                ),
              ],
            ),
          ),

        // Bottom-left: pose detection indicator
        Positioned(
          bottom: 16,
          left: 16,
          child: Semantics(
            label: hasPose ? 'Pose detected' : 'No pose detected',
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              borderRadius: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasPose
                          ? theme.poseDetectedColor
                          : theme.poseNotDetectedColor,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (hasPose
                                      ? theme.poseDetectedColor
                                      : theme.poseNotDetectedColor)
                                  .withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasPose && poseConfidence != null
                        ? '$poseLabel: ${(poseConfidence! * 100).toStringAsFixed(0)}%'
                        : 'No pose detected',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Top-right badge (mode indicator)
        if (badgeLabel.isNotEmpty)
          Positioned(
            top: 64,
            right: 16,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              borderRadius: 8,
              backgroundColor: badgeColor?.withValues(alpha: 0.8),
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Consistent iOS-style circular icon button used throughout the overlay.
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final double size;

  const _ActionIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GlassContainer(
          padding: EdgeInsets.zero,
          borderRadius: size / 2,
          child: SizedBox(
            width: size,
            height: size,
            child: IconButton(
              icon: Icon(icon, color: Colors.white, size: size * 0.5),
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: size, minHeight: size),
            ),
          ),
        ),
      ),
    );
  }
}
