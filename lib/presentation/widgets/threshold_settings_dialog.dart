import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';

import '../../domain/models/exercise_type.dart';
import '../theme/app_theme.dart';

/// Dialog result containing angle thresholds and optional sensitivity config.
class ThresholdDialogResult {
  final double topThreshold;
  final double bottomThreshold;
  final FormSensitivityConfig? sensitivity;

  const ThresholdDialogResult({
    required this.topThreshold,
    required this.bottomThreshold,
    this.sensitivity,
  });
}

/// Shows a bottom sheet for configuring exercise thresholds and form sensitivity.
///
/// Returns a [ThresholdDialogResult] if the user applies changes, or null
/// if they dismiss without applying.
Future<ThresholdDialogResult?> showThresholdSettingsSheet({
  required BuildContext context,
  required double initialTopThreshold,
  required double initialBottomThreshold,
  required ExerciseType exerciseType,
  FormSensitivityConfig? initialSensitivity,
  VoidCallback? onShowDemo,
}) {
  return showModalBottomSheet<ThresholdDialogResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ThresholdSettingsSheet(
      initialTopThreshold: initialTopThreshold,
      initialBottomThreshold: initialBottomThreshold,
      exerciseType: exerciseType,
      initialSensitivity: initialSensitivity,
      onShowDemo: onShowDemo,
    ),
  );
}

/// Bottom sheet content for configuring exercise thresholds and form sensitivity.
class ThresholdSettingsSheet extends StatefulWidget {
  final double initialTopThreshold;
  final double initialBottomThreshold;
  final FormSensitivityConfig? initialSensitivity;
  final ExerciseType exerciseType;
  final VoidCallback? onShowDemo;

  const ThresholdSettingsSheet({
    super.key,
    required this.initialTopThreshold,
    required this.initialBottomThreshold,
    required this.exerciseType,
    this.initialSensitivity,
    this.onShowDemo,
  });

  @override
  State<ThresholdSettingsSheet> createState() => _ThresholdSettingsSheetState();
}

