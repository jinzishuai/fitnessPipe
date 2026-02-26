import '../form_analyzers/lateral_raise_form_analyzer.dart';

/// A single filtered feedback item ready for display/voice.
class FilteredFeedback {
  /// The highest-priority issue that passed throttling.
  final FormIssue issue;

  /// The overall form status.
  final FormStatus status;

  const FilteredFeedback({required this.issue, required this.status});
}

/// Throttles form feedback for both visual and voice output.
///
/// Prevents overwhelming the user with corrections they haven't had time
/// to act on by enforcing:
/// - A **global cooldown** between any feedback output
/// - A **per-code cooldown** so the same issue isn't repeated too quickly
///
/// Priority: [FormStatus.bad] always wins over [FormStatus.warning].
///
/// This class accepts an optional [clock] function for testability,
/// defaulting to [DateTime.now].
class FeedbackCooldownManager {
  /// Minimum gap between any two feedback outputs.
  final Duration globalCooldown;

  /// Minimum gap before the same issue code can be output again.
  final Duration perCodeCooldown;

  /// Injectable clock for testing. Returns current time.
  final DateTime Function() _clock;

  /// Last time any feedback was output.
  DateTime? _lastFeedbackTime;

  /// Last time each specific issue code was output.
  final Map<String, DateTime> _lastCodeTimes = {};

  FeedbackCooldownManager({
    this.globalCooldown = const Duration(seconds: 2),
    this.perCodeCooldown = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Process a [FormFeedback] and return a [FilteredFeedback] if an issue
  /// passes all cooldown checks, or `null` if throttled.
  ///
  /// Selects the highest-priority issue (bad > warning), then checks
  /// global and per-code cooldowns.
  FilteredFeedback? processFeedback(FormFeedback feedback) {
    if (feedback.status == FormStatus.good || feedback.issues.isEmpty) {
      return null;
    }

    // Select highest-priority issue: bad first, then warning
    final sorted = List<FormIssue>.from(feedback.issues)
      ..sort((a, b) {
        if (a.severity == FormStatus.bad && b.severity != FormStatus.bad) {
          return -1;
        }
        if (b.severity == FormStatus.bad && a.severity != FormStatus.bad) {
          return 1;
        }
        return 0;
      });

    final now = _clock();

    // Try each issue in priority order
    for (final issue in sorted) {
      // Skip silent codes
      if (issue.code == 'LOW_CONFIDENCE') continue;

      // Check global cooldown
      if (_lastFeedbackTime != null &&
          now.difference(_lastFeedbackTime!) < globalCooldown) {
        return null; // Global cooldown blocks everything
      }

      // Check per-code cooldown
      final lastCodeTime = _lastCodeTimes[issue.code];
      if (lastCodeTime != null &&
          now.difference(lastCodeTime) < perCodeCooldown) {
        continue; // This code is on cooldown, try the next
      }

      // This issue passes all checks
      _lastFeedbackTime = now;
      _lastCodeTimes[issue.code] = now;

      return FilteredFeedback(issue: issue, status: feedback.status);
    }

    return null; // All issues were throttled
  }

  /// Reset all cooldown state (e.g. when exercise changes or counter resets).
  void reset() {
    _lastFeedbackTime = null;
    _lastCodeTimes.clear();
  }
}
