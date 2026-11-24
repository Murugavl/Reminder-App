import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/customer_with_history.dart';
import '../local/database.dart';

/// Used when no explicit global default is passed in — matches the app's
/// out-of-the-box behavior before the reminder interval became configurable.
const defaultReminderIntervalMonths = 3;
const _uuid = Uuid();

class DuplicateCustomerException implements Exception {
  @override
  String toString() => 'A customer with the same name, phone number, and address already exists.';
}

class CustomerRepository {
  CustomerRepository(this._db);

  final AppDatabase _db;

  /// All customers sorted by next_due_date ascending, so overdue customers
  /// (the smallest/oldest due dates) come first.
  Future<List<Customer>> getAllCustomers() {
    return (_db.select(_db.customers)
          ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]))
        .get();
  }

  Future<List<Customer>> getOverdueCustomers() {
    // Remind the night *before* the due date: treat a customer as overdue
    // when today >= (nextDueDate - 1 day), i.e. nextDueDate <= tomorrow.
    final tomorrow = _dateOnly(DateTime.now()).add(const Duration(days: 1));
    return (_db.select(_db.customers)
          ..where((t) => t.nextDueDate.isSmallerOrEqualValue(tomorrow))
          ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]))
        .get();
  }

  /// [globalDefaultIntervalMonths] is the app-wide default reminder interval
  /// (see ReminderIntervalPreferences) — pass the caller's currently
  /// configured value. [reminderIntervalMonths] is an optional per-customer
  /// override; leave it null unless the caller is deliberately setting one
  /// up front (most customers use the global default instead).
  Future<Customer> addCustomer({
    required String name,
    required String phone,
    required String address,
    required DateTime installationDate,
    int globalDefaultIntervalMonths = defaultReminderIntervalMonths,
    int? reminderIntervalMonths,
  }) {
    return _db.transaction(() async {
      final duplicate = await (_db.select(_db.customers)
            ..where((customer) =>
                customer.name.equals(name) & customer.phone.equals(phone) & customer.address.equals(address)))
          .getSingleOrNull();
      if (duplicate != null) throw DuplicateCustomerException();

      final now = _now();
      final installation = _dateOnly(installationDate);
      final effectiveMonths = reminderIntervalMonths ?? globalDefaultIntervalMonths;

      return _db.into(_db.customers).insertReturning(
            CustomersCompanion.insert(
              id: _uuid.v4(),
              name: name,
              phone: phone,
              address: address,
              installationDate: installation,
              nextDueDate: _addMonths(installation, effectiveMonths),
              createdAt: now,
              updatedAt: now,
              reminderIntervalMonths: Value(reminderIntervalMonths),
            ),
          );
    });
  }

  Future<Customer> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? address,
    DateTime? installationDate,
  }) async {
    final rows = await (_db.update(_db.customers)..where((t) => t.id.equals(id))).writeReturning(
          CustomersCompanion(
            name: name != null ? Value(name) : const Value.absent(),
            phone: phone != null ? Value(phone) : const Value.absent(),
            address: address != null ? Value(address) : const Value.absent(),
            installationDate:
                installationDate != null ? Value(_dateOnly(installationDate)) : const Value.absent(),
            updatedAt: Value(_now()),
          ),
        );
    return rows.single;
  }

  /// Inserts a service record for [customerId] and pushes next_due_date out
  /// to (the now-latest service date) + interval.
  Future<ServiceRecord> addServiceRecord({
    required String customerId,
    required DateTime serviceDate,
    required String whatChanged,
    int globalDefaultIntervalMonths = defaultReminderIntervalMonths,
  }) {
    return _db.transaction(() async {
      final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingle();

      final record = await _db.into(_db.serviceRecords).insertReturning(
            ServiceRecordsCompanion.insert(
              id: _uuid.v4(),
              customerId: customerId,
              serviceDate: _dateOnly(serviceDate),
              whatChanged: whatChanged,
              createdAt: _now(),
            ),
          );

      await _recomputeNextDueDate(
        customerId: customerId,
        customer: customer,
        globalDefaultIntervalMonths: globalDefaultIntervalMonths,
      );

      return record;
    });
  }

  /// Corrects a previously logged service record and recomputes next_due_date
  /// from whichever service record is now chronologically latest.
  Future<ServiceRecord> updateServiceRecord({
    required String id,
    required String customerId,
    DateTime? serviceDate,
    String? whatChanged,
    int globalDefaultIntervalMonths = defaultReminderIntervalMonths,
  }) {
    return _db.transaction(() async {
      final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingle();

      final rows = await (_db.update(_db.serviceRecords)..where((t) => t.id.equals(id))).writeReturning(
            ServiceRecordsCompanion(
              serviceDate: serviceDate != null ? Value(_dateOnly(serviceDate)) : const Value.absent(),
              whatChanged: whatChanged != null ? Value(whatChanged) : const Value.absent(),
            ),
          );
      final record = rows.single;

      await _recomputeNextDueDate(
        customerId: customerId,
        customer: customer,
        globalDefaultIntervalMonths: globalDefaultIntervalMonths,
      );

      return record;
    });
  }

  /// Removes a mistakenly logged service record and recomputes next_due_date
  /// from whichever service record (if any) is now chronologically latest.
  Future<void> deleteServiceRecord({
    required String id,
    required String customerId,
    int globalDefaultIntervalMonths = defaultReminderIntervalMonths,
  }) {
    return _db.transaction(() async {
      final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingle();

      await (_db.delete(_db.serviceRecords)..where((t) => t.id.equals(id))).go();

      await _recomputeNextDueDate(
        customerId: customerId,
        customer: customer,
        globalDefaultIntervalMonths: globalDefaultIntervalMonths,
      );
    });
  }

  /// Permanently deletes a customer and all of their service records. There
  /// is no undo — callers must confirm with the user before calling this.
  Future<void> deleteCustomer(String id) {
    return _db.transaction(() async {
      // Children before parents, respecting the customerId foreign key.
      await (_db.delete(_db.serviceRecords)..where((t) => t.customerId.equals(id))).go();
      await (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Sets (or, passing null, clears) this customer's per-customer reminder
  /// interval override, and immediately recomputes next_due_date using the
  /// new effective interval (override ?? [globalDefaultIntervalMonths]).
  Future<Customer> setReminderIntervalOverride({
    required String customerId,
    required int? months,
    int globalDefaultIntervalMonths = defaultReminderIntervalMonths,
  }) {
    return _db.transaction(() async {
      final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingle();
      final basis = await _latestDueDateBasis(customerId, customer.installationDate);
      final effectiveMonths = months ?? globalDefaultIntervalMonths;

      final rows = await (_db.update(_db.customers)..where((t) => t.id.equals(customerId))).writeReturning(
            CustomersCompanion(
              reminderIntervalMonths: Value(months),
              nextDueDate: Value(_addMonths(basis, effectiveMonths)),
              updatedAt: Value(_now()),
            ),
          );
      return rows.single;
    });
  }

  /// Recomputes next_due_date from whichever service record is chronologically
  /// latest (falling back to installation_date), using [customer]'s reminder
  /// interval override if it has one, or [globalDefaultIntervalMonths] otherwise.
  Future<void> _recomputeNextDueDate({
    required String customerId,
    required Customer customer,
    required int globalDefaultIntervalMonths,
  }) async {
    final nextDueDate = await _latestDueDateBasis(customerId, customer.installationDate);
    final effectiveMonths = customer.reminderIntervalMonths ?? globalDefaultIntervalMonths;

    await (_db.update(_db.customers)..where((t) => t.id.equals(customerId))).write(
      CustomersCompanion(
        nextDueDate: Value(_addMonths(nextDueDate, effectiveMonths)),
        updatedAt: Value(_now()),
      ),
    );
  }

  /// The date the next_due_date should be based on: the most recent
  /// remaining service_date for this customer, or installation_date if they
  /// have no service records.
  Future<DateTime> _latestDueDateBasis(String customerId, DateTime installationDate) async {
    final latest = await (_db.select(_db.serviceRecords)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.serviceDate)])
          ..limit(1))
        .getSingleOrNull();
    return latest?.serviceDate ?? installationDate;
  }

  Future<CustomerWithHistory> getCustomerWithHistory(String id) async {
    final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(id))).getSingle();
    final records = await (_db.select(_db.serviceRecords)
          ..where((t) => t.customerId.equals(id))
          ..orderBy([(t) => OrderingTerm.desc(t.serviceDate)]))
        .get();
    return CustomerWithHistory(customer: customer, serviceRecords: records);
  }

  /// Normalizes [date] to a timezone-independent "calendar date": UTC
  /// midnight for the same year/month/day that [date] displays (whatever
  /// its own timezone). Storing dates this way — rather than as a local
  /// `DateTime` or a bare instant — means installation/service/due dates
  /// round-trip through the database exactly, regardless of what timezone
  /// the device is in when they're read back (drift decodes a stored UTC
  /// instant as UTC, never reinterpreting it through the current local
  /// offset the way it would for a local `DateTime`).
  static DateTime _dateOnly(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  /// The current instant, stored in UTC. Used for created_at/updated_at —
  /// unlike the date-only fields above these carry real time-of-day, but
  /// storing them in UTC keeps every column in this database on the same
  /// timezone-independent footing (see [_dateOnly] for why that matters).
  static DateTime _now() => DateTime.now().toUtc();

  /// Adds [months] to [date], clamping the day to the last valid day of the
  /// target month (e.g. Jan 31 + 1 month = Feb 28, not Mar 3). [date] is
  /// assumed to already be a UTC calendar date (see [_dateOnly]); the result
  /// is too.
  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final year = date.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final daysInTargetMonth = DateTime.utc(year, month + 1, 0).day;
    final day = date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
    return DateTime.utc(year, month, day);
  }
}
