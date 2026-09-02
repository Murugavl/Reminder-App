import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'providers/backup_providers.dart';
import 'providers/notification_providers.dart';
import 'providers/settings_providers.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/home_screen.dart';
import 'services/backup/backup_background_task.dart';
import 'services/backup/backup_preferences.dart';
import 'services/reminders/reminder_background_task.dart';
import 'services/workmanager_callback_dispatcher.dart';

/// Lets the notification-tap handler navigate without needing a
/// [BuildContext] (it can fire while the app has no active route, e.g. right
/// after a cold start).
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      overdueReminderTaskUniqueName,
      overdueReminderTaskName,
      frequency: overdueReminderCheckFrequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    // The weekly backup task is opt-in (Settings toggle) — only (re-)arm it
    // here if the user previously turned it on, so the schedule survives
    // app restarts/updates.
    if (await BackupPreferences().isAutoBackupEnabled()) {
      await Workmanager().registerPeriodicTask(
        weeklyBackupTaskUniqueName,
        weeklyBackupTaskName,
        frequency: weeklyBackupFrequency,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }
  } catch (_) {
    // Workmanager only has a real platform backing on Android/iOS; skip
    // silently on other targets (desktop/web) rather than crashing startup.
  }

  runApp(const ProviderScope(child: ServiceReminderApp()));
}

class ServiceReminderApp extends ConsumerStatefulWidget {
  const ServiceReminderApp({super.key});

  @override
  ConsumerState<ServiceReminderApp> createState() => _ServiceReminderAppState();
}

class _ServiceReminderAppState extends ConsumerState<ServiceReminderApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotifications();
      _initBackup();
    });
  }

  Future<void> _initNotifications() async {
    try {
      final notifications = ref.read(notificationServiceProvider);
      await notifications.initialize(onNotificationTap: _openCustomerFromPayload);
      await notifications.requestPermission();

      final launchDetails = await notifications.getLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _openCustomerFromPayload(launchDetails?.notificationResponse?.payload);
      }
    } catch (_) {
      // No real notification platform channel on this build/platform (e.g.
      // web, desktop, or a test harness) — nothing to wire up.
    }
  }

  Future<void> _initBackup() async {
    try {
      // Silently restores any previous Google sign-in session, if any. The
      // app is fully usable whether or not this succeeds — Drive is backup
      // only, never required to use Service Reminder.
      await ref.read(backupServiceProvider).initialize();
    } catch (_) {
      // No real Google Sign-In platform channel on this build/platform, or
      // no OAuth client configured yet — nothing to wire up.
    }
  }

  void _openCustomerFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: payload)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Service Reminder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
