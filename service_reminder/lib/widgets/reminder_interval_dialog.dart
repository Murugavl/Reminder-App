import 'package:flutter/material.dart';

const _customIntervalChoices = [1, 2, 3, 6, 12];

/// The user's choice from [ReminderIntervalDialog]. [months] is null when
/// they picked "Use app default" — distinct from the dialog being cancelled,
/// which returns no result at all (see [showDialog]'s null-on-dismiss).
class ReminderIntervalChoice {
  const ReminderIntervalChoice(this.months);
  final int? months;
}

/// Lets the user pick between the app-wide default reminder interval and a
/// custom one for a single customer — the "advanced, per-customer override"
/// control referenced from CustomerDetailScreen.
class ReminderIntervalDialog extends StatefulWidget {
  const ReminderIntervalDialog({
    super.key,
    required this.currentOverrideMonths,
    required this.globalDefaultMonths,
  });

  final int? currentOverrideMonths;
  final int globalDefaultMonths;

  @override
  State<ReminderIntervalDialog> createState() => _ReminderIntervalDialogState();
}

class _ReminderIntervalDialogState extends State<ReminderIntervalDialog> {
  late bool _useCustom = widget.currentOverrideMonths != null;
  late int _customMonths = widget.currentOverrideMonths ?? widget.globalDefaultMonths;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reminder Interval'),
      content: RadioGroup<bool>(
        groupValue: _useCustom,
        onChanged: (value) => setState(() => _useCustom = value ?? false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: Text('Use app default (${widget.globalDefaultMonths} months)'),
              value: false,
            ),
            RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom interval for this customer'),
              value: true,
            ),
            if (_useCustom)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: DropdownButton<int>(
                  value: _customMonths,
                  items: [
                    for (final months in _customIntervalChoices)
                      DropdownMenuItem(value: months, child: Text('$months month${months == 1 ? '' : 's'}')),
                  ],
                  onChanged: (months) {
                    if (months != null) setState(() => _customMonths = months);
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ReminderIntervalChoice(_useCustom ? _customMonths : null),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