class _ThresholdSettingsSheetState extends State<ThresholdSettingsSheet> {
  late double topThreshold;
  late double bottomThreshold;
  late FormSensitivityConfig? sensitivity;

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
    final theme = context.fpTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHelpButton(theme),
                      const SizedBox(width: 4),
                      if (hasThresholds)
                        TextButton(
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
                          child: Text(
                            'Apply',
                            style: TextStyle(
                              color: theme.accentGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),

            // Content
            Expanded(
              child: hasThresholds
                  ? ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Adjust thresholds based on your range of motion',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Top threshold
                        _buildThresholdSlider(
                          label: 'Top Threshold',
                          value: topThreshold,
                          min: widget.exerciseType.config.topThresholdBounds.$1,
                          max: widget.exerciseType.config.topThresholdBounds.$2,
                          description: 'Angle needed to reach "up" position',
                          onChanged: (value) {
                            setState(() {
                              topThreshold = value;
                              if (bottomThreshold >= topThreshold - 10) {
                                bottomThreshold = topThreshold - 10;
                                if (bottomThreshold <
                                    widget
                                        .exerciseType
                                        .config
                                        .bottomThresholdBounds
                                        .$1) {
                                  bottomThreshold = widget
                                      .exerciseType
                                      .config
                                      .bottomThresholdBounds
                                      .$1;
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Bottom threshold
                        _buildThresholdSlider(
                          label: 'Bottom Threshold',
                          value: bottomThreshold,
                          min: widget
                              .exerciseType
                              .config
                              .bottomThresholdBounds
                              .$1,
                          max: widget
                              .exerciseType
                              .config
                              .bottomThresholdBounds
                              .$2,
                          description: 'Angle for "down" position',
                          onChanged: (value) {
                            setState(() {
                              if (value <= topThreshold - 10) {
                                bottomThreshold = value;
                              }
                            });
                          },
                        ),

                        // Form Sensitivity section
                        if (sensitivity != null) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12),
                          _buildSensitivitySection(),
                        ],

                        const SizedBox(height: 32),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Use the help menu (?) to view the exercise demo.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThresholdSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String description,
    required ValueChanged<double> onChanged,
  }) {
    final theme = context.fpTheme;
    final divisions = (max - min).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.round()}°',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: theme.accentGreen,
            thumbColor: theme.accentGreen,
            inactiveTrackColor: const Color(0xFF3A3A3C),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.round()}°',
            onChanged: onChanged,
          ),
        ),
        Text(
          description,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildHelpButton(FitnessPipeTheme theme) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(Icons.question_mark, size: 16, color: Colors.white54),
      ),
      tooltip: 'Help',
      onSelected: (value) {
        switch (value) {
          case 'view_demo':
            Navigator.of(context).pop();
            widget.onShowDemo?.call();
            break;
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
      ],
    );
  }

  Widget _buildSensitivitySection() {
    final s = sensitivity!;
    if (s is LateralRaiseSensitivity) {
      return _buildLateralRaiseSensitivity(s);
    } else if (s is SingleSquatSensitivity) {
      return _buildSingleSquatSensitivity(s);
    } else if (s is BenchPressSensitivity) {
      return _buildBenchPressSensitivity(s);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLateralRaiseSensitivity(LateralRaiseSensitivity s) {
    final theme = context.fpTheme;

    return ExpansionTile(
      title: const Text(
        'Form Sensitivity',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      iconColor: Colors.white54,
      collapsedIconColor: Colors.white54,
      children: [
        const SizedBox(height: 8),

        _buildSectionHeader('Elbow Straightness', Icons.fitness_center),
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
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
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
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

        _buildSectionHeader('Trunk Stability', Icons.accessibility_new),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
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
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
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

        _buildSectionHeader('Shoulder Shrug', Icons.person),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
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
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
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

  Widget _buildSingleSquatSensitivity(SingleSquatSensitivity s) {
    final theme = context.fpTheme;

    return ExpansionTile(
      title: const Text(
        'Form Sensitivity',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      iconColor: Colors.white54,
      collapsedIconColor: Colors.white54,
      children: [
        const SizedBox(height: 8),

        _buildSectionHeader(
          'Knee Alignment',
          Icons.airline_seat_legroom_normal,
        ),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
          value: s.kneeValgusWarnRatio * 100,
          min: 3,
          max: 15,
          unit: '%',
          description: 'Knee inward deviation % of hip width',
          effectHint: 'Lower = stricter',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              kneeValgusWarnRatio: v / 100,
              kneeValgusBadRatio: s.kneeValgusBadRatio < (v / 100) + 0.03
                  ? (v / 100) + 0.03
                  : null,
            );
          }),
        ),
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
          value: s.kneeValgusBadRatio * 100,
          min: 8,
          max: 25,
          unit: '%',
          description: 'Knee inward deviation % for bad form',
          effectHint: 'Lower = stricter',
          onChanged: (v) => setState(() {
            if (v / 100 > s.kneeValgusWarnRatio + 0.02) {
              sensitivity = s.copyWith(kneeValgusBadRatio: v / 100);
            }
          }),
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('Trunk Lean', Icons.accessibility_new),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
          value: s.trunkLeanWarnAngle,
          min: 15,
          max: 45,
          unit: '°',
          description: 'Forward lean angle for warning',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              trunkLeanWarnAngle: v,
              trunkLeanBadAngle: s.trunkLeanBadAngle < v + 5 ? v + 5 : null,
            );
          }),
        ),
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
          value: s.trunkLeanBadAngle,
          min: 25,
          max: 60,
          unit: '°',
          description: 'Forward lean angle for bad form',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            if (v > s.trunkLeanWarnAngle + 5) {
              sensitivity = s.copyWith(trunkLeanBadAngle: v);
            }
          }),
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('Squat Depth', Icons.arrow_downward),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
          value: s.depthWarnAngle,
          min: 100,
          max: 140,
          unit: '°',
          description: 'Knee angle above which depth is insufficient',
          effectHint: 'Lower = deeper required',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              depthWarnAngle: v,
              depthGoodAngle: s.depthGoodAngle > v - 10 ? v - 10 : null,
            );
          }),
        ),
        _buildSensitivitySlider(
          label: 'Good',
          severityColor: theme.feedbackGood,
          value: s.depthGoodAngle,
          min: 70,
          max: 130,
          unit: '°',
          description: 'Knee angle at which depth is good',
          effectHint: 'Lower = deeper required',
          onChanged: (v) => setState(() {
            if (v < s.depthWarnAngle - 10) {
              sensitivity = s.copyWith(depthGoodAngle: v);
            }
          }),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                sensitivity = const SingleSquatSensitivity.defaults();
              });
            },
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Reset to Defaults'),
          ),
        ),
      ],
    );
  }

  Widget _buildBenchPressSensitivity(BenchPressSensitivity s) {
    final theme = context.fpTheme;

    return ExpansionTile(
      title: const Text(
        'Form Sensitivity',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      iconColor: Colors.white54,
      collapsedIconColor: Colors.white54,
      children: [
        const SizedBox(height: 8),

        _buildSectionHeader('Elbow Flare', Icons.fitness_center),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
          value: s.flareWarnAngle,
          min: 55,
          max: 85,
          unit: '°',
          description: 'Shoulder-to-elbow angle for flare warning',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              flareWarnAngle: v,
              flareBadAngle: s.flareBadAngle < v + 5 ? v + 5 : null,
            );
          }),
        ),
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
          value: s.flareBadAngle,
          min: 65,
          max: 100,
          unit: '°',
          description: 'Shoulder-to-elbow angle for bad flare',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            if (v > s.flareWarnAngle + 5) {
              sensitivity = s.copyWith(flareBadAngle: v);
            }
          }),
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('Uneven Extension', Icons.balance),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
          value: s.unevenWarnAngle,
          min: 8,
          max: 25,
          unit: '°',
          description: 'Left-right elbow angle difference for warning',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              unevenWarnAngle: v,
              unevenBadAngle: s.unevenBadAngle < v + 5 ? v + 5 : null,
            );
          }),
        ),
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
          value: s.unevenBadAngle,
          min: 15,
          max: 40,
          unit: '°',
          description: 'Left-right elbow angle difference for bad form',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            if (v > s.unevenWarnAngle + 5) {
              sensitivity = s.copyWith(unevenBadAngle: v);
            }
          }),
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('Hip Rise', Icons.airline_seat_flat),
        _buildSensitivitySlider(
          label: 'Warning',
          severityColor: theme.feedbackWarning,
          value: s.hipRiseWarnDrop * 100,
          min: 2,
          max: 15,
          unit: '%',
          description: 'Hip rise % of baseline for warning',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            sensitivity = s.copyWith(
              hipRiseWarnDrop: v / 100,
              hipRiseBadDrop: s.hipRiseBadDrop < (v / 100) + 0.03
                  ? (v / 100) + 0.03
                  : null,
            );
          }),
        ),
        _buildSensitivitySlider(
          label: 'Bad',
          severityColor: theme.feedbackBad,
          value: s.hipRiseBadDrop * 100,
          min: 5,
          max: 25,
          unit: '%',
          description: 'Hip rise % of baseline for bad form',
          effectHint: 'Higher = more lenient',
          onChanged: (v) => setState(() {
            if (v / 100 > s.hipRiseWarnDrop + 0.02) {
              sensitivity = s.copyWith(hipRiseBadDrop: v / 100);
            }
          }),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                sensitivity = const BenchPressSensitivity.defaults();
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
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensitivitySlider({
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
    final clampedValue = value.clamp(min, max);
    final divisions = ((max - min) * 2).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$label: ${clampedValue.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: severityColor,
              ),
            ),
            const Spacer(),
            Text(
              effectHint,
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: severityColor.withValues(alpha: 0.7),
            thumbColor: severityColor,
            inactiveTrackColor: const Color(0xFF3A3A3C),
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
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
