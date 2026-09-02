import 'package:shared_preferences/shared_preferences.dart';

/// Whether overdue-reminder notifications should play a sound and vibrate.
/// Device-local, not part of the backed-up data.
class NotificationPreferences {
  static const _key = 'notification_sound_and_vibration_enabled';

  Future<bool> isSoundAndVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setSoundAndVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
