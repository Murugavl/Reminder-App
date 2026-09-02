import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notifications/local_notification_service.dart';
import '../services/notifications/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService(FlutterLocalNotificationsPlugin());
});
