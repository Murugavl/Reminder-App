import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../models/customer_with_history.dart';
import 'database_providers.dart';

/// All customers, overdue-first. Call `ref.invalidate(customersListProvider)`
/// after any add/update/service-record mutation to refresh the list.
final customersListProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).getAllCustomers();
});

/// Current text typed into the HomeScreen search bar.
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

/// [customersListProvider] filtered by [customerSearchQueryProvider], matching
/// against name or phone (case-insensitive).
final filteredCustomersProvider = Provider<AsyncValue<List<Customer>>>((ref) {
  final query = ref.watch(customerSearchQueryProvider).trim().toLowerCase();
  final customers = ref.watch(customersListProvider);

  if (query.isEmpty) return customers;

  return customers.whenData(
    (list) => list
        .where((c) => c.name.toLowerCase().contains(query) || c.phone.contains(query))
        .toList(),
  );
});

/// A single customer plus their service history. Call
/// `ref.invalidate(customerDetailProvider(id))` after editing that customer.
final customerDetailProvider = FutureProvider.family<CustomerWithHistory, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getCustomerWithHistory(id);
});
