import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_reminder/data/local/database.dart';
import 'package:service_reminder/data/repositories/customer_repository.dart';
import 'package:service_reminder/services/backup/backup_snapshot.dart';

void main() {
  group('encode/decode round trip', () {
    late AppDatabase db;
    late CustomerRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CustomerRepository(db);
    });

    tearDown(() async => db.close());

    test('round-trips customers and service records exactly', () async {
      final customer = await repo.addCustomer(
        name: 'Alice',
        phone: '12345',
        address: '1 Main St',
        installationDate: DateTime(2026, 1, 15),
      );
      await repo.addServiceRecord(
        customerId: customer.id,
        serviceDate: DateTime(2026, 3, 1),
        whatChanged: 'Filter replaced',
      );

      final customers = await (db.select(db.customers)).get();
      final serviceRecords = await (db.select(db.serviceRecords)).get();

      final snapshot = buildBackupSnapshot(
        customers: customers,
        serviceRecords: serviceRecords,
        exportedAt: DateTime.utc(2026, 6, 1, 10, 30),
      );
      final bytes = encodeBackupSnapshot(snapshot);
      final decoded = decodeBackupSnapshot(bytes);

      expect(decoded.exportedAt, DateTime.utc(2026, 6, 1, 10, 30));
      expect(decoded.customers, hasLength(1));
      expect(decoded.customers.single.name, 'Alice');
      expect(decoded.serviceRecords, hasLength(1));
      expect(decoded.serviceRecords.single.whatChanged, 'Filter replaced');
    });

    test('encodes as human-readable JSON with the expected top-level shape', () {
      final bytes = encodeBackupSnapshot(
        buildBackupSnapshot(customers: [], serviceRecords: [], exportedAt: DateTime.utc(2026, 1, 1)),
      );
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      expect(json['version'], backupSnapshotVersion);
      expect(json['exportedAt'], '2026-01-01T00:00:00.000Z');
      expect(json['customers'], isA<List>());
      expect(json['serviceRecords'], isA<List>());
    });
  });

  group('decodeBackupSnapshot validation', () {
    test('rejects non-JSON content', () {
      expect(
        () => decodeBackupSnapshot(utf8.encode('not json')),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });

    test('rejects a JSON array at the top level', () {
      expect(
        () => decodeBackupSnapshot(utf8.encode(jsonEncode([1, 2, 3]))),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });

    test('rejects a version newer than this app supports', () {
      final json = jsonEncode({
        'version': backupSnapshotVersion + 1,
        'exportedAt': DateTime(2026).toIso8601String(),
        'customers': [],
        'serviceRecords': [],
      });
      expect(
        () => decodeBackupSnapshot(utf8.encode(json)),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });

    test('rejects a missing customers list', () {
      final json = jsonEncode({
        'version': backupSnapshotVersion,
        'exportedAt': DateTime(2026).toIso8601String(),
        'serviceRecords': [],
      });
      expect(
        () => decodeBackupSnapshot(utf8.encode(json)),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });
  });

  group('backupFileName', () {
    test('is filesystem-safe (no colons) and identifies the app', () {
      final name = backupFileName(DateTime(2026, 3, 5, 14, 30, 0));
      expect(name, isNot(contains(':')));
      expect(name, startsWith('service_reminder_backup_'));
      expect(name, endsWith('.json'));
    });
  });

  group('replaceLocalDataWithSnapshot', () {
    late AppDatabase db;
    late CustomerRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = CustomerRepository(db);
    });

    tearDown(() async => db.close());

    test('replaces existing local data entirely with the snapshot contents', () async {
      await repo.addCustomer(
        name: 'Local Only',
        phone: '000',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
      );

      final backedUpCustomer = Customer(
        id: 'backup-customer-1',
        name: 'From Backup',
        phone: '111',
        address: 'Addr',
        installationDate: DateTime.utc(2026, 2, 1),
        nextDueDate: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
      );
      final backedUpServiceRecord = ServiceRecord(
        id: 'backup-record-1',
        customerId: backedUpCustomer.id,
        serviceDate: DateTime.utc(2026, 3, 1),
        whatChanged: 'Pump replaced',
        createdAt: DateTime.utc(2026, 3, 1),
      );
      final snapshot = buildBackupSnapshot(
        customers: [backedUpCustomer],
        serviceRecords: [backedUpServiceRecord],
      );

      await replaceLocalDataWithSnapshot(db, snapshot);

      final customers = await repo.getAllCustomers();
      expect(customers, hasLength(1));
      expect(customers.single.name, 'From Backup');

      final history = await repo.getCustomerWithHistory(customers.single.id);
      expect(history.serviceRecords, hasLength(1));
      expect(history.serviceRecords.single.whatChanged, 'Pump replaced');
    });

    test('restoring an empty snapshot clears all local data', () async {
      await repo.addCustomer(
        name: 'Will Be Cleared',
        phone: '000',
        address: 'Addr',
        installationDate: DateTime(2026, 1, 1),
      );

      await replaceLocalDataWithSnapshot(db, buildBackupSnapshot(customers: [], serviceRecords: []));

      expect(await repo.getAllCustomers(), isEmpty);
    });
  });
}
