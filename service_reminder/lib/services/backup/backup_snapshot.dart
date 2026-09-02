import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show ValueSerializer;

import '../../data/local/database.dart';

const backupSnapshotVersion = 1;

/// Serializes DateTime fields as ISO-8601 strings (with their UTC/offset
/// marker) rather than drift's default of a bare millisecond epoch. Every
/// date field on [Customer]/[ServiceRecord] is UTC by the time it reaches
/// here (see CustomerRepository._dateOnly/_now), so this round-trips exactly
/// on restore regardless of which device's timezone reads it back — the
/// default epoch encoding reconstructs via a *local* DateTime on read,
/// which is exactly the kind of timezone-dependent bug date-only fields
/// need to avoid.
const _dateTimeSafeSerializer = ValueSerializer.defaults(serializeDateTimeValuesAsString: true);

/// A full point-in-time export of the local database: every customer and
/// service record, nothing device-specific.
class BackupSnapshot {
  const BackupSnapshot({required this.exportedAt, required this.customers, required this.serviceRecords});

  final DateTime exportedAt;
  final List<Customer> customers;
  final List<ServiceRecord> serviceRecords;
}

/// Thrown when a downloaded backup file isn't a snapshot this app produced
/// (wrong shape, or a newer/unsupported version).
class InvalidBackupFormatException implements Exception {
  InvalidBackupFormatException(this.message);
  final String message;

  @override
  String toString() => 'InvalidBackupFormatException: $message';
}

BackupSnapshot buildBackupSnapshot({
  required List<Customer> customers,
  required List<ServiceRecord> serviceRecords,
  DateTime? exportedAt,
}) {
  return BackupSnapshot(
    exportedAt: (exportedAt ?? DateTime.now()).toUtc(),
    customers: customers,
    serviceRecords: serviceRecords,
  );
}

Uint8List encodeBackupSnapshot(BackupSnapshot snapshot) {
  final json = {
    'version': backupSnapshotVersion,
    'exportedAt': snapshot.exportedAt.toIso8601String(),
    'customers': [for (final c in snapshot.customers) c.toJson(serializer: _dateTimeSafeSerializer)],
    'serviceRecords': [
      for (final r in snapshot.serviceRecords) r.toJson(serializer: _dateTimeSafeSerializer),
    ],
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(json)));
}

BackupSnapshot decodeBackupSnapshot(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    throw InvalidBackupFormatException('Not valid JSON: $e');
  }

  if (decoded is! Map<String, dynamic>) {
    throw InvalidBackupFormatException('Expected a JSON object at the top level.');
  }
  final version = decoded['version'];
  if (version is! int || version > backupSnapshotVersion) {
    throw InvalidBackupFormatException('Unsupported backup version: $version');
  }

  final exportedAtRaw = decoded['exportedAt'];
  final exportedAt = exportedAtRaw is String ? DateTime.tryParse(exportedAtRaw) : null;
  if (exportedAt == null) {
    throw InvalidBackupFormatException('Missing or invalid exportedAt.');
  }

  final customersRaw = decoded['customers'];
  final serviceRecordsRaw = decoded['serviceRecords'];
  if (customersRaw is! List || serviceRecordsRaw is! List) {
    throw InvalidBackupFormatException('Missing customers or serviceRecords list.');
  }

  try {
    return BackupSnapshot(
      exportedAt: exportedAt,
      customers: [
        for (final c in customersRaw) Customer.fromJson(c as Map<String, dynamic>, serializer: _dateTimeSafeSerializer),
      ],
      serviceRecords: [
        for (final r in serviceRecordsRaw)
          ServiceRecord.fromJson(r as Map<String, dynamic>, serializer: _dateTimeSafeSerializer),
      ],
    );
  } catch (e) {
    throw InvalidBackupFormatException('Malformed customer or service record entry: $e');
  }
}

/// Filename a backup is uploaded to Drive under. Colons are stripped since
/// some filesystems (Windows) reject them if a user ever downloads the file.
String backupFileName(DateTime timestamp) {
  final sanitized = timestamp.toIso8601String().replaceAll(':', '-');
  return 'service_reminder_backup_$sanitized.json';
}

/// Replaces all local customers and service records with the contents of
/// [snapshot], inside a single transaction. This is the destructive
/// "replace" restore strategy — callers are responsible for warning the user
/// before invoking it.
Future<void> replaceLocalDataWithSnapshot(AppDatabase db, BackupSnapshot snapshot) {
  return db.transaction(() async {
    // Children before parents, respecting the customerId foreign key.
    await db.delete(db.serviceRecords).go();
    await db.delete(db.customers).go();

    await db.batch((batch) => batch.insertAll(db.customers, snapshot.customers));
    await db.batch((batch) => batch.insertAll(db.serviceRecords, snapshot.serviceRecords));
  });
}
