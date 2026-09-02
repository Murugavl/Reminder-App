import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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
///
/// When [showContactPicker] is true (default), a contacts icon button is
/// embedded in the Name field's suffix. Tapping it opens the OS-native contact
/// picker, then auto-fills Name and Phone from the selected contact.
class CustomerForm extends StatefulWidget {
  const CustomerForm({
    super.key,
    this.initial,
    required this.onSubmit,
    required this.submitLabel,
    this.showContactPicker = true,
  });

  final Customer? initial;
  final Future<void> Function(CustomerFormResult result) onSubmit;
  final String submitLabel;

  /// Whether to show the "import from contacts" icon next to the Name field.
  final bool showContactPicker;

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
  bool _isPickingContact = false;

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

  // ─── Contact picker ──────────────────────────────────────────────────────

  Future<void> _pickContact() async {
    if (_isPickingContact) return;
    setState(() => _isPickingContact = true);

    try {
      // On Android, openExternalPick() returns a contact with phones only if
      // READ_CONTACTS is granted (the OS picker itself needs no permission, but
      // reading phone numbers from the returned URI does).
      final granted = await FlutterContacts.requestPermission(readonly: true);

      if (!granted) {
        if (!mounted) return;
        _showPermissionDeniedDialog();
        return;
      }

      // Opens the OS-native contact picker (no custom list UI).
      // Returns null if the user cancels.
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;

      // Re-fetch the contact with phone numbers — openExternalPick() returns a
      // lightly-fetched contact (id + displayName only by default).
      final full = await FlutterContacts.getContact(
        contact.id,
        withProperties: true,
      );
      if (full == null || !mounted) return;

      final name = full.displayName.trim();
      final phones = full.phones;

      // ── No phone number at all ──────────────────────────────────────────
      if (phones.isEmpty) {
        _nameController.text = name;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                name.isEmpty
                    ? 'The selected contact has no phone number. Please enter one manually.'
                    : '"$name" has no phone number saved. Please enter one manually.',
              ),
            ),
          );
        }
        return;
      }

      // ── Exactly one phone number — fill immediately ────────────────────
      if (phones.length == 1) {
        _autofill(name: name, rawPhone: phones.first.number);
        return;
      }

      // ── Multiple phone numbers — ask the user to pick one ──────────────
      final chosen = await _showPhonePickerDialog(name: name, phones: phones);
      if (chosen != null && mounted) {
        _autofill(name: name, rawPhone: chosen);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open contacts: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingContact = false);
    }
  }

  /// Strips non-digit characters from [rawPhone] before writing to the field,
  /// so the form's digit-only validator passes for standard numbers.
  void _autofill({required String name, required String rawPhone}) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    _nameController.text = name;
    _phoneController.text = digitsOnly;
    // Re-trigger validation so any previous error clears immediately.
    _formKey.currentState?.validate();
  }

  Future<String?> _showPhonePickerDialog({
    required String name,
    required List<Phone> phones,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name.isEmpty ? 'Which number?' : 'Which number for "$name"?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final phone in phones)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(phone.number),
                  subtitle: _labelText(phone.label).isNotEmpty
                      ? Text(
                          _labelText(phone.label),
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(phone.number),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Human-readable label from a [PhoneLabel], e.g. "mobile", "work", "home".
  String _labelText(PhoneLabel label) {
    return switch (label) {
      PhoneLabel.mobile => 'Mobile',
      PhoneLabel.home => 'Home',
      PhoneLabel.work => 'Work',
      PhoneLabel.faxHome => 'Fax (home)',
      PhoneLabel.faxWork => 'Fax (work)',
      PhoneLabel.other => 'Other',
      _ => '',
    };
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contacts permission needed'),
        content: const Text(
          'Service Reminder needs access to your contacts to auto-fill the '
          'customer name and phone number.\n\n'
          'You can still enter them manually, or grant the permission in '
          'Settings → Apps → Service Reminder → Permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Form submission ─────────────────────────────────────────────────────

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

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name field — with optional contacts-icon button embedded as suffix.
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Customer Name',
              border: const OutlineInputBorder(),
              suffixIcon: widget.showContactPicker
                  ? Tooltip(
                      message: 'Import from contacts',
                      child: _isPickingContact
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.contacts_outlined),
                              onPressed: _pickContact,
                            ),
                    )
                  : null,
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
