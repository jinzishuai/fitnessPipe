import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';

import '../../domain/models/exercise_type.dart';

/// Dialog result containing angle thresholds and optional sensitivity config.
class ThresholdDialogResult {
  final double topThreshold;
  final double bottomThreshold;
  final LateralRaiseSensitivity? sensitivity;

  const ThresholdDialogResult({
    required this.topThreshold,
    required this.bottomThreshold,
    this.sensitivity,
  });
}

/// Dialog for configuring exercise thresholds and form sensitivity.
///
/// When [initialSensitivity] is provided, shows additional sliders
/// for adjusting form check sensitivity. When null, only the angle
/// threshold sliders are shown.
class ThresholdSettingsDialog extends StatefulWidget {
  final double initialTopThreshold;
  final double initialBottomThreshold;
  final LateralRaiseSensitivity? initialSensitivity;
  final ExerciseType exerciseType;
  final VoidCallback? onShowDemo;

  const ThresholdSettingsDialog({
    super.key,
    required this.initialTopThreshold,
    required this.initialBottomThreshold,
    required this.exerciseType,
    this.initialSensitivity,
    this.onShowDemo,
  });

  @override
  State<ThresholdSettingsDialog> createState() =>
      _ThresholdSettingsDialogState();
}

class _ThresholdSettingsDialogState extends State<ThresholdSettingsDialog> {
  late double topThreshold;
  late double bottomThreshold;
  late LateralRaiseSensitivity? sensitivity;

  @override
  void initState() {
    super.initState();
    topThreshold = widget.initialTopThreshold;
    bottomThreshold = widget.initialBottomThreshold;
    sensitivity = widget.initialSensitivity;
  }

