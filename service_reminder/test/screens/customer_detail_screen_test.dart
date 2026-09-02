import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/data/repositories/customer_repository.dart';
import 'package:service_reminder/providers/database_providers.dart';
import 'package:service_reminder/providers/notification_providers.dart';
import 'package:service_reminder/screens/customer_detail_screen.dart';

import '../fakes/fake_notification_service.dart';

void main() {
  late AppDatabase db;
  late CustomerRepository repo;
  late FakeNotificationService notifications;
  final dateFormat = DateFormat('dd MMM yyyy');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CustomerRepository(db);
    notifications = FakeNotificationService();
  });

  tearDown(() async => db.close());

  Future<void> pumpDetail(WidgetTester tester, String customerId) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(home: CustomerDetailScreen(customerId: customerId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows header fields and overdue banner styling', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Alice Smith',
      phone: '9998887777',
      address: '221B Baker Street',
      installationDate: DateTime.now().subtract(const Duration(days: 200)),
    );

    await pumpDetail(tester, customer.id);

    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('9998887777'), findsOneWidget);
    expect(find.text('221B Baker Street'), findsOneWidget);
    expect(find.text('Service overdue'), findsOneWidget);
  });

  testWidgets('shows on-track styling when next due date is in the future', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Bob Jones',
      phone: '111',
      address: 'Addr',
      installationDate: DateTime.now(),
    );

    await pumpDetail(tester, customer.id);

    expect(find.text('Next service due'), findsOneWidget);
    expect(find.text('Service overdue'), findsNothing);
  });

  testWidgets('service history lists records reverse-chronologically', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Carol',
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
      whatChanged: 'Pump replaced',
    );

    await pumpDetail(tester, customer.id);

    expect(find.text('Filter replaced'), findsOneWidget);
    expect(find.text('Pump replaced'), findsOneWidget);

    final pumpTop = tester.getTopLeft(find.text('Pump replaced')).dy;
    final filterTop = tester.getTopLeft(find.text('Filter replaced')).dy;
    expect(pumpTop, lessThan(filterTop));
  });

  testWidgets('shows empty state when there is no service history yet', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Dana',
      phone: '333',
      address: 'Addr',
      installationDate: DateTime.now(),
    );

    await pumpDetail(tester, customer.id);

    expect(find.textContaining('No service records yet'), findsOneWidget);
  });

  testWidgets('Log Service adds a record, refreshes next due date, and shows a success snackbar', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Eve',
      phone: '444',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );

    await pumpDetail(tester, customer.id);

    await tester.tap(find.text('Log Service'));
    await tester.pumpAndSettle();

    expect(find.text('Log Service'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'What Changed'), 'Annual maintenance');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Annual maintenance'), findsOneWidget);

    final updated = await repo.getCustomerWithHistory(customer.id);
    expect(
      find.textContaining('Service logged'),
      findsOneWidget,
    );
    expect(
      find.textContaining(dateFormat.format(updated.customer.nextDueDate)),
      findsWidgets,
    );

    expect(notifications.canceledCustomerIds, contains(customer.id));
  });

  testWidgets('editing a service record via its menu updates the entry', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Frank',
      phone: '555',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );
    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 2, 1),
      whatChanged: 'Filter replaced',
    );

    await pumpDetail(tester, customer.id);

    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextFormField, 'What Changed');
    await tester.enterText(field, 'Filter and gasket replaced');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Filter and gasket replaced'), findsOneWidget);
    expect(find.text('Filter replaced'), findsNothing);
    expect(find.text('Service record updated'), findsOneWidget);
  });

  testWidgets('deleting a service record via its menu removes it after confirmation', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Grace',
      phone: '666',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );
    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 2, 1),
      whatChanged: 'Filter replaced',
    );

    await pumpDetail(tester, customer.id);
    expect(find.text('Filter replaced'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete service record?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Filter replaced'), findsNothing);
    expect(find.textContaining('No service records yet'), findsOneWidget);
    expect(find.text('Service record deleted'), findsOneWidget);
  });

  testWidgets('canceling the delete confirmation keeps the record', (tester) async {
    final customer = await repo.addCustomer(
      name: 'Henry',
      phone: '777',
      address: 'Addr',
      installationDate: DateTime(2026, 1, 1),
    );
    await repo.addServiceRecord(
      customerId: customer.id,
      serviceDate: DateTime(2026, 2, 1),
      whatChanged: 'Filter replaced',
    );

    await pumpDetail(tester, customer.id);

    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Filter replaced'), findsOneWidget);
  });
}
