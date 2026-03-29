/// Status of the user's form for a single frame.
enum FormStatus { good, warning, bad }

/// A specific issue detected with the form.
class FormIssue {
  final String code;
  final String message;
  final FormStatus severity;

  const FormIssue({
    required this.code,
    required this.message,
    required this.severity,
  });

  @override
  String toString() => '$code: $message ($severity)';
}

/// Complete feedback for a single frame.
class FormFeedback {
  final FormStatus status;
  final List<FormIssue> issues;
  final Map<String, double> debugMetrics;

  const FormFeedback({
    required this.status,
    this.issues = const [],
    this.debugMetrics = const {},
  });

  factory FormFeedback.empty() => const FormFeedback(status: FormStatus.good);
}
