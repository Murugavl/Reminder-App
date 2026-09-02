import 'package:workmanager/workmanager.dart';

import 'backup_background_task.dart';

/// Thin wrapper around the Workmanager calls needed to turn the automatic
/// weekly backup on/off, kept behind an interface so the Settings screen's
/// toggle can be tested without a real Workmanager platform channel behind
/// it (there isn't one outside a real Android/iOS build).
abstract class WeeklyBackupScheduler {
  Future<void> enable();
  Future<void> disable();
}

class WorkmanagerWeeklyBackupScheduler implements WeeklyBackupScheduler {
  @override
  Future<void> enable() {
    return Workmanager().registerPeriodicTask(
      weeklyBackupTaskUniqueName,
      weeklyBackupTaskName,
      frequency: weeklyBackupFrequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  @override
  Future<void> disable() => Workmanager().cancelByUniqueName(weeklyBackupTaskUniqueName);
}
