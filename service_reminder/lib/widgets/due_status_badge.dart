import 'package:flutter/material.dart';

import '../models/due_status.dart';

class DueStatusBadge extends StatelessWidget {
  const DueStatusBadge({super.key, required this.status});

  final DueStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      DueStatus.overdue => (Colors.red, 'Overdue'),
      DueStatus.dueSoon => (Colors.orange, 'Due soon'),
      DueStatus.onTrack => (Colors.green, 'On track'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
