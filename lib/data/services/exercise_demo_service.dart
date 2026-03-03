import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/widgets/exercise_selector.dart';

/// Service that tracks whether the user has seen the instructional demo
/// for each exercise. Uses [SharedPreferences] for persistence.
///
/// Scalable: new exercises only need an [ExerciseType] entry — the key
/// is derived automatically from the enum name.
class ExerciseDemoService {
  static const _keyPrefix = 'demo_seen_';

  SharedPreferences? _prefs;

  /// Initialise the underlying [SharedPreferences] instance.
  /// Call once at app startup or before first use.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Whether the user has already seen the demo for [exercise].
  Future<bool> hasSeenDemo(ExerciseType exercise) async {
    await init();
    return _prefs!.getBool('$_keyPrefix${exercise.name}') ?? false;
  }

  /// Mark the demo for [exercise] as seen.
  Future<void> markDemoSeen(ExerciseType exercise) async {
    await init();
    await _prefs!.setBool('$_keyPrefix${exercise.name}', true);
  }

  /// Reset all demo-seen flags (useful for testing / debug).
  Future<void> resetAll() async {
    await init();
    for (final exercise in ExerciseType.values) {
      await _prefs!.remove('$_keyPrefix${exercise.name}');
    }
  }
}
