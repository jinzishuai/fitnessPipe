import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';

/// Overlay widget displaying rep counter information.
class RepCounterOverlay extends StatelessWidget {
  final int repCount;
  final LateralRaisePhase phase;
  final double currentAngle;

  const RepCounterOverlay({
    super.key,
    required this.repCount,
    required this.phase,
    required this.currentAngle,
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
            // Rep count (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$repCount',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'reps',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Phase indicator
            _buildPhaseChip(phase),

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

  Widget _buildPhaseChip(LateralRaisePhase phase) {
    final (label, color) = switch (phase) {
      LateralRaisePhase.waiting => ('Ready...', Colors.grey),
      LateralRaisePhase.down => ('Down', Colors.blue),
      LateralRaisePhase.rising => ('Rising ↑', Colors.orange),
      LateralRaisePhase.up => ('Up!', Colors.green),
      LateralRaisePhase.falling => ('Lowering ↓', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
