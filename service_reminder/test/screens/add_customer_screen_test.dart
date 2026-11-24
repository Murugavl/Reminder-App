import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/data/repositories/customer_repository.dart';
import 'package:service_reminder/providers/database_providers.dart';
import 'package:service_reminder/screens/add_customer_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> pumpAddScreenPushedFromHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('submitting an empty form shows inline validation errors', (tester) async {
    await pumpAddScreenPushedFromHome(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Customer name is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Installation date is required'), findsOneWidget);
  });

  testWidgets('rejects a non-numeric phone number', (tester) async {
    await pumpAddScreenPushedFromHome(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), 'abc-123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid phone number (digits only)'), findsOneWidget);
  });

  testWidgets('valid submission saves the customer and pops back to Home', (tester) async {
    await pumpAddScreenPushedFromHome(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name'), 'Test Customer');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '9998887777');

    await tester.tap(find.text('Date of Installation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(AddCustomerScreen), findsNothing);

    final customers = await CustomerRepository(db).getAllCustomers();
    expect(customers, hasLength(1));
    expect(customers.first.name, 'Test Customer');
    expect(customers.first.phone, '9998887777');
  });

  testWidgets('duplicate customer details are rejected with a visible message', (tester) async {
    await CustomerRepository(db).addCustomer(
      name: 'Test Customer',
      phone: '9998887777',
      address: '1 Main St',
      installationDate: DateTime(2026, 1, 1),
    );
    await pumpAddScreenPushedFromHome(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name'), 'Test Customer');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '9998887777');
    await tester.enterText(find.widgetWithText(TextFormField, 'Address'), '1 Main St');

    await tester.tap(find.text('Date of Installation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not save customer: A customer with the same name, phone number, and address already exists.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AddCustomerScreen), findsOneWidget);
    expect(await CustomerRepository(db).getAllCustomers(), hasLength(1));
  });
}
