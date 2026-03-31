import 'dart:async';
import 'dart:io';

import 'package:fitness_counter/fitness_counter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service that converts form correction feedback into spoken voice messages.
///
/// Uses `flutter_tts` (native platform TTS) for cross-platform support.
/// Implements Option B interruption: when a [FormStatus.bad] message arrives
/// while a lower-priority message is speaking, the current utterance is
/// stopped and the bad message is spoken immediately.
class VoiceGuidanceService {
  final FlutterTts _tts;
  final Stopwatch _latencyStopwatch = Stopwatch();
  final Completer<void> _initCompleter = Completer<void>();

  /// Whether voice guidance is enabled. Toggle via [setEnabled].
  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  /// Whether TTS is currently speaking.
  bool _isSpeaking = false;

  /// The severity of the currently-speaking message (for interruption logic).
  FormStatus? _currentSeverity;

  /// Tracks when the start-position prompt was last spoken, to avoid
  /// repeating every frame. Uses the same cooldown as form feedback (3s).
  DateTime? _lastStartPromptTime;
  static const Duration _startPromptCooldown = Duration(seconds: 3);

  /// Maps issue codes to short, actionable voice phrases.
  static const Map<String, String> _voicePhrases = {
    // Lateral Raise Form
    'ELBOW_BENT': 'Keep your arms straight',
    'ELBOW_SOFT': 'Extend your elbows more',
    'TRUNK_LEAN': 'Keep your torso upright',
    'TRUNK_SHIFT': 'Keep your hips centered',
    'SHRUGGING': 'Relax your shoulders away from ears',

    // Bench Press Form
    'ELBOW_FLARE_BAD': 'Tuck your elbows, flaring is dangerous',
    'ELBOW_FLARE_WARN': 'Tuck your elbows closer to your body',
    'UNEVEN_PRESS_BAD': 'Push evenly with both arms',
    'UNEVEN_PRESS_WARN': 'Keep the bar level',
    'HIPS_RISING_BAD': 'Keep your glutes on the bench',
    'HIPS_RISING_WARN': 'Don\'t lift your hips',

    // Single Squat Form
    'KNEE_VALGUS_BAD': 'Push your knees outward, they are caving in',
    'KNEE_VALGUS_WARN': 'Keep your knees over your toes',
    'TRUNK_LEAN_BAD': 'Keep your chest up, do not lean too far forward',
    'TRUNK_LEAN_WARN': 'Keep your chest up',
    'DEPTH_WARN': 'Try to squat lower',

    // LOW_CONFIDENCE is intentionally absent — always silent
  };

  VoiceGuidanceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _initTts();
  }

  Future<void> _initTts() async {
    // On iOS, the camera plugin sets the AVAudioSession category to .record
    // or .playAndRecord, which blocks AVSpeechSynthesizer from producing audio.
    // We must explicitly configure the audio session to allow TTS playback
    // alongside the camera. This is the #1 cause of TTS silence on real devices
    // (works fine on simulator where audio session handling is lenient).
    if (Platform.isIOS) {
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]);
    }

    // Configure TTS settings
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.55); // Slightly elevated for coaching brevity
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false); // Non-blocking async speech

    // Track speaking state with latency logging
    _tts.setStartHandler(() {
      _isSpeaking = true;
      if (_latencyStopwatch.isRunning) {
        final latencyMs = _latencyStopwatch.elapsedMilliseconds;
        _latencyStopwatch.stop();
        debugPrint('TTS_LATENCY: speak→start = ${latencyMs}ms');
      }
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _currentSeverity = null;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _currentSeverity = null;
    });

    _tts.setErrorHandler((msg) {
      debugPrint('TTS_ERROR: $msg');
      _isSpeaking = false;
      _currentSeverity = null;
      _latencyStopwatch.stop();
    });

    // Try to select a premium/enhanced voice
    await _selectBestVoice();
    debugPrint('TTS_INIT: Voice guidance service initialized');
    _initCompleter.complete();
  }

  /// Attempt to select a premium neural voice if available.
  Future<void> _selectBestVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices == null || voices is! List) return;

      final voiceList = List<Map<dynamic, dynamic>>.from(
        voices.map((v) => Map<dynamic, dynamic>.from(v as Map)),
      );

      // Filter for English voices
      final englishVoices = voiceList.where((v) {
        final locale = (v['locale'] ?? v['language'] ?? '').toString();
        return locale.startsWith('en');
      }).toList();

      if (englishVoices.isEmpty) return;

      // Prefer "enhanced" or "premium" voices (iOS naming convention)
      final enhanced = englishVoices.where((v) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        return name.contains('enhanced') || name.contains('premium');
      }).toList();

      if (enhanced.isNotEmpty) {
        await _tts.setVoice({
          'name': enhanced.first['name'].toString(),
          'locale': enhanced.first['locale']?.toString() ?? 'en-US',
        });
        debugPrint(
          'TTS_INIT: Selected enhanced voice: ${enhanced.first['name']}',
        );
      } else {
        debugPrint('TTS_INIT: No enhanced voice found, using device default');
      }
    } catch (e) {
      debugPrint('TTS_INIT: Could not select voice, using default: $e');
    }
  }

  /// Speak a filtered feedback item.
  ///
  /// Implements Option B interruption: if a `bad` issue arrives while a
  /// `warning` is speaking, the current utterance is stopped and the bad
  /// message is spoken immediately.
  Future<void> speak(FilteredFeedback feedback) async {
    if (!_isEnabled) return;

    // Wait for TTS engine to finish initialising (typically instant after
    // the first frame, but guards against a race on cold start).
    await _initCompleter.future;

    final phrase = _voicePhrases[feedback.issue.code];
    if (phrase == null) {
      return; // No voice phrase for this code (e.g. LOW_CONFIDENCE)
    }

    // Interruption logic (Option B)
    if (_isSpeaking) {
      if (feedback.issue.severity == FormStatus.bad &&
          _currentSeverity != FormStatus.bad) {
        // Bad preempts non-bad: stop current and speak immediately
        debugPrint(
          'TTS_INTERRUPT: Stopping ${_currentSeverity?.name} for ${feedback.issue.code} (bad)',
        );
        await _tts.stop();
      } else {
        // Same or lower priority while speaking: drop the new message
        return;
      }
    }

    _currentSeverity = feedback.issue.severity;

    // Start latency measurement
    _latencyStopwatch.reset();
    _latencyStopwatch.start();

    debugPrint(
      'TTS_SPEAK: "$phrase" [${feedback.issue.severity.name}] code=${feedback.issue.code}',
    );
    await _tts.speak(phrase);
  }

  /// Speak an exercise start-position prompt
  /// (e.g. "Lower arms to start", "Stand straight to begin").
  ///
  /// Uses a 3-second cooldown (matching [FeedbackCooldownManager] per-code
  /// default) to avoid overwhelming the user with repeated instructions.
  /// This prompt has lower priority than form corrections and will not
  /// interrupt an in-progress utterance.
  Future<void> speakStartPrompt(String prompt) async {
    if (!_isEnabled || prompt.isEmpty) return;

    // Don't interrupt any in-progress speech
    if (_isSpeaking) return;

    // Throttle: only re-speak after cooldown
    final now = DateTime.now();
    if (_lastStartPromptTime != null &&
        now.difference(_lastStartPromptTime!) < _startPromptCooldown) {
      return;
    }

    await _initCompleter.future;

    _lastStartPromptTime = now;

    debugPrint('TTS_START_PROMPT: "$prompt"');
    await _tts.speak(prompt);
  }

  /// Reset the start-prompt cooldown (e.g. when exercise changes).
  void resetStartPromptCooldown() {
    _lastStartPromptTime = null;
  }

  /// Stop any currently speaking utterance immediately.
  ///
  /// Unlike [setEnabled], this does **not** disable future speech — it only
  /// cancels the in-progress utterance. Use this when the user triggers
  /// a demo video and you want to silence feedback without toggling the
  /// enabled state.
  Future<void> stop() async {
    debugPrint('TTS_STOP: stopping current utterance');
    await _tts.stop();
    _isSpeaking = false;
    _currentSeverity = null;
    if (_latencyStopwatch.isRunning) {
      _latencyStopwatch.stop();
    }
  }

  /// Enable or disable voice guidance.
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint(
      'TTS_TOGGLE: voice guidance ${enabled ? "enabled" : "disabled"}',
    );
    if (!enabled && _isSpeaking) {
      _tts.stop();
    }
  }

  /// Dispose of TTS resources.
  void dispose() {
    _tts.stop();
  }
}