  @override
  Widget build(BuildContext context) {
    final hasThresholds = widget.exerciseType.config.hasThresholds;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [const Text('Settings'), _buildHelpButton()],
      ),
      content: hasThresholds
          ? SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adjust thresholds based on your range of motion',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // Top threshold slider
                    Text('Top Threshold: ${topThreshold.round()}°'),
                    Slider(
                      value: topThreshold,
                      min: 30,
                      max: 90,
                      divisions: 60,
                      label: '${topThreshold.round()}°',
                      onChanged: (value) {
                        setState(() {
                          topThreshold = value;
                          // Ensure bottom is always lower than top
                          if (bottomThreshold >= topThreshold - 10) {
                            bottomThreshold = topThreshold - 10;
                          }
                        });
                      },
                    ),
                    const Text(
                      'Angle needed to reach "up" position',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // Bottom threshold slider
                    Text('Bottom Threshold: ${bottomThreshold.round()}°'),
                    Slider(
                      value: bottomThreshold,
                      min: 10,
                      max: 40,
                      divisions: 30,
                      label: '${bottomThreshold.round()}°',
                      onChanged: (value) {
                        setState(() {
                          if (value <= topThreshold - 10) {
                            bottomThreshold = value;
                          }
                        });
                      },
                    ),
                    const Text(
                      'Angle for "down" position',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),

                    // Form Sensitivity section (only for exercises with form analysis)
                    if (sensitivity != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      _buildSensitivitySection(),
                    ],
                  ],
                ),
              ),
            )
          : SizedBox(
              width: 300,
              child: Text(
                'Use the help menu (?) to view the exercise demo.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(hasThresholds ? 'Cancel' : 'Close'),
        ),
        if (hasThresholds)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                ThresholdDialogResult(
                  topThreshold: topThreshold,
                  bottomThreshold: bottomThreshold,
                  sensitivity: sensitivity,
                ),
              );
            },
            child: const Text('Apply'),
          ),
      ],
    );
  }

  Widget _buildHelpButton() {
    return PopupMenuButton<String>(
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey),
        ),
        child: const Icon(Icons.question_mark, size: 18, color: Colors.grey),
      ),
      tooltip: 'Help',
      onSelected: (value) {
        switch (value) {
          case 'view_demo':
            Navigator.of(context).pop(); // close settings first
            widget.onShowDemo?.call(); // let parent handle demo
            break;
          // Future help options can be added here
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'view_demo',
          child: Row(
            children: [
              Icon(Icons.play_circle_outline, size: 20),
              SizedBox(width: 8),
              Text('View Exercise Demo'),
            ],
          ),
        ),
        // Additional help items can be added here for scalability
      ],
    );
  }

  Widget _buildSensitivitySection() {
    final s = sensitivity!;
    return ExpansionTile(
      title: const Text(
        'Form Sensitivity',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),

        // --- Elbow ---
        _buildSectionHeader('Elbow Straightness', Icons.fitness_center),
        _buildSlider(
          label: 'Bad',
          severityColor: Colors.red,
          value: s.elbowBadAngle,
          min: 120,
          max: 160,
          unit: '°',
          description: 'Angle below which arms are too bent',
          effectHint: 'Lower = stricter',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              elbowBadAngle: v,
              elbowWarnAngle: s.elbowWarnAngle < v + 5 ? v + 5 : null,
            );
          }),
        ),
        _buildSlider(
          label: 'Warning',
          severityColor: Colors.amber,
          value: s.elbowWarnAngle,
          min: 135,
          max: 170,
          unit: '°',
          description: 'Angle below which a soft bend warning shows',
          effectHint: 'Lower = stricter',
          onChanged: (v) => setState(() {
            if (v > s.elbowBadAngle + 5) {
              sensitivity = s.copyWith(elbowWarnAngle: v);
            }
          }),
        ),
        const SizedBox(height: 12),

        // --- Trunk ---
        _buildSectionHeader('Trunk Stability', Icons.accessibility_new),
        _buildSlider(
          label: 'Warning',
          severityColor: Colors.amber,
          value: s.trunkLeanWarnAngle,
          min: 4,
          max: 20,
          unit: '°',
          description: 'Lean angle for warning',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              trunkLeanWarnAngle: v,
              trunkLeanBadAngle: s.trunkLeanBadAngle < v + 3 ? v + 3 : null,
            );
          }),
        ),
        _buildSlider(
          label: 'Bad',
          severityColor: Colors.red,
          value: s.trunkLeanBadAngle,
          min: 8,
          max: 30,
          unit: '°',
          description: 'Lean angle for bad form',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            if (v > s.trunkLeanWarnAngle + 3) {
              sensitivity = s.copyWith(trunkLeanBadAngle: v);
            }
          }),
        ),
        const SizedBox(height: 12),

        // --- Shoulders ---
        _buildSectionHeader('Shoulder Shrug', Icons.person),
        _buildSlider(
          label: 'Warning',
          severityColor: Colors.amber,
          value: s.shrugWarnDrop * 100,
          min: 5,
          max: 25,
          unit: '%',
          description: 'Neck drop % for warning',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              shrugWarnDrop: v / 100,
              shrugBadDrop: s.shrugBadDrop < (v / 100) + 0.10
                  ? (v / 100) + 0.10
                  : null,
            );
          }),
        ),
        _buildSlider(
          label: 'Bad',
          severityColor: Colors.red,
          value: s.shrugBadDrop * 100,
          min: 15,
          max: 50,
          unit: '%',
          description: 'Neck drop % for bad form',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            if (v / 100 > s.shrugWarnDrop + 0.05) {
              sensitivity = s.copyWith(shrugBadDrop: v / 100);
            }
          }),
        ),
        const SizedBox(height: 12),

        // Reset button
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                sensitivity = const LateralRaiseSensitivity.defaults();
              });
            },
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Reset to Defaults'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required Color severityColor,
    required double value,
    required double min,
    required double max,
    required String unit,
    required String description,
    required String effectHint,
    required ValueChanged<double> onChanged,
  }) {
    // Clamp value into range to prevent slider errors
    final clampedValue = value.clamp(min, max);
    final divisions = ((max - min) * 2).round(); // 0.5 step precision

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Severity-colored label
            Text(
              '$label: ${clampedValue.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: severityColor,
              ),
            ),
            const Spacer(),
            // Directional effect hint
            Text(
              effectHint,
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: severityColor.withValues(alpha: 0.7),
            thumbColor: severityColor,
          ),
          child: Slider(
            value: clampedValue,
            min: min,
            max: max,
            divisions: divisions,
            label: '${clampedValue.toStringAsFixed(1)}$unit',
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
