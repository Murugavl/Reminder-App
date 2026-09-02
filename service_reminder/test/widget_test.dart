import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/main.dart';
import 'package:service_reminder/providers/database_providers.dart';

void main() {
  testWidgets('Home screen shows Service Reminder title and empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
        ],
        child: const ServiceReminderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Service Reminder'), findsOneWidget);
    expect(find.text('No customers yet'), findsOneWidget);
    expect(find.text('Add your first customer'), findsOneWidget);
  });
}
