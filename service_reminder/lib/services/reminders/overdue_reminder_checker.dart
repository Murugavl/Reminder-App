import '../../data/repositories/customer_repository.dart';
import '../notifications/notification_service.dart';
import '../notifications/overdue_notification_plan.dart';

/// The single check-and-notify routine, shared by the daily Workmanager task
/// and the "Check reminders now" debug button so both paths behave
/// identically. Returns the number of customers currently overdue.
Future<int> checkOverdueRemindersAndNotify({
  required CustomerRepository repository,
  required NotificationService notifications,
  bool soundAndVibrationEnabled = true,
}) async {
  final overdueCustomers = await repository.getOverdueCustomers();

  final entries = <OverdueCustomerNotificationData>[];
  for (final customer in overdueCustomers) {
    final history = await repository.getCustomerWithHistory(customer.id);
    final lastServiceDate =
        history.serviceRecords.isNotEmpty ? history.serviceRecords.first.serviceDate : customer.installationDate;
    entries.add(OverdueCustomerNotificationData(customer: customer, lastServiceDate: lastServiceDate));
  }

  await notifications.showOverdueNotifications(entries, soundAndVibrationEnabled: soundAndVibrationEnabled);
  return entries.length;
}
