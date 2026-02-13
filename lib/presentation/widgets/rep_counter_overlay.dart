import 'package:flutter/material.dart';

/// Overlay widget displaying rep counter information.
class RepCounterOverlay extends StatelessWidget {
  final int repCount;
  final String phaseLabel;
  final Color phaseColor;
  final double currentAngle;
  final bool isActive;

  const RepCounterOverlay({
    super.key,
    required this.repCount,
    required this.phaseLabel,
    required this.phaseColor,
    required this.currentAngle,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80, // Below exercise selector
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Guidance prompt (Only when inactive)
            if (!isActive) ...[
              const Text(
                'Lower arms to start',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Rep count (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Status Indicator (Red/Green)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8, top: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? Colors.greenAccent.withValues(alpha: 0.6)
                            : Colors.redAccent.withValues(alpha: 0.6),
                        blurRadius: 4,
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
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'reps',
                  excludeSemantics: true,
                  child: const Text(
                    'reps',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Phase indicator
            _buildPhaseChip(),

            const SizedBox(height: 4),

            // Debug: current angle
            Text(
              'Angle: ${currentAngle.toStringAsFixed(1)}°',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
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
        color: phaseColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        phaseLabel,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
