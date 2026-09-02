import 'package:flutter_test/flutter_test.dart';
import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/services/notifications/overdue_notification_plan.dart';

Customer _customer({required String id, required String name}) {
  final now = DateTime(2026, 1, 1);
  return Customer(
    id: id,
    name: name,
    phone: '000',
    address: 'Addr',
    installationDate: now,
    nextDueDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('no overdue customers produces no individual and no summary notification', () {
    final plan = buildOverdueNotificationPlan([]);

    expect(plan.individual, isEmpty);
    expect(plan.summary, isNull);
  });

  test('a single overdue customer gets one notification and no group summary', () {
    final entry = OverdueCustomerNotificationData(
      customer: _customer(id: '1', name: 'Alice'),
      lastServiceDate: DateTime(2026, 1, 1),
    );

    final plan = buildOverdueNotificationPlan([entry]);

    expect(plan.individual, hasLength(1));
    expect(plan.summary, isNull);
    expect(plan.individual.single.customerId, '1');
    expect(
      plan.individual.single.body,
      'Service due: Alice — last service 01 Jan 2026. Tap to update.',
    );
  });

  test('multiple overdue customers get individual notifications plus a group summary', () {
    final entries = [
      OverdueCustomerNotificationData(
        customer: _customer(id: '1', name: 'Alice'),
        lastServiceDate: DateTime(2026, 1, 1),
      ),
      OverdueCustomerNotificationData(
        customer: _customer(id: '2', name: 'Bob'),
        lastServiceDate: DateTime(2026, 2, 15),
      ),
    ];

    final plan = buildOverdueNotificationPlan(entries);

    expect(plan.individual, hasLength(2));
    expect(plan.summary, isNotNull);
    expect(plan.summary!.notificationId, overdueSummaryNotificationId);
    expect(plan.summary!.title, '2 customers need service');
    expect(plan.summary!.body, contains('Alice'));
    expect(plan.summary!.body, contains('Bob'));
    expect(plan.summary!.lines, hasLength(2));
    expect(plan.summary!.lines[0], contains('Alice'));
    expect(plan.summary!.lines[1], contains('Bob'));
  });

  test('notification id for a customer is stable across calls and differs between customers', () {
    final idA1 = notificationIdForCustomer('customer-a');
    final idA2 = notificationIdForCustomer('customer-a');
    final idB = notificationIdForCustomer('customer-b');

    expect(idA1, idA2);
    expect(idA1, isNot(idB));
    expect(idA1, greaterThanOrEqualTo(0)); // must be a valid positive Android notification id
  });

  test('individual notification ids never collide with the reserved summary id', () {
    for (final id in ['a', 'b', 'c', 'customer-123', 'zzz']) {
      expect(notificationIdForCustomer(id), isNot(overdueSummaryNotificationId));
    }
  });
}
