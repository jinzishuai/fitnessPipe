import 'package:flutter/material.dart';

/// Dialog for configuring lateral raise thresholds.
class ThresholdSettingsDialog extends StatefulWidget {
  final double initialTopThreshold;
  final double initialBottomThreshold;

  const ThresholdSettingsDialog({
    super.key,
    required this.initialTopThreshold,
    required this.initialBottomThreshold,
  });

  @override
  State<ThresholdSettingsDialog> createState() =>
      _ThresholdSettingsDialogState();
}

class _ThresholdSettingsDialogState extends State<ThresholdSettingsDialog> {
  late double topThreshold;
  late double bottomThreshold;

  @override
  void initState() {
    super.initState();
    topThreshold = widget.initialTopThreshold;
    bottomThreshold = widget.initialBottomThreshold;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Threshold Settings'),
      content: SizedBox(
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
            const SizedBox(height: 16),

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
                  // Only allow changing bottom threshold if it stays below top - 10
                  if (value < topThreshold - 10) {
                    bottomThreshold = value;
                  }
                });
              },
            ),
            const Text(
              'Angle for "down" position',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'top': topThreshold,
              'bottom': bottomThreshold,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
