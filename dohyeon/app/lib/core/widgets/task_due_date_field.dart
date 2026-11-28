import 'package:flutter/material.dart';

import '../utils/date_helpers.dart';

class TaskDueDateField extends StatelessWidget {
  const TaskDueDateField({
    super.key,
    required this.dueAt,
    required this.onChanged,
    this.emptyLabel = '마감일 선택',
  });

  final DateTime? dueAt;
  final ValueChanged<DateTime?>? onChanged;
  final String emptyLabel;

  Future<void> _select(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dueAt ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 15),
    );
    if (context.mounted && picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = dueAt;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onChanged == null ? null : () => _select(context),
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(date == null ? emptyLabel : formatDate(date)),
          ),
        ),
        if (date != null)
          IconButton(
            tooltip: '마감일 제거',
            onPressed: onChanged == null ? null : () => onChanged?.call(null),
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}
