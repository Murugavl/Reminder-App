import 'package:service_reminder/services/backup/weekly_backup_scheduler.dart';

class FakeWeeklyBackupScheduler implements WeeklyBackupScheduler {
  int enableCallCount = 0;
  int disableCallCount = 0;

  @override
  Future<void> enable() async {
    enableCallCount++;
  }

  @override
  Future<void> disable() async {
    disableCallCount++;
  }
}
