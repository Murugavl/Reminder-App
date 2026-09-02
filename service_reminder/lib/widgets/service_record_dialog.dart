import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/local/database.dart';

class ServiceRecordFormResult {
  const ServiceRecordFormResult({
    required this.serviceDate,
    required this.whatChanged,
  });

  final DateTime serviceDate;
  final String whatChanged;
}

/// A dialog for logging a new service visit or correcting a previously
/// logged one. Presentation-only: pops with a [ServiceRecordFormResult] on
/// Save, or `null` on Cancel. The caller decides what to do with the result
/// (call addServiceRecord vs. updateServiceRecord).
class ServiceRecordDialog extends StatefulWidget {
  const ServiceRecordDialog({
    super.key,
    this.initial,
    required this.title,
    required this.submitLabel,
  });

  final ServiceRecord? initial;
  final String title;
  final String submitLabel;

  @override
  State<ServiceRecordDialog> createState() => _ServiceRecordDialogState();
}

class _ServiceRecordDialogState extends State<ServiceRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _whatChangedController;
  late DateTime _serviceDate;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _serviceDate = initial?.serviceDate ?? DateTime.now();
    _whatChangedController = TextEditingController(text: initial?.whatChanged ?? '');
  }

  @override
  void dispose() {
    _whatChangedController.dispose();
    super.dispose();
  }

  Future<void> _pickServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _serviceDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      ServiceRecordFormResult(
        serviceDate: _serviceDate,
        whatChanged: _whatChangedController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _pickServiceDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Service Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_dateFormat.format(_serviceDate)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatChangedController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What Changed',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please describe what was done';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
