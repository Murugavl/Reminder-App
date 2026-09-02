import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/local/database.dart';
import '../models/due_status.dart';
import '../providers/customer_providers.dart';
import '../providers/database_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/due_status_badge.dart';
import '../widgets/reminder_interval_dialog.dart';
import '../widgets/service_record_dialog.dart';
import 'edit_customer_screen.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  void _refresh(WidgetRef ref) {
    ref.invalidate(customerDetailProvider(customerId));
    ref.invalidate(customersListProvider);
  }

  Future<int> _resolveGlobalDefaultIntervalMonths(WidgetRef ref) {
    return ref.read(defaultReminderIntervalMonthsProvider.future);
  }

  Future<void> _logService(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ServiceRecordFormResult>(
      context: context,
      builder: (_) => const ServiceRecordDialog(title: 'Log Service', submitLabel: 'Save'),
    );
    if (result == null || !context.mounted) return;

    try {
      final globalDefaultIntervalMonths = await _resolveGlobalDefaultIntervalMonths(ref);
      if (!context.mounted) return;
      await ref.read(customerRepositoryProvider).addServiceRecord(
            customerId: customerId,
            serviceDate: result.serviceDate,
            whatChanged: result.whatChanged,
            globalDefaultIntervalMonths: globalDefaultIntervalMonths,
          );
      _refresh(ref);
      // Logging service is the "mark as done" step — clear their overdue
      // notification immediately rather than waiting for the next check.
      // Best-effort: a notification-plugin hiccup shouldn't make this look
      // like the service log itself failed.
      try {
        await ref.read(notificationServiceProvider).cancelForCustomer(customerId);
      } catch (_) {}
      if (context.mounted) {
        final updated = await ref.read(customerDetailProvider(customerId).future);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Service logged ✓  Next due: ${_dateFormat.format(updated.customer.nextDueDate)}',
              ),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not log service: $e')),
        );
      }
    }
  }

  Future<void> _editServiceRecord(BuildContext context, WidgetRef ref, ServiceRecord record) async {
    final result = await showDialog<ServiceRecordFormResult>(
      context: context,
      builder: (_) => ServiceRecordDialog(
        initial: record,
        title: 'Edit Service Record',
        submitLabel: 'Save Changes',
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      final globalDefaultIntervalMonths = await _resolveGlobalDefaultIntervalMonths(ref);
      if (!context.mounted) return;
      await ref.read(customerRepositoryProvider).updateServiceRecord(
            id: record.id,
            customerId: customerId,
            serviceDate: result.serviceDate,
            whatChanged: result.whatChanged,
            globalDefaultIntervalMonths: globalDefaultIntervalMonths,
          );
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service record updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update service record: $e')),
        );
      }
    }
  }

  Future<void> _deleteServiceRecord(BuildContext context, WidgetRef ref, ServiceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service record?'),
        content: Text(
          'This will remove the "${record.whatChanged}" entry from ${_dateFormat.format(record.serviceDate)}. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final globalDefaultIntervalMonths = await _resolveGlobalDefaultIntervalMonths(ref);
      if (!context.mounted) return;
      await ref.read(customerRepositoryProvider).deleteServiceRecord(
            id: record.id,
            customerId: customerId,
            globalDefaultIntervalMonths: globalDefaultIntervalMonths,
          );
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service record deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete service record: $e')),
        );
      }
    }
  }

  Future<void> _changeReminderInterval(BuildContext context, WidgetRef ref, Customer customer) async {
    final globalDefaultIntervalMonths = await _resolveGlobalDefaultIntervalMonths(ref);
    if (!context.mounted) return;

    final choice = await showDialog<ReminderIntervalChoice>(
      context: context,
      builder: (_) => ReminderIntervalDialog(
        currentOverrideMonths: customer.reminderIntervalMonths,
        globalDefaultMonths: globalDefaultIntervalMonths,
      ),
    );
    if (choice == null || !context.mounted) return;

    try {
      await ref.read(customerRepositoryProvider).setReminderIntervalOverride(
            customerId: customerId,
            months: choice.months,
            globalDefaultIntervalMonths: globalDefaultIntervalMonths,
          );
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder interval updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update reminder interval: $e')),
        );
      }
    }
  }

  Future<void> _deleteCustomer(BuildContext context, WidgetRef ref, Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
          'This will permanently delete ${customer.name} and their entire service history. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(customerRepositoryProvider).deleteCustomer(customerId);
      ref.invalidate(customersListProvider);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${customer.name} deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete customer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customerDetailProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          detail.maybeWhen(
            data: (d) => PopupMenuButton<_CustomerAction>(
              onSelected: (action) => switch (action) {
                _CustomerAction.edit => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EditCustomerScreen(customer: d.customer)),
                  ),
                _CustomerAction.delete => _deleteCustomer(context, ref, d.customer),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: _CustomerAction.edit, child: Text('Edit')),
                PopupMenuItem(value: _CustomerAction.delete, child: Text('Delete')),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load customer: $error')),
        data: (d) {
          final customer = d.customer;
          final status = dueStatusFor(customer.nextDueDate);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(customer.name, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  DueStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              _NextDueBanner(nextDueDate: customer.nextDueDate, status: status),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Phone', value: customer.phone),
                      _DetailRow(label: 'Address', value: customer.address),
                      _DetailRow(
                        label: 'Installation Date',
                        value: _dateFormat.format(customer.installationDate),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: InkWell(
                  onTap: () => _changeReminderInterval(context, ref, customer),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.event_repeat_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reminder Interval'),
                              Text(
                                customer.reminderIntervalMonths == null
                                    ? 'App default'
                                    : 'Custom: ${customer.reminderIntervalMonths} '
                                        'month${customer.reminderIntervalMonths == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Service History', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (d.serviceRecords.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No service records yet. Tap "Log Service" to add one.'),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final record in d.serviceRecords) ...[
                        _ServiceRecordTile(
                          record: record,
                          onEdit: () => _editServiceRecord(context, ref, record),
                          onDelete: () => _deleteServiceRecord(context, ref, record),
                        ),
                        if (record != d.serviceRecords.last) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logService(context, ref),
        icon: const Icon(Icons.build),
        label: const Text('Log Service'),
      ),
    );
  }
}

enum _CustomerAction { edit, delete }

class _NextDueBanner extends StatelessWidget {
  const _NextDueBanner({required this.nextDueDate, required this.status});

  final DateTime nextDueDate;
  final DueStatus status;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (status) {
      DueStatus.overdue => (Colors.red, Icons.warning_amber_rounded),
      DueStatus.dueSoon => (Colors.orange, Icons.schedule),
      DueStatus.onTrack => (Colors.green, Icons.check_circle_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == DueStatus.overdue ? 'Service overdue' : 'Next service due',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
                ),
                Text(
                  _dateFormat.format(nextDueDate),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _ServiceRecordTile extends StatelessWidget {
  const _ServiceRecordTile({required this.record, required this.onEdit, required this.onDelete});

  final ServiceRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(record.whatChanged),
      subtitle: Text(_dateFormat.format(record.serviceDate)),
      trailing: PopupMenuButton<_ServiceRecordAction>(
        onSelected: (action) => switch (action) {
          _ServiceRecordAction.edit => onEdit(),
          _ServiceRecordAction.delete => onDelete(),
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _ServiceRecordAction.edit, child: Text('Edit')),
          PopupMenuItem(value: _ServiceRecordAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }
}

enum _ServiceRecordAction { edit, delete }
