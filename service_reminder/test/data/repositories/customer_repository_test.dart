import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/data/repositories/customer_repository.dart';

void main() {
  late AppDatabase db;
  late CustomerRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CustomerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addCustomer sets next_due_date to installation_date + 3 months', () async {
    final customer = await repo.addCustomer(
      name: 'Alice',
      phone: '12345',
      address: '1 Main St',
      installationDate: DateTime(2026, 1, 15),
    );

    expect(customer.nextDueDate, DateTime.utc(2026, 4, 15));
  });

  group('date storage is timezone-safe', () {
    test('installation_date, next_due_date, and service_date all come back UTC-tagged', () async {
      final customer = await repo.addCustomer(
        name: 'Alice',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 15),
      );
      final record = await repo.addServiceRecord(
        customerId: customer.id,
        serviceDate: DateTime(2026, 3, 1),
        whatChanged: 'Filter replaced',
      );
      final reloaded = await repo.getCustomerWithHistory(customer.id);

      expect(reloaded.customer.installationDate.isUtc, isTrue);
      expect(reloaded.customer.nextDueDate.isUtc, isTrue);
      expect(record.serviceDate.isUtc, isTrue);
    });

    test('a late-evening local date stores as that same calendar day, not the day after', () async {
      final customer = await repo.addCustomer(
        name: 'Bob',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 15, 23, 45),
      );

      expect(customer.installationDate, DateTime.utc(2026, 1, 15));
    });

    test('an early-morning local date stores as that same calendar day, not the day before', () async {
      final customer = await repo.addCustomer(
        name: 'Carol',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 15, 0, 15),
      );

      expect(customer.installationDate, DateTime.utc(2026, 1, 15));
    });
  });

  test('installation date at month end clamps instead of rolling over (Jan 31 -> Apr 30)', () async {
    final customer = await repo.addCustomer(
      name: 'Carol',
      phone: '111',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 31),
    );

    expect(customer.nextDueDate, DateTime.utc(2026, 4, 30));
  });

  test('addServiceRecord recalculates next_due_date from service_date, not installation_date', () async {
    final customer = await repo.addCustomer(
      name: 'Bob',
      phone: '999',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 15),
    );

    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 3, 1),
      whatChanged: 'Filter replaced',
    );

    final updated = await repo.getCustomerWithHistory(customer.id);

    expect(updated.customer.nextDueDate, DateTime.utc(2026, 6, 1));
  });

  test('addServiceRecord is reflected in getCustomerWithHistory service records', () async {
    final customer = await repo.addCustomer(
      name: 'Dana',
      phone: '222',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );

    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 2, 1),
      whatChanged: 'Filter replaced',
    );
    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 5, 1),
      whatChanged: 'Pump serviced',
    );

    final result = await repo.getCustomerWithHistory(customer.id);

    expect(result.serviceRecords, hasLength(2));
    expect(result.serviceRecords.first.whatChanged, 'Pump serviced');
    expect(result.customer.nextDueDate, DateTime.utc(2026, 8, 1));
  });

  test('getOverdueCustomers only returns customers whose next_due_date has passed', () async {
    final overdueCustomer = await repo.addCustomer(
      name: 'Overdue',
      phone: '1',
      address: 'A',
      installationDate: DateTime.now().subtract(const Duration(days: 400)),
    );
    final futureCustomer = await repo.addCustomer(
      name: 'Future',
      phone: '2',
      address: 'B',
      installationDate: DateTime.now(),
    );

    final overdue = await repo.getOverdueCustomers();
    final overdueIds = overdue.map((c) => c.id);

    expect(overdueIds, contains(overdueCustomer.id));
    expect(overdueIds, isNot(contains(futureCustomer.id)));
  });

  test('getAllCustomers sorts by next_due_date ascending, overdue first', () async {
    final later = await repo.addCustomer(
      name: 'Later',
      phone: '1',
      address: 'A',
      installationDate: DateTime.now(),
    );
    final sooner = await repo.addCustomer(
      name: 'Sooner',
      phone: '2',
      address: 'B',
      installationDate: DateTime.now().subtract(const Duration(days: 200)),
    );

    final all = await repo.getAllCustomers();

    expect(all.first.id, sooner.id);
    expect(all.last.id, later.id);
  });

  test('addServiceRecord logged out of order still bases next_due_date on the latest service date', () async {
    final customer = await repo.addCustomer(
      name: 'Frank',
      phone: '444',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );

    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 5, 1),
      whatChanged: 'Pump serviced',
    );
    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 2, 1),
      whatChanged: 'Filter replaced',
    );

    final result = await repo.getCustomerWithHistory(customer.id);

    expect(result.customer.nextDueDate, DateTime.utc(2026, 8, 1));
  });

  test('updateServiceRecord recalculates next_due_date', () async {
    final customer = await repo.addCustomer(
      name: 'Grace',
      phone: '555',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );

    final record = await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 3, 1),
      whatChanged: 'Filter replaced',
    );

    await repo.updateServiceRecord(
      id: record.id,
      customerId: customer.id,
      serviceDate: DateTime(2026, 4, 15),
      whatChanged: 'Filter and pump replaced',
    );

    final result = await repo.getCustomerWithHistory(customer.id);

    expect(result.customer.nextDueDate, DateTime.utc(2026, 7, 15));
    expect(result.serviceRecords.single.whatChanged, 'Filter and pump replaced');
  });

  test('deleteServiceRecord recalculates next_due_date from what remains', () async {
    final customer = await repo.addCustomer(
      name: 'Henry',
      phone: '666',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );

    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 2, 1),
      whatChanged: 'Filter replaced',
    );
    final laterRecord = await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 5, 1),
      whatChanged: 'Pump replaced',
    );

    await repo.deleteServiceRecord(id: laterRecord.id, customerId: customer.id);

    final result = await repo.getCustomerWithHistory(customer.id);

    expect(result.customer.nextDueDate, DateTime.utc(2026, 5, 1));
    expect(result.serviceRecords, hasLength(1));
  });

  test('deleteServiceRecord falls back to installation_date when no service records remain', () async {
    final customer = await repo.addCustomer(
      name: 'Ivy',
      phone: '777',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );

    final record = await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 2, 1),
      whatChanged: 'Filter replaced',
    );

    await repo.deleteServiceRecord(id: record.id, customerId: customer.id);

    final result = await repo.getCustomerWithHistory(customer.id);

    expect(result.customer.nextDueDate, DateTime.utc(2026, 4, 1));
    expect(result.serviceRecords, isEmpty);
  });

  group('deleteCustomer', () {
    test('removes the customer and all of their service records', () async {
      final customer = await repo.addCustomer(
        name: 'Jack',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
      );
      await repo.addServiceRecord(
        customerId: customer.id,
        serviceDate: DateTime(2026, 2, 1),
        whatChanged: 'Filter replaced',
      );

      await repo.deleteCustomer(customer.id);

      expect(await repo.getAllCustomers(), isEmpty);
      expect(
        () => repo.getCustomerWithHistory(customer.id),
        throwsA(anything),
      );
    });

    test('does not affect other customers', () async {
      final keep = await repo.addCustomer(
        name: 'Keep',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
      );
      final remove = await repo.addCustomer(
        name: 'Remove',
        phone: '2',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
      );

      await repo.deleteCustomer(remove.id);

      final remaining = await repo.getAllCustomers();
      expect(remaining, hasLength(1));
      expect(remaining.single.id, keep.id);
    });
  });

  group('reminder interval configuration', () {
    test('addCustomer uses the global default when no override is given', () async {
      final customer = await repo.addCustomer(
        name: 'Default Interval',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
        globalDefaultIntervalMonths: 6,
      );

      expect(customer.reminderIntervalMonths, isNull);
      expect(customer.nextDueDate, DateTime.utc(2026, 7, 1));
    });

    test('addCustomer honors an explicit per-customer override over the global default', () async {
      final customer = await repo.addCustomer(
        name: 'Custom Interval',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
        globalDefaultIntervalMonths: 6,
        reminderIntervalMonths: 1,
      );

      expect(customer.reminderIntervalMonths, 1);
      expect(customer.nextDueDate, DateTime.utc(2026, 2, 1));
    });

    test('setReminderIntervalOverride recomputes next_due_date immediately', () async {
      final customer = await repo.addCustomer(
        name: 'Alice',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
      );

      final updated = await repo.setReminderIntervalOverride(customerId: customer.id, months: 1);

      expect(updated.reminderIntervalMonths, 1);
      expect(updated.nextDueDate, DateTime.utc(2026, 2, 1));
    });

    test('setReminderIntervalOverride(months: null) clears the override back to the global default', () async {
      final customer = await repo.addCustomer(
        name: 'Bob',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
        reminderIntervalMonths: 1,
      );

      final cleared = await repo.setReminderIntervalOverride(
        customerId: customer.id,
        months: null,
        globalDefaultIntervalMonths: 6,
      );

      expect(cleared.reminderIntervalMonths, isNull);
      expect(cleared.nextDueDate, DateTime.utc(2026, 7, 1));
    });

    test('a customer with an override keeps using it even as service records are logged', () async {
      final customer = await repo.addCustomer(
        name: 'Carol',
        phone: '1',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
        reminderIntervalMonths: 1,
      );

      await repo.addServiceRecord(
        customerId: customer.id,
        serviceDate: DateTime(2026, 3, 1),
        whatChanged: 'Filter replaced',
        globalDefaultIntervalMonths: 6,
      );

      final result = await repo.getCustomerWithHistory(customer.id);
      expect(result.customer.nextDueDate, DateTime.utc(2026, 4, 1));
    });
  });
}
