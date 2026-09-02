import 'package:intl/intl.dart';

import '../../data/local/database.dart';

/// A customer that is currently overdue, plus the date their reminder text
/// should reference: their most recent service, or installation_date if
/// they've never had one logged.
class OverdueCustomerNotificationData {
  const OverdueCustomerNotificationData({required this.customer, required this.lastServiceDate});

  final Customer customer;
  final DateTime lastServiceDate;
}

/// One per-customer notification to post.
class CustomerNotificationSpec {
  const CustomerNotificationSpec({
    required this.customerId,
    required this.notificationId,
    required this.title,
    required this.body,
  });

  final String customerId;
  final int notificationId;
  final String title;
  final String body;
}

/// The group-summary notification to post when there's more than one
/// overdue customer, so Android collapses the individual notifications
/// instead of spamming the shade with one-per-customer.
class OverdueGroupSummarySpec {
  const OverdueGroupSummarySpec({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.lines,
  });

  final int notificationId;
  final String title;
  final String body;
  final List<String> lines;
}

class OverdueNotificationPlan {
  const OverdueNotificationPlan({required this.individual, this.summary});

  final List<CustomerNotificationSpec> individual;
  final OverdueGroupSummarySpec? summary;
}

/// Notification channel + grouping constants shared between the real
/// implementation and anything that needs to reason about notification ids
/// (e.g. cancelling a specific customer's notification).
const overdueChannelId = 'service_reminders';
const overdueChannelName = 'Service Reminders';
const overdueChannelDescription = 'Alerts when a customer service is overdue';

/// A second channel with sound/vibration disabled. Android freezes a
/// channel's sound/vibration behavior once it's created (API 26+), so
/// honoring the user's sound/vibration preference means picking between two
/// pre-created channels rather than trying to mutate one.
const overdueSilentChannelId = 'service_reminders_silent';
const overdueSilentChannelName = 'Service Reminders (silent)';

const overdueGroupKey = 'service_reminder.overdue_group';
const overdueSummaryNotificationId = 0;

/// A stable notification id derived from the customer's uuid, so posting
/// again for the same customer updates their existing notification instead
/// of creating a duplicate.
int notificationIdForCustomer(String customerId) => customerId.hashCode & 0x7fffffff;

final _dateFormat = DateFormat('dd MMM yyyy');

/// Decides what notifications should be on screen for the given overdue
/// customers. Pure and platform-independent — no plugin calls happen here.
OverdueNotificationPlan buildOverdueNotificationPlan(List<OverdueCustomerNotificationData> entries) {
  final individual = [
    for (final entry in entries)
      CustomerNotificationSpec(
        customerId: entry.customer.id,
        notificationId: notificationIdForCustomer(entry.customer.id),
        title: 'Service Reminder',
        body: 'Service due: ${entry.customer.name} — last service '
            '${_dateFormat.format(entry.lastServiceDate)}. Tap to update.',
      ),
  ];

  if (entries.length <= 1) {
    return OverdueNotificationPlan(individual: individual);
  }

  return OverdueNotificationPlan(
    individual: individual,
    summary: OverdueGroupSummarySpec(
      notificationId: overdueSummaryNotificationId,
      title: '${entries.length} customers need service',
      body: entries.map((e) => e.customer.name).join(', '),
      lines: [
        for (final entry in entries)
          '${entry.customer.name} — last service ${_dateFormat.format(entry.lastServiceDate)}',
      ],
    ),
  );
}
