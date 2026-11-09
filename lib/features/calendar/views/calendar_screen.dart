import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/task_tile.dart';
import '../../task/viewmodels/task_view_model.dart';
import '../../settings/viewmodels/settings_view_model.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(tasksProvider);
    final settings = ref.watch(settingsViewModelProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('날짜별 태스크')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(elevation: 0, color: scheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: CalendarDatePicker(
                initialDate: _selected,
                currentDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(DateTime.now().year + 15),
                onDateChanged: (date) => setState(() => _selected = date),
              ),
            ),
            const SizedBox(height: 13),
            Row(children: [
              Expanded(child: Text(formatDate(_selected),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              Text('달력 표시 설정: ${settings.calendarRows}행',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(message: '$error', icon: Icons.error_outline),
              data: (tasks) {
                final dayTasks = tasks.where((task) => isSameDay(task.dueAt, _selected)).toList();
                final completed = dayTasks.where((task) => task.isCompleted).length;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('이날의 태스크 ${dayTasks.length}개 · 완료 $completed개'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: dayTasks.isEmpty ? 0 : completed / dayTasks.length,
                    minHeight: 7, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 14),
                  if (dayTasks.isEmpty) const EmptyState(
                    message: '선택한 날짜에 등록된 태스크가 없습니다.', icon: Icons.event_available_outlined),
                  for (final task in dayTasks) TaskTile(
                    task: task,
                    onToggle: () async {
                      try {
                        await ref.read(taskViewModelProvider).toggle(task);
                      } catch (error) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('상태 변경 실패: $error')));
                      }
                    },
                  ),
                ]);
              },
            ),
          ]),
        ),
      )),
    );
  }
}
