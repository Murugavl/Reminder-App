import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';
import 'overdue_notification_plan.dart';

/// Real [NotificationService] backed by `flutter_local_notifications`.
///
/// Usable from any isolate — the app's main isolate constructs one to wire
/// up tap handling and permissions, and the Workmanager background isolate
/// constructs its own separate instance to post/update notifications.
class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize({required void Function(String? payload) onNotificationTap}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) => onNotificationTap(response.payload),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // Both channels are created up front so toggling the sound/vibration
    // preference just changes which channel future notifications go to —
    // Android freezes a channel's own sound/vibration behavior once it
    // exists (API 26+), so there's no way to "update" one in place.
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        overdueChannelId,
        overdueChannelName,
        description: overdueChannelDescription,
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        overdueSilentChannelId,
        overdueSilentChannelName,
        description: overdueChannelDescription,
        importance: Importance.high,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<NotificationAppLaunchDetails?> getLaunchDetails() => _plugin.getNotificationAppLaunchDetails();

  @override
  Future<void> showOverdueNotifications(
    List<OverdueCustomerNotificationData> entries, {
    required bool soundAndVibrationEnabled,
  }) async {
    final plan = buildOverdueNotificationPlan(entries);
    final channelId = soundAndVibrationEnabled ? overdueChannelId : overdueSilentChannelId;
    final channelName = soundAndVibrationEnabled ? overdueChannelName : overdueSilentChannelName;

    // Drop any stale summary first: if we've fallen to 0 or 1 overdue
    // customers since the last check, a summary shouldn't linger.
    await _plugin.cancel(id: overdueSummaryNotificationId);

    for (final spec in plan.individual) {
      await _plugin.show(
        id: spec.notificationId,
        title: spec.title,
        body: spec.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: overdueChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            groupKey: overdueGroupKey,
            // Not one-shot: stays until the customer's service is logged.
            ongoing: true,
            autoCancel: false,
            // Ignored on API 26+ (the channel's own setting wins there) but
            // correct for API 24-25, which this app still supports.
            playSound: soundAndVibrationEnabled,
            enableVibration: soundAndVibrationEnabled,
          ),
        ),
        payload: spec.customerId,
      );
    }

    final summary = plan.summary;
    if (summary != null) {
      await _plugin.show(
        id: summary.notificationId,
        title: summary.title,
        body: summary.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: overdueChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            groupKey: overdueGroupKey,
            setAsGroupSummary: true,
            ongoing: true,
            autoCancel: false,
            playSound: soundAndVibrationEnabled,
            enableVibration: soundAndVibrationEnabled,
            styleInformation: InboxStyleInformation(
              summary.lines,
              contentTitle: summary.title,
              summaryText: summary.body,
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<void> cancelForCustomer(String customerId) {
    return _plugin.cancel(id: notificationIdForCustomer(customerId));
  }
}
