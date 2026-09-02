enum DueStatus { overdue, dueSoon, onTrack }

/// The notification fires the night *before* the due date, so the UI badge
/// should match: show a customer as overdue when they are 1 day or less away
/// from their nextDueDate (i.e. daysUntilDue <= 1 means overdue-or-eve).
/// The due-soon window is extended by the same 1-day shift.
const dueSoonWindowDays = 7;

/// Classifies a customer's next_due_date relative to [now] (defaults to
/// today), ignoring time-of-day on both sides.
///
/// A customer is treated as [DueStatus.overdue] when today is the day before
/// (or past) their nextDueDate, so the badge aligns with the nightly
/// notification that fires one day early.
DueStatus dueStatusFor(DateTime nextDueDate, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final due = _dateOnly(nextDueDate);
  // Shift by -1: overdue starts when there is ≤1 day until due.
  final daysUntilDue = due.difference(today).inDays - 1;

  if (daysUntilDue <= 0) return DueStatus.overdue;
  if (daysUntilDue <= dueSoonWindowDays) return DueStatus.dueSoon;
  return DueStatus.onTrack;
}

// Matches CustomerRepository's storage convention: dates are normalized to
// UTC midnight so comparisons are correct regardless of the device's
// timezone (see CustomerRepository._dateOnly for the full rationale).
DateTime _dateOnly(DateTime date) => DateTime.utc(date.year, date.month, date.day);
