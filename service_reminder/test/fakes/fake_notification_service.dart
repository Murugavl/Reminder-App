import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:service_reminder/services/notifications/notification_service.dart';
import 'package:service_reminder/services/notifications/overdue_notification_plan.dart';

/// Records calls instead of touching a real platform channel, so screens and
/// the reminder-check routine can be tested without Android/iOS behind them.
class FakeNotificationService implements NotificationService {
  bool initializeCalled = false;
  bool permissionRequested = false;
  final List<List<OverdueCustomerNotificationData>> showCalls = [];
  final List<bool> soundAndVibrationEnabledCalls = [];
  final List<String> canceledCustomerIds = [];

  List<OverdueCustomerNotificationData>? get lastShown => showCalls.isEmpty ? null : showCalls.last;

  @override
  Future<void> initialize({required void Function(String? payload) onNotificationTap}) async {
    initializeCalled = true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?> getLaunchDetails() async => null;

  @override
  Future<void> showOverdueNotifications(
    List<OverdueCustomerNotificationData> entries, {
    required bool soundAndVibrationEnabled,
  }) async {
    showCalls.add(entries);
    soundAndVibrationEnabledCalls.add(soundAndVibrationEnabled);
  }

  @override
  Future<void> cancelForCustomer(String customerId) async {
    canceledCustomerIds.add(customerId);
  }
}
