import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/material.dart';

/// Overlay widget displaying real-time form feedback.
class FormFeedbackOverlay extends StatelessWidget {
  final FormFeedback feedback;

  const FormFeedbackOverlay({
    super.key,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    if (feedback.status == FormStatus.good) {
      // Optional: Show nothing or a small "Good Form" check checkmark
      // For now, let's keep it clean and only show when issues arise, 
      // or maybe a subtle green indicator?
      // User request implied they want "feedback", usually implied corrections.
      // Let's show a small green dot for positive reinforcement?
      return Positioned(
        top: 80,
        right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(
                'Good Form',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final color = feedback.status == FormStatus.bad ? Colors.red : Colors.orange;
    final icon = feedback.status == FormStatus.bad ? Icons.cancel : Icons.warning_amber_rounded;
    final title = feedback.status == FormStatus.bad ? 'Bad Form' : 'Warning';

    return Positioned(
      top: 80, // Same vertical alignment as rep counter (approx) but on Right
      right: 16, // Top Right as requested
      child: Container(
        width: 220, // Limit width
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (feedback.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...feedback.issues.map((issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Text(
                        issue.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
