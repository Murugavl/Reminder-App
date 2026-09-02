import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/data/repositories/customer_repository.dart';
import 'package:service_reminder/providers/backup_providers.dart';
import 'package:service_reminder/providers/database_providers.dart';
import 'package:service_reminder/providers/notification_providers.dart';
import 'package:service_reminder/screens/settings_screen.dart';
import 'package:service_reminder/services/backup/backup_service.dart';

import '../fakes/fake_backup_service.dart';
import '../fakes/fake_notification_service.dart';
import '../fakes/fake_weekly_backup_scheduler.dart';

void main() {
  late AppDatabase db;
  late FakeNotificationService notifications;
  late FakeBackupService backup;
  late FakeWeeklyBackupScheduler scheduler;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = FakeNotificationService();
    backup = FakeBackupService();
    scheduler = FakeWeeklyBackupScheduler();
  });

  tearDown(() async => db.close());

  Future<void> pumpSettings(WidgetTester tester) async {
    // The default 800x600 test surface is too short for this screen's
    // growing content; use a phone-sized surface so items further down
    // (weekly backup toggle, debug section) land onstage for finders/taps.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(notifications),
          backupServiceProvider.overrideWithValue(backup),
          weeklyBackupSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Check reminders now runs the check and reports "no overdue" when none are overdue', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Check reminders now'));
    await tester.pumpAndSettle();

    expect(notifications.showCalls, hasLength(1));
    expect(find.text('Checked — no overdue customers right now.'), findsOneWidget);
  });

  testWidgets('Check reminders now reports the overdue count and triggers the notification service', (tester) async {
    final repo = CustomerRepository(db);
    await repo.addCustomer(
      name: 'Overdue Customer',
      phone: '1',
      address: 'A',
      installationDate: DateTime.now().subtract(const Duration(days: 200)),
    );

    await pumpSettings(tester);

    await tester.tap(find.text('Check reminders now'));
    await tester.pumpAndSettle();

    expect(notifications.showCalls, hasLength(1));
    expect(notifications.lastShown, hasLength(1));
    expect(notifications.lastShown!.single.customer.name, 'Overdue Customer');
    expect(find.text('Checked — 1 customer overdue, notification updated.'), findsOneWidget);
  });

  group('Google Drive backup', () {
    testWidgets('shows "not set up" state when Google Sign-In has no OAuth client configured', (tester) async {
      backup.configured = false;
      await pumpSettings(tester);

      expect(find.text('Google Sign-In not set up'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('shows a Sign in button when signed out, and it signs in on tap', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Sign in with Google'), findsOneWidget);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(backup.signInCallCount, 1);
      expect(find.text('test@example.com'), findsWidgets);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('Backup now and Restore are disabled until signed in', (tester) async {
      await pumpSettings(tester);

      final backupNowTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Backup now'));
      final restoreTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Restore from backup'));

      expect(backupNowTile.enabled, isFalse);
      expect(restoreTile.enabled, isFalse);
    });

    testWidgets('Backup now uploads and reports success once signed in', (tester) async {
      backup = FakeBackupService(initialAccount: const SignedInAccount(email: 'me@example.com'))
        ..nextBackupOutcome = BackupSucceeded(DateTime(2026, 5, 1, 9));
      await pumpSettings(tester);

      await tester.tap(find.text('Backup now'));
      await tester.pumpAndSettle();

      expect(backup.backupNowInteractiveCalls, [true]);
      expect(find.textContaining('Backup uploaded'), findsOneWidget);
    });

    testWidgets('Backup now reports failure without crashing', (tester) async {
      backup = FakeBackupService(initialAccount: const SignedInAccount(email: 'me@example.com'))
        ..nextBackupOutcome = const BackupFailed('network error');
      await pumpSettings(tester);

      await tester.tap(find.text('Backup now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Backup failed: network error'), findsOneWidget);
    });

    testWidgets('turning on automatic weekly backup signs in, backs up, and enables the scheduler', (tester) async {
      backup.nextBackupOutcome = BackupSucceeded(DateTime(2026, 1, 1));
      await pumpSettings(tester);

      await tester.tap(find.text('Automatic weekly backup'));
      await tester.pumpAndSettle();

      expect(backup.signInCallCount, 1);
      expect(backup.backupNowInteractiveCalls, [true]);
      expect(scheduler.enableCallCount, 1);
      expect(find.text('Automatic weekly backup turned on.'), findsOneWidget);

      final toggle = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Automatic weekly backup'));
      expect(toggle.value, isTrue);
    });

    testWidgets('turning off automatic weekly backup disables the scheduler without touching sign-in', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'auto_backup_enabled': true});
      backup = FakeBackupService(initialAccount: const SignedInAccount(email: 'me@example.com'));
      await pumpSettings(tester);

      final initialToggle = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Automatic weekly backup'));
      expect(initialToggle.value, isTrue);

      await tester.tap(find.text('Automatic weekly backup'));
      await tester.pumpAndSettle();

      expect(scheduler.disableCallCount, 1);
      expect(backup.signInCallCount, 0);

      final toggle = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Automatic weekly backup'));
      expect(toggle.value, isFalse);
    });
  });
}
