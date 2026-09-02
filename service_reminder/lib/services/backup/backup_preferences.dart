import 'package:shared_preferences/shared_preferences.dart';

/// Whether automatic weekly backup is turned on. Deliberately stored outside
/// the drift database (via shared_preferences) since it's a device-local
/// setting, not app data — a restore from backup shouldn't touch it.
class BackupPreferences {
  static const _autoBackupEnabledKey = 'auto_backup_enabled';

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }
}
