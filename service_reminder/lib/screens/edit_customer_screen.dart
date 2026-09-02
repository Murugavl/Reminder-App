import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../providers/customer_providers.dart';
import '../providers/database_providers.dart';
import '../widgets/customer_form.dart';

/// Edits base customer/installation details only. Service history is managed
/// separately (Phase 3).
class EditCustomerScreen extends ConsumerWidget {
  const EditCustomerScreen({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Customer')),
      body: CustomerForm(
        initial: customer,
        submitLabel: 'Save Changes',
        onSubmit: (result) async {
          await ref.read(customerRepositoryProvider).updateCustomer(
                id: customer.id,
                name: result.name,
                phone: result.phone,
                address: result.address,
                installationDate: result.installationDate,
              );
          ref.invalidate(customersListProvider);
          ref.invalidate(customerDetailProvider(customer.id));
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
