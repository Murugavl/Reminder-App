import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup/backup_preferences.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/google_drive_backup_service.dart';
import '../services/backup/weekly_backup_scheduler.dart';
import 'database_providers.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return GoogleDriveBackupService(ref.watch(appDatabaseProvider));
});

final backupPreferencesProvider = Provider<BackupPreferences>((ref) => BackupPreferences());

final weeklyBackupSchedulerProvider = Provider<WeeklyBackupScheduler>((ref) {
  return WorkmanagerWeeklyBackupScheduler();
});

/// The currently signed-in Google account, or null. Updates live as the user
/// signs in/out.
final signedInAccountProvider = StreamProvider<SignedInAccount?>((ref) {
  final service = ref.watch(backupServiceProvider);
  return service.accountChanges.startWith(service.currentAccount);
});

/// Whether automatic weekly backup is turned on. Call
/// `ref.invalidate(autoBackupEnabledProvider)` after changing it.
final autoBackupEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(backupPreferencesProvider).isAutoBackupEnabled();
});

extension _StartWith<T> on Stream<T> {
  /// Prepends [value] so late subscribers see the current state immediately
  /// instead of waiting for the next sign-in/out event.
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
