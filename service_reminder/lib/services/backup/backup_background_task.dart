import '../../data/local/database.dart';
import 'google_drive_backup_service.dart';

/// Unique name Workmanager tracks this registration under.
const weeklyBackupTaskUniqueName = 'service_reminder.weekly_backup';

/// The task identifier delivered back to the shared callback dispatcher.
const weeklyBackupTaskName = 'weeklyBackupCheck';

const weeklyBackupFrequency = Duration(days: 7);

/// Runs the automatic weekly backup in whatever isolate it's called from.
/// Builds its own fresh dependencies, since a background isolate shares no
/// state with the main isolate's Riverpod providers.
///
/// This only ever runs `interactive: false` — if the user's Drive
/// authorization has lapsed, it fails softly (no prompt is possible from a
/// background isolate) rather than crashing the task. The user will notice
/// on their next visit to Settings, where "Backup now" is always available.
Future<void> runWeeklyBackupInBackground() async {
  final db = AppDatabase();
  try {
    final backupService = GoogleDriveBackupService(db);
    await backupService.initialize();
    if (backupService.currentAccount == null) return;

    await backupService.backupNow(interactive: false);
  } finally {
    await db.close();
  }
}
