import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';

import '../../domain/models/exercise_type.dart';
import '../../presentation/screens/pose_detection_input_mode.dart';
import '../theme/app_theme.dart';
import 'exercise_selector.dart';
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
  final bool showInputSelector;
  final PoseDetectionInputMode? currentInputMode;
  final List<PoseDetectionInputMode> availableInputModes;
  final ValueChanged<PoseDetectionInputMode>? onInputModeSelected;

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
    this.showInputSelector = false,
    this.currentInputMode,
    this.availableInputModes = const [],
    this.onInputModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.fpTheme;
    final safePad = MediaQuery.of(context).padding;
    final topInset = safePad.top + 8;
    final bottomInset = safePad.bottom + 8;
    final leftInset = safePad.left + 16;
    final rightInset = safePad.right + 16;

    return Stack(
      children: [
        // Top-center: app title (preserved for test/Maestro compatibility)
        Positioned(
          top: topInset,
          left: leftInset,
          right: rightInset,
          child: Row(
            children: [
              // Input mode switcher (left side)
              if (showInputSelector && onInputModeSelected != null)
                PopupMenuButton<PoseDetectionInputMode>(
                  initialValue: currentInputMode,
                  icon: const Icon(
                    Icons.cameraswitch,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'Switch Input',
                  onSelected: onInputModeSelected,
                  itemBuilder: (context) => availableInputModes
                      .map(
                        (mode) => PopupMenuItem<PoseDetectionInputMode>(
                          value: mode,
                          child: Row(
                            children: [
                              Icon(
                                currentInputMode == mode
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(mode.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              const Spacer(),
              const Text(
                'FitnessPipe',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              // Pose visibility indicator (right side, mirrors the input switcher)
              Icon(
                hasPose ? Icons.visibility : Icons.visibility_off,
                color: Colors.white54,
                size: 22,
              ),
            ],
          ),
        ),

        // Top-right column: exercise selector, badge, then form feedback
        // Uses a Column so elements flow vertically and never overlap.
        Positioned(
          top: topInset + 44,
          right: rightInset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Exercise selector + settings gear
              Row(
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

              // Mode badge (e.g. SIMULATOR MODE, VIDEO REPLAY)
              if (badgeLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
              ],

              // Form feedback (below selector and badge, never overlapping)
              if (displayedFeedback != null) ...[
                const SizedBox(height: 8),
                _buildFormFeedbackInline(theme),
              ],
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
            topOffset: topInset + 44,
            leftOffset: leftInset,
          ),

        // Bottom-right: action button toolbar
        if (selectedExercise != null)
          Positioned(
            bottom: bottomInset,
            right: rightInset,
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
          bottom: bottomInset,
          left: leftInset,
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
      ],
    );
  }

  Widget _buildFormFeedbackInline(FitnessPipeTheme theme) {
    final feedback = FormFeedback(
      status: displayedFeedback!.status,
      issues: [displayedFeedback!.issue],
    );

    if (feedback.status == FormStatus.good) {
      return Semantics(
        label: 'Good form',
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          borderRadius: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: theme.feedbackGood, size: 18),
              const SizedBox(width: 6),
              Text(
                'Good Form',
                style: TextStyle(
                  color: theme.feedbackGood,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isBad = feedback.status == FormStatus.bad;
    final color = isBad ? theme.feedbackBad : theme.feedbackWarning;
    final icon = isBad ? Icons.cancel : Icons.warning_amber_rounded;
    final title = isBad ? 'Bad Form' : 'Warning';

    return Semantics(
      label: '$title: ${feedback.issues.map((i) => i.message).join(', ')}',
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        borderRadius: 14,
        borderColor: color.withValues(alpha: 0.6),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (feedback.issues.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...feedback.issues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '\u2022 ',
                          style: TextStyle(color: Colors.white60),
                        ),
                        Expanded(
                          child: Text(
                            issue.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
