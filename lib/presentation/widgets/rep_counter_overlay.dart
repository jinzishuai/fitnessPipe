import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Overlay widget displaying rep counter information with glass-morphism styling.
class RepCounterOverlay extends StatelessWidget {
  final int repCount;
  final String phaseLabel;
  final Color phaseColor;
  final double currentAngle;
  final bool isActive;

  /// Exercise-specific prompt shown when user hasn't reached the starting
  /// position yet (e.g., "Lower arms to start", "Stand straight to begin").
  final String startPrompt;

  const RepCounterOverlay({
    super.key,
    required this.repCount,
    required this.phaseLabel,
    required this.phaseColor,
    required this.currentAngle,
    this.isActive = false,
    this.startPrompt = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.fpTheme;

    return Positioned(
      top: 80,
      left: 16,
      child: GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Guidance prompt (only when inactive)
            if (!isActive && startPrompt.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.poseNotDetectedColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    startPrompt,
                    style: TextStyle(
                      color: theme.poseNotDetectedColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Rep count row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status indicator
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.poseDetectedColor
                        : theme.poseNotDetectedColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isActive
                                    ? theme.poseDetectedColor
                                    : theme.poseNotDetectedColor)
                                .withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: '$repCount',
                  excludeSemantics: true,
                  child: Text(
                    '$repCount',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'reps',
                  excludeSemantics: true,
                  child: const Text(
                    'reps',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Phase chip
            _buildPhaseChip(),

            const SizedBox(height: 6),

            // Debug angle
            Text(
              'Angle: ${currentAngle.toStringAsFixed(1)}°',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: phaseColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        phaseLabel,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
