import 'package:fitness_counter/fitness_counter.dart';
import 'package:test/test.dart';

void main() {
  // Helper factories
  FormFeedback makeFeedback({
    required FormStatus status,
    required List<FormIssue> issues,
  }) => FormFeedback(status: status, issues: issues);

  FormIssue makeIssue(String code, FormStatus severity) =>
      FormIssue(code: code, message: 'msg', severity: severity);

  group('FeedbackCooldownManager', () {
    late DateTime fakeNow;
    late FeedbackCooldownManager manager;

    setUp(() {
      fakeNow = DateTime(2024, 1, 1, 12, 0, 0);
      manager = FeedbackCooldownManager(
        globalCooldown: const Duration(seconds: 2),
        perCodeCooldown: const Duration(seconds: 3),
        clock: () => fakeNow,
      );
    });

    test('first feedback passes through immediately', () {
      final feedback = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );

      final result = manager.processFeedback(feedback);
      expect(result, isNotNull);
      expect(result!.issue.code, 'ELBOW_BENT');
    });

    test('good form returns null', () {
      final feedback = makeFeedback(status: FormStatus.good, issues: []);

      final result = manager.processFeedback(feedback);
      expect(result, isNull);
    });

    test('same code blocked within per-code cooldown', () {
      final feedback = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );

      manager.processFeedback(feedback); // passes

      fakeNow = fakeNow.add(const Duration(seconds: 1)); // 1s later
      final result = manager.processFeedback(feedback);
      expect(result, isNull); // still within 3s per-code cooldown
    });

    test('same code allowed after per-code cooldown expires', () {
      final feedback = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );

      manager.processFeedback(feedback); // passes

      fakeNow = fakeNow.add(const Duration(seconds: 3)); // 3s later
      final result = manager.processFeedback(feedback);
      expect(result, isNotNull);
      expect(result!.issue.code, 'ELBOW_BENT');
    });

    test('different code blocked within global cooldown', () {
      final feedback1 = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );
      final feedback2 = makeFeedback(
        status: FormStatus.warning,
        issues: [makeIssue('TRUNK_LEAN', FormStatus.warning)],
      );

      manager.processFeedback(feedback1); // passes

      fakeNow = fakeNow.add(const Duration(seconds: 1)); // 1s later
      final result = manager.processFeedback(feedback2);
      expect(result, isNull); // global 2s cooldown not elapsed
    });

    test('different code allowed after global cooldown', () {
      final feedback1 = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );
      final feedback2 = makeFeedback(
        status: FormStatus.warning,
        issues: [makeIssue('TRUNK_LEAN', FormStatus.warning)],
      );

      manager.processFeedback(feedback1); // passes

      fakeNow = fakeNow.add(const Duration(seconds: 2)); // 2s later
      final result = manager.processFeedback(feedback2);
      expect(result, isNotNull);
      expect(result!.issue.code, 'TRUNK_LEAN');
    });

    test('bad severity preempts warning when both in same feedback', () {
      final feedback = makeFeedback(
        status: FormStatus.bad,
        issues: [
          makeIssue('TRUNK_LEAN', FormStatus.warning),
          makeIssue('ELBOW_BENT', FormStatus.bad),
        ],
      );

      final result = manager.processFeedback(feedback);
      expect(result, isNotNull);
      expect(result!.issue.code, 'ELBOW_BENT'); // bad wins over warning
      expect(result.issue.severity, FormStatus.bad);
    });

    test('falls back to warning if bad code is on cooldown', () {
      // First: bad code fires
      final badFeedback = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );
      manager.processFeedback(badFeedback);

      // 2s later: global cooldown elapsed but ELBOW_BENT still on per-code cooldown
      fakeNow = fakeNow.add(const Duration(seconds: 2));
      final mixed = makeFeedback(
        status: FormStatus.bad,
        issues: [
          makeIssue('ELBOW_BENT', FormStatus.bad), // still on cooldown
          makeIssue('TRUNK_LEAN', FormStatus.warning), // should pass
        ],
      );

      final result = manager.processFeedback(mixed);
      expect(result, isNotNull);
      expect(result!.issue.code, 'TRUNK_LEAN'); // falls back to warning
    });

    test('LOW_CONFIDENCE is always skipped', () {
      final feedback = makeFeedback(
        status: FormStatus.warning,
        issues: [makeIssue('LOW_CONFIDENCE', FormStatus.warning)],
      );

      final result = manager.processFeedback(feedback);
      expect(result, isNull);
    });

    test('reset clears all cooldown state', () {
      final feedback = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );

      manager.processFeedback(feedback); // passes

      manager.reset();

      // Immediately after reset, same code should pass again
      final result = manager.processFeedback(feedback);
      expect(result, isNotNull);
      expect(result!.issue.code, 'ELBOW_BENT');
    });

    test('custom cooldown durations are respected', () {
      final customManager = FeedbackCooldownManager(
        globalCooldown: const Duration(seconds: 1),
        perCodeCooldown: const Duration(seconds: 5),
        clock: () => fakeNow,
      );

      final feedback = makeFeedback(
        status: FormStatus.bad,
        issues: [makeIssue('ELBOW_BENT', FormStatus.bad)],
      );

      customManager.processFeedback(feedback);

      // 1s later: global passed, but per-code (5s) not elapsed
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      expect(customManager.processFeedback(feedback), isNull);

      // 5s total: both cooldowns elapsed
      fakeNow = fakeNow.add(const Duration(seconds: 4));
      expect(customManager.processFeedback(feedback), isNotNull);
    });
  });
}
