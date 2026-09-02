import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/providers/database_providers.dart';
import 'package:service_reminder/screens/add_customer_screen.dart';
import 'package:service_reminder/screens/home_screen.dart';
import 'package:service_reminder/widgets/due_status_badge.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> seedCustomer(
    AppDatabase db, {
    required String id,
    required String name,
    required String phone,
    required DateTime nextDueDate,
  }) {
    final now = DateTime.now();
    return db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: id,
            name: name,
            phone: phone,
            address: 'Addr',
            installationDate: nextDueDate.subtract(const Duration(days: 90)),
            nextDueDate: nextDueDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search bar filters the list by name and by phone', (tester) async {
    await seedCustomer(
      db,
      id: '1',
      name: 'Alice Smith',
      phone: '1112223333',
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
    );
    await seedCustomer(
      db,
      id: '2',
      name: 'Bob Jones',
      phone: '4445556666',
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
    );

    await pumpHome(tester);

    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();

    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsNothing);

    await tester.enterText(find.byType(TextField), '444555');
    await tester.pumpAndSettle();

    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Alice Smith'), findsNothing);
  });

  testWidgets('badges reflect overdue / due-soon / on-track status', (tester) async {
    await seedCustomer(
      db,
      id: '1',
      name: 'Overdue Customer',
      phone: '1',
      nextDueDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    await seedCustomer(
      db,
      id: '2',
      name: 'Soon Customer',
      phone: '2',
      nextDueDate: DateTime.now().add(const Duration(days: 3)),
    );
    await seedCustomer(
      db,
      id: '3',
      name: 'On Track Customer',
      phone: '3',
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
    );

    await pumpHome(tester);

    // Scope to the status badges specifically — the dashboard summary tile
    // above the list is also labeled "Overdue".
    expect(find.descendant(of: find.byType(DueStatusBadge), matching: find.text('Overdue')), findsOneWidget);
    expect(find.descendant(of: find.byType(DueStatusBadge), matching: find.text('Due soon')), findsOneWidget);
    expect(find.descendant(of: find.byType(DueStatusBadge), matching: find.text('On track')), findsOneWidget);
  });

  testWidgets('list is sorted overdue-first', (tester) async {
    await seedCustomer(
      db,
      id: '1',
      name: 'Later',
      phone: '1',
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
    );
    await seedCustomer(
      db,
      id: '2',
      name: 'Sooner',
      phone: '2',
      nextDueDate: DateTime.now().subtract(const Duration(days: 5)),
    );

    await pumpHome(tester);

    final laterTop = tester.getTopLeft(find.text('Later')).dy;
    final soonerTop = tester.getTopLeft(find.text('Sooner')).dy;

    expect(soonerTop, lessThan(laterTop));
  });

  group('empty states', () {
    testWidgets('shows a friendly empty state with an add-customer call to action when there are no customers',
        (tester) async {
      await pumpHome(tester);

      expect(find.text('No customers yet'), findsOneWidget);
      expect(find.text('Add your first customer'), findsOneWidget);

      await tester.tap(find.text('Add your first customer'));
      await tester.pumpAndSettle();

      expect(find.byType(AddCustomerScreen), findsOneWidget);
    });

    testWidgets('shows a distinct "no results" state when a search matches nothing, without the add-customer CTA',
        (tester) async {
      await seedCustomer(
        db,
        id: '1',
        name: 'Alice Smith',
        phone: '1112223333',
        nextDueDate: DateTime.now().add(const Duration(days: 30)),
      );

      await pumpHome(tester);
      await tester.enterText(find.byType(TextField), 'nobody matches this');
      await tester.pumpAndSettle();

      expect(find.text('No matching customers'), findsOneWidget);
      expect(find.text('No customers yet'), findsNothing);
      expect(find.text('Add your first customer'), findsNothing);
    });
  });

  group('dashboard summary', () {
    testWidgets('shows total, overdue, and due-this-week counts', (tester) async {
      await seedCustomer(
        db,
        id: '1',
        name: 'Overdue Customer',
        phone: '1',
        nextDueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      await seedCustomer(
        db,
        id: '2',
        name: 'Soon Customer',
        phone: '2',
        nextDueDate: DateTime.now().add(const Duration(days: 3)),
      );
      await seedCustomer(
        db,
        id: '3',
        name: 'On Track Customer',
        phone: '3',
        nextDueDate: DateTime.now().add(const Duration(days: 30)),
      );

      await pumpHome(tester);

      expect(find.text('Customers'), findsOneWidget);
      // "Overdue" also appears on the customer's own status badge, so two.
      expect(find.text('Overdue'), findsNWidgets(2));
      expect(find.text('Due this week'), findsOneWidget);
      // Counts: 3 total, 1 overdue, 1 due this week (the dueSoon-status customer).
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('is hidden entirely when there are no customers', (tester) async {
      await pumpHome(tester);

      expect(find.text('Customers'), findsNothing);
    });

    testWidgets('still shows even while a search filters the list below it to nothing', (tester) async {
      await seedCustomer(
        db,
        id: '1',
        name: 'Alice Smith',
        phone: '1112223333',
        nextDueDate: DateTime.now().add(const Duration(days: 30)),
      );

      await pumpHome(tester);
      await tester.enterText(find.byType(TextField), 'nobody matches this');
      await tester.pumpAndSettle();

      expect(find.text('Customers'), findsOneWidget);
    });
  });
}
