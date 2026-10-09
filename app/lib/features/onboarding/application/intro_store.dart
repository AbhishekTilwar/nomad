import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the first-run intro carousel has been completed.
class IntroStore {
  const IntroStore();

  static const key = 'intro_seen_v1';

  Future<bool> hasSeen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    } catch (_) {
      // Non-critical: the intro just shows again next time.
    }
  }
}
