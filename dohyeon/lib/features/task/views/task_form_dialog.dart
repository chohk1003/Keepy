import 'package:flutter/material.dart';

import '../../../core/models/task.dart';
import '../../../core/utils/date_helpers.dart';

class TaskDraft {
  const TaskDraft({required this.title, required this.description,
    required this.dueAt, required this.priority});
  final String title;
  final String description;
  final DateTime? dueAt;
  final TaskPriority priority;
}

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, this.task});
  final Task? task;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late TaskPriority _priority;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _description = TextEditingController(text: widget.task?.description ?? '');
    _priority = widget.task?.priority ?? TaskPriority.normal;
    _dueAt = widget.task?.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? '새 태스크' : '태스크 수정'),
    content: SizedBox(width: 440, child: SingleChildScrollView(child:
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _title, autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '제목 *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 2,
            decoration: const InputDecoration(labelText: '메모', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: '우선순위', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: TaskPriority.low, child: Text('낮음')),
              DropdownMenuItem(value: TaskPriority.normal, child: Text('보통')),
              DropdownMenuItem(value: TaskPriority.high, child: Text('높음')),
            ],
            onChanged: (value) { if (value != null) setState(() => _priority = value); },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueAt ?? now,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year + 15),
                );
                if (picked != null && mounted) setState(() => _dueAt = picked);
              },
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_dueAt == null ? '마감일 선택' : formatDate(_dueAt!)),
            )),
            if (_dueAt != null) IconButton(
              tooltip: '마감일 제거',
              onPressed: () => setState(() => _dueAt = null),
              icon: const Icon(Icons.close),
            ),
          ]),
        ],
      ),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      FilledButton(onPressed: () {
        final title = _title.text.trim();
        if (title.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('제목을 입력해 주세요.')),
          );
          return;
        }
        Navigator.pop(context, TaskDraft(title: title,
          description: _description.text.trim(), dueAt: _dueAt, priority: _priority));
      }, child: const Text('저장')),
    ],
  );
}
