import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationAppLaunchDetails;

import 'overdue_notification_plan.dart';

/// Abstraction over the platform notification plugin so the app's
/// notification decisions (what to show, when to cancel) can be exercised in
/// tests without a real Android platform channel behind them.
abstract class NotificationService {
  /// Creates the "service_reminders" channel and wires up tap handling.
  /// [onNotificationTap] receives the tapped notification's payload (the
  /// overdue customer's id, or null for the group summary).
  Future<void> initialize({required void Function(String? payload) onNotificationTap});

  /// Requests the Android 13+ POST_NOTIFICATIONS runtime permission. Returns
  /// whether it's granted (a no-op `true` on platforms/versions that don't
  /// need it).
  Future<bool> requestPermission();

  /// Details of the notification that launched the app, if it was launched
  /// by tapping one (cold start case — [onNotificationTap] alone only fires
  /// for taps while the app process is already alive).
  Future<NotificationAppLaunchDetails?> getLaunchDetails();

  /// Upserts one notification per overdue customer (updating in place if
  /// still overdue from a previous check) and, for more than one, an
  /// Android group-summary notification. Notifications are `ongoing` — the
  /// user can't swipe them away; only [cancelForCustomer] (called once a
  /// service is logged) clears them.
  ///
  /// [soundAndVibrationEnabled] reflects the user's Settings toggle for this
  /// check.
  Future<void> showOverdueNotifications(
    List<OverdueCustomerNotificationData> entries, {
    required bool soundAndVibrationEnabled,
  });

  /// Clears the given customer's overdue notification, e.g. after a service
  /// is logged for them and they're no longer overdue.
  Future<void> cancelForCustomer(String customerId);
}
