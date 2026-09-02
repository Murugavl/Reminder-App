import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/data/repositories/customer_repository.dart';
import 'package:service_reminder/services/reminders/overdue_reminder_checker.dart';

import '../../fakes/fake_notification_service.dart';

void main() {
  late AppDatabase db;
  late CustomerRepository repo;
  late FakeNotificationService notifications;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CustomerRepository(db);
    notifications = FakeNotificationService();
  });

  tearDown(() async => db.close());

  test('no overdue customers: shows an empty notification set and returns 0', () async {
    await repo.addCustomer(
      name: 'Future Customer',
      phone: '1',
      address: 'A',
      installationDate: DateTime.now(),
    );

    final count = await checkOverdueRemindersAndNotify(repository: repo, notifications: notifications);

    expect(count, 0);
    expect(notifications.lastShown, isEmpty);
  });

  test('an overdue customer with no service history uses installation_date as last service date', () async {
    final customer = await repo.addCustomer(
      name: 'Overdue Customer',
      phone: '1',
      address: 'A',
      installationDate: DateTime.now().subtract(const Duration(days: 200)),
    );

    final count = await checkOverdueRemindersAndNotify(repository: repo, notifications: notifications);

    expect(count, 1);
    final shown = notifications.lastShown!;
    expect(shown, hasLength(1));
    expect(shown.single.customer.id, customer.id);
    expect(shown.single.lastServiceDate, customer.installationDate);
  });

  test('an overdue customer with service history uses the latest service_date, not installation_date', () async {
    final customer = await repo.addCustomer(
      name: 'Serviced Once',
      phone: '1',
      address: 'A',
      installationDate: DateTime(2025, 1, 1),
    );
    final serviceDate = DateTime.utc(2025, 3, 1);
    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: serviceDate,
      whatChanged: 'Filter replaced',
    );

    await checkOverdueRemindersAndNotify(repository: repo, notifications: notifications);

    final shown = notifications.lastShown!;
    expect(shown.single.lastServiceDate, serviceDate);
  });

  test('multiple overdue customers are all passed through to the notification service', () async {
    await repo.addCustomer(
      name: 'Overdue One',
      phone: '1',
      address: 'A',
      installationDate: DateTime.now().subtract(const Duration(days: 200)),
    );
    await repo.addCustomer(
      name: 'Overdue Two',
      phone: '2',
      address: 'B',
      installationDate: DateTime.now().subtract(const Duration(days: 300)),
    );
    await repo.addCustomer(
      name: 'Not Due Yet',
      phone: '3',
      address: 'C',
      installationDate: DateTime.now(),
    );

    final count = await checkOverdueRemindersAndNotify(repository: repo, notifications: notifications);

    expect(count, 2);
    expect(notifications.lastShown!.map((e) => e.customer.name), containsAll(['Overdue One', 'Overdue Two']));
    expect(notifications.lastShown!.map((e) => e.customer.name), isNot(contains('Not Due Yet')));
  });
}
