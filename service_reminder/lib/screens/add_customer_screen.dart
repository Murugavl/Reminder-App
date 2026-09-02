import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/customer_providers.dart';
import '../providers/database_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/customer_form.dart';

class AddCustomerScreen extends ConsumerWidget {
  const AddCustomerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: CustomerForm(
        submitLabel: 'Save',
        onSubmit: (result) async {
          final globalDefaultIntervalMonths = await ref.read(defaultReminderIntervalMonthsProvider.future);
          await ref.read(customerRepositoryProvider).addCustomer(
                name: result.name,
                phone: result.phone,
                address: result.address,
                installationDate: result.installationDate,
                globalDefaultIntervalMonths: globalDefaultIntervalMonths,
              );
          ref.invalidate(customersListProvider);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
