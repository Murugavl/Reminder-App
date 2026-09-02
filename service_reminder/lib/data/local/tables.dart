import 'package:drift/drift.dart';

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get address => text()();
  DateTimeColumn get installationDate => dateTime()();
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Per-customer override for the reminder interval, in months. Null means
  /// "use the app-wide default" (see ReminderIntervalPreferences) — most
  /// customers should leave this unset; it's an advanced, per-customer knob.
  IntColumn get reminderIntervalMonths => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ServiceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  DateTimeColumn get serviceDate => dateTime()();
  TextColumn get whatChanged => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
