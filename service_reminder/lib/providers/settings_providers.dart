import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notifications/notification_preferences.dart';
import '../services/reminders/reminder_interval_preferences.dart';
import '../services/theme_preferences.dart';

final reminderIntervalPreferencesProvider = Provider<ReminderIntervalPreferences>((ref) {
  return ReminderIntervalPreferences();
});

/// Call `ref.invalidate(defaultReminderIntervalMonthsProvider)` after
/// changing it.
final defaultReminderIntervalMonthsProvider = FutureProvider<int>((ref) {
  return ref.watch(reminderIntervalPreferencesProvider).getDefaultIntervalMonths();
});

final notificationPreferencesProvider = Provider<NotificationPreferences>((ref) {
  return NotificationPreferences();
});

/// Call `ref.invalidate(soundAndVibrationEnabledProvider)` after changing it.
final soundAndVibrationEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(notificationPreferencesProvider).isSoundAndVibrationEnabled();
});

final themePreferencesProvider = Provider<ThemePreferences>((ref) => ThemePreferences());

/// Call `ref.invalidate(themeModeProvider)` after changing it.
final themeModeProvider = FutureProvider<ThemeMode>((ref) {
  return ref.watch(themePreferencesProvider).getThemeMode();
});
