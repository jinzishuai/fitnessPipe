import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Overlay widget displaying real-time form feedback.
class FormFeedbackOverlay extends StatelessWidget {
  final FormFeedback feedback;
  final double topOffset;
  final double rightOffset;

  const FormFeedbackOverlay({
    super.key,
    required this.feedback,
    this.topOffset = 80,
    this.rightOffset = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.fpTheme;

    if (feedback.status == FormStatus.good) {
      return Positioned(
        top: topOffset,
        right: rightOffset,
        child: Semantics(
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
        ),
      );
    }

    final isBad = feedback.status == FormStatus.bad;
    final color = isBad ? theme.feedbackBad : theme.feedbackWarning;
    final icon = isBad ? Icons.cancel : Icons.warning_amber_rounded;
    final title = isBad ? 'Bad Form' : 'Warning';

    return Positioned(
      top: topOffset,
      right: rightOffset,
      child: Semantics(
        label: '$title: ${feedback.issues.map((i) => i.message).join(', ')}',
        child: GlassContainer(
          padding: const EdgeInsets.all(14),
          borderRadius: 14,
          borderColor: color.withValues(alpha: 0.6),
          child: SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
      ),
    );
  }
}
