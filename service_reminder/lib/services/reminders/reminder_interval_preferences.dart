import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/customer_repository.dart' show defaultReminderIntervalMonths;

/// The app-wide default reminder interval (in months) used for any customer
/// without their own per-customer override. Device-local, not part of the
/// backed-up data.
class ReminderIntervalPreferences {
  static const _key = 'default_reminder_interval_months';

  Future<int> getDefaultIntervalMonths() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? defaultReminderIntervalMonths;
  }

  Future<void> setDefaultIntervalMonths(int months) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, months);
  }
}
