import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/date_helpers.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.onToggle,
    this.onEdit, this.onDelete});

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final priorityLabel = switch (task.priority) {
      TaskPriority.high => '높음',
      TaskPriority.normal => '보통',
      TaskPriority.low => '낮음',
    };
    final priorityColor = switch (task.priority) {
      TaskPriority.high => Colors.deepOrange,
      TaskPriority.normal => colorScheme.primary,
      TaskPriority.low => colorScheme.outline,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(value: task.isCompleted, onChanged: (_) => onToggle()),
        title: Text(task.title, style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted ? colorScheme.outline : null,
          fontWeight: FontWeight.w600,
        )),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(spacing: 9, runSpacing: 4, children: [
            if (task.dueAt != null) Text('📅 ${formatDate(task.dueAt!)}'),
            Text('● $priorityLabel', style: TextStyle(color: priorityColor)),
            if (task.description.isNotEmpty)
              Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        trailing: onEdit == null && onDelete == null
            ? null
            : PopupMenuButton<String>(
                tooltip: '태스크 메뉴',
                onSelected: (choice) {
                  if (choice == 'edit') onEdit?.call();
                  if (choice == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('수정')),
                  if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
      ),
    );
  }
}
