import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/local/database.dart';
import '../models/due_status.dart';
import '../providers/customer_providers.dart';
import '../widgets/due_status_badge.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCustomers = ref.watch(customersListProvider);
    final filteredCustomers = ref.watch(filteredCustomersProvider);
    final isSearching = ref.watch(customerSearchQueryProvider).trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Reminder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          allCustomers.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => const SizedBox.shrink(),
            data: (list) => list.isEmpty ? const SizedBox.shrink() : _DashboardSummary(customers: list),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(customerSearchQueryProvider.notifier).state = '';
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => ref.read(customerSearchQueryProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: filteredCustomers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Could not load customers: $error')),
              data: (list) {
                if (list.isEmpty) {
                  return isSearching ? const _NoSearchResults() : const _EmptyHomeState();
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(customersListProvider),
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _CustomerListTile(customer: list[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    var overdue = 0;
    var dueThisWeek = 0;
    for (final customer in customers) {
      switch (dueStatusFor(customer.nextDueDate)) {
        case DueStatus.overdue:
          overdue++;
        case DueStatus.dueSoon:
          dueThisWeek++;
        case DueStatus.onTrack:
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(label: 'Customers', value: customers.length, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(child: _SummaryTile(label: 'Overdue', value: overdue, color: Colors.red)),
          const SizedBox(width: 8),
          Expanded(child: _SummaryTile(label: 'Due this week', value: dueThisWeek, color: Colors.orange)),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeState extends StatelessWidget {
  const _EmptyHomeState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No customers yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your first customer to start tracking service reminders.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add your first customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No matching customers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Try a different name or phone number.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerListTile extends StatelessWidget {
  const _CustomerListTile({required this.customer});

  final Customer customer;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final status = dueStatusFor(customer.nextDueDate);

    return ListTile(
      title: Text(customer.name),
      subtitle: Text('${customer.phone} · Due ${_dateFormat.format(customer.nextDueDate)}'),
      trailing: DueStatusBadge(status: status),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer.id)),
      ),
    );
  }
}
