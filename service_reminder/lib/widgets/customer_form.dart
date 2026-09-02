import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local/database.dart';

class CustomerFormResult {
  const CustomerFormResult({
    required this.name,
    required this.phone,
    required this.address,
    required this.installationDate,
  });

  final String name;
  final String phone;
  final String address;
  final DateTime installationDate;
}

/// Shared Name/Phone/Address/Installation-date form used by both
/// AddCustomerScreen and EditCustomerScreen. Presentation-only: the caller
/// decides what [onSubmit] actually does (insert vs. update) and how to
/// navigate away afterwards.
class CustomerForm extends StatefulWidget {
  const CustomerForm({
    super.key,
    this.initial,
    required this.onSubmit,
    required this.submitLabel,
  });

  final Customer? initial;
  final Future<void> Function(CustomerFormResult result) onSubmit;
  final String submitLabel;

  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  DateTime? _installationDate;
  bool _isSaving = false;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _addressController = TextEditingController(text: initial?.address ?? '');
    _installationDate = initial?.installationDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickInstallationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _installationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _installationDate = picked);
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    final installationDate = _installationDate;

    if (installationDate == null) {
      // Trigger revalidation so the date field's error text appears too.
      setState(() {});
    }
    if (!formValid || installationDate == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(
        CustomerFormResult(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          installationDate: installationDate,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save customer: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Customer Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Customer name is required';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Phone number is required';
              if (!RegExp(r'^\d{7,15}$').hasMatch(trimmed)) {
                return 'Enter a valid phone number (digits only)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickInstallationDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date of Installation',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
                errorText: _installationDate == null ? 'Installation date is required' : null,
              ),
              child: Text(
                _installationDate == null ? '' : _dateFormat.format(_installationDate!),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
