import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:service_reminder/providers/backup_providers.dart';
import 'package:service_reminder/screens/restore_backup_screen.dart';
import 'package:service_reminder/services/backup/backup_service.dart';

import '../fakes/fake_backup_service.dart';

void main() {
  late FakeBackupService backup;

  setUp(() {
    backup = FakeBackupService();
  });

  Future<void> pumpRestoreScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backupServiceProvider.overrideWithValue(backup)],
        child: const MaterialApp(home: RestoreBackupScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state when there are no backups yet', (tester) async {
    backup.backupsToReturn = [];
    await pumpRestoreScreen(tester);

    expect(find.textContaining('No backups yet'), findsOneWidget);
  });

  testWidgets('lists available backups by timestamp, most recent first as returned by the service', (tester) async {
    backup.backupsToReturn = [
      DriveBackupFile(id: '1', name: 'a.json', createdTime: DateTime(2026, 5, 1, 9, 0)),
      DriveBackupFile(id: '2', name: 'b.json', createdTime: DateTime(2026, 4, 1, 9, 0)),
    ];
    await pumpRestoreScreen(tester);

    expect(find.text('01 May 2026, 09:00'), findsOneWidget);
    expect(find.text('01 Apr 2026, 09:00'), findsOneWidget);
  });

  testWidgets('tapping a backup shows a warning dialog before restoring', (tester) async {
    backup.backupsToReturn = [
      DriveBackupFile(id: '1', name: 'a.json', createdTime: DateTime(2026, 5, 1, 9, 0)),
    ];
    await pumpRestoreScreen(tester);

    await tester.tap(find.text('01 May 2026, 09:00'));
    await tester.pumpAndSettle();

    expect(find.text('Restore this backup?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(backup.restoreCalls, isEmpty);
  });

  testWidgets('canceling the warning dialog does not restore', (tester) async {
    backup.backupsToReturn = [
      DriveBackupFile(id: '1', name: 'a.json', createdTime: DateTime(2026, 5, 1, 9, 0)),
    ];
    await pumpRestoreScreen(tester);

    await tester.tap(find.text('01 May 2026, 09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(backup.restoreCalls, isEmpty);
    expect(find.text('Restore this backup?'), findsNothing);
  });

  testWidgets('confirming the warning dialog restores and pops back with a confirmation', (tester) async {
    backup.backupsToReturn = [
      DriveBackupFile(id: 'backup-1', name: 'a.json', createdTime: DateTime(2026, 5, 1, 9, 0)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backupServiceProvider.overrideWithValue(backup)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RestoreBackupScreen()),
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

    await tester.tap(find.text('01 May 2026, 09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(backup.restoreCalls, ['backup-1']);
    expect(find.text('Backup restored.'), findsOneWidget);
    // Popped back to the placeholder screen.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('shows an error message if restore fails, without popping', (tester) async {
    backup.backupsToReturn = [
      DriveBackupFile(id: 'backup-1', name: 'a.json', createdTime: DateTime(2026, 5, 1, 9, 0)),
    ];
    backup.restoreError = Exception('corrupt file');
    await pumpRestoreScreen(tester);

    await tester.tap(find.text('01 May 2026, 09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Restore failed'), findsOneWidget);
    expect(find.text('Restore from Backup'), findsOneWidget); // still on the same screen
  });
}
