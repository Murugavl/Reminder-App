import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/local/database.dart';
import '../../data/repositories/customer_repository.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_preferences.dart';
import 'overdue_reminder_checker.dart';

/// Unique name Workmanager tracks this registration under (used to
/// re-register idempotently and to query/cancel it).
const overdueReminderTaskUniqueName = 'service_reminder.overdue_check';

/// The task identifier delivered back to the shared callback dispatcher.
const overdueReminderTaskName = 'overdueReminderCheck';

const overdueReminderCheckFrequency = Duration(hours: 24);

/// Runs the overdue-reminder check in whatever isolate it's called from,
/// building its own fresh dependencies — used by the Workmanager background
/// isolate, which shares no state with the main isolate's Riverpod
/// providers.
Future<void> runOverdueReminderCheckInBackground() async {
  final db = AppDatabase();
  try {
    final notifications = LocalNotificationService(FlutterLocalNotificationsPlugin());
    // A fresh isolate has its own plugin instance, so the channel needs
    // (re-)creating here too. No UI exists in this isolate, so tap handling
    // is a no-op — real navigation happens when the user opens the app, via
    // the foreground/cold-start paths wired up in main().
    await notifications.initialize(onNotificationTap: (_) {});
    final soundAndVibrationEnabled = await NotificationPreferences().isSoundAndVibrationEnabled();

    await checkOverdueRemindersAndNotify(
      repository: CustomerRepository(db),
      notifications: notifications,
      soundAndVibrationEnabled: soundAndVibrationEnabled,
    );
  } finally {
    await db.close();
  }
}
