import 'package:workmanager/workmanager.dart';

import 'backup/backup_background_task.dart';
import 'reminders/reminder_background_task.dart';

/// The single Workmanager entry point for this app — Workmanager only
/// supports one callback dispatcher, so it fans out to each background
/// task's own runner by task name. Must stay a top-level function annotated
/// `@pragma('vm:entry-point')` so the Dart compiler doesn't tree-shake it
/// away.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case overdueReminderTaskName:
        await runOverdueReminderCheckInBackground();
      case weeklyBackupTaskName:
        await runWeeklyBackupInBackground();
    }
    return true;
  });
}
