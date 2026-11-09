import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/task_tile.dart';
import '../viewmodels/task_view_model.dart';
import 'task_form_dialog.dart';

enum TaskFilter { all, active, completed }

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});
  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  TaskFilter _filter = TaskFilter.all;

  Future<void> _save([Task? existing]) async {
    final draft = await showDialog<TaskDraft>(context: context,
      builder: (_) => TaskFormDialog(task: existing));
    if (draft == null || !mounted) return;
    try {
      final viewModel = ref.read(taskViewModelProvider);
      if (existing == null) {
        await viewModel.add(title: draft.title, description: draft.description,
          dueAt: draft.dueAt, priority: draft.priority);
      } else {
        await viewModel.edit(existing, title: draft.title,
          description: draft.description, dueAt: draft.dueAt,
          priority: draft.priority);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $error')));
    }
  }

  Future<void> _delete(Task task) async {
    try {
      await ref.read(taskViewModelProvider).delete(task.id);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $error')));
    }
  }

  Future<void> _toggle(Task task) async {
    try {
      await ref.read(taskViewModelProvider).toggle(task);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태 변경 실패: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Keepy')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _save(), icon: const Icon(Icons.add), label: const Text('태스크 추가')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(message: '태스크를 불러오지 못했습니다.\n$error',
            icon: Icons.error_outline),
          data: (tasks) {
            final completed = tasks.where((t) => t.isCompleted).length;
            final selected = tasks.where((task) => switch (_filter) {
              TaskFilter.all => true,
              TaskFilter.active => !task.isCompleted,
              TaskFilter.completed => task.isCompleted,
            }).toList();
            return ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
              children: [
                _SummaryCard(total: tasks.length, completed: completed),
                const SizedBox(height: 22),
                Text('할 일 목록', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 9, children: [
                  ChoiceChip(label: const Text('전체'), selected: _filter == TaskFilter.all,
                    onSelected: (_) => setState(() => _filter = TaskFilter.all)),
                  ChoiceChip(label: const Text('미완료'), selected: _filter == TaskFilter.active,
                    onSelected: (_) => setState(() => _filter = TaskFilter.active)),
                  ChoiceChip(label: const Text('완료'), selected: _filter == TaskFilter.completed,
                    onSelected: (_) => setState(() => _filter = TaskFilter.completed)),
                ]),
                const SizedBox(height: 12),
                if (selected.isEmpty) const EmptyState(message: '표시할 태스크가 없습니다.'),
                for (final task in selected) TaskTile(key: ValueKey(task.id), task: task,
                  onToggle: () => _toggle(task), onEdit: () => _save(task),
                  onDelete: () => _delete(task)),
              ]);
          },
        ),
      )),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.completed});
  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(23),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('KEEPY  /  TODAY', style: TextStyle(
          color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 13),
        const Text('오늘도 차근차근,\n할 일을 정리해 보세요.', style: TextStyle(
          color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 18),
        Row(children: [
          _SummaryNumber(label: '전체', number: total),
          const SizedBox(width: 28),
          _SummaryNumber(label: '미완료', number: total - completed),
          const SizedBox(width: 28),
          _SummaryNumber(label: '완료', number: completed),
        ]),
        const SizedBox(height: 15),
        ClipRRect(borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: total == 0 ? 0 : completed / total,
            minHeight: 7, backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
      ]),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  const _SummaryNumber({required this.label, required this.number});
  final String label;
  final int number;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$number', style: const TextStyle(color: Colors.white,
        fontSize: 24, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70)),
    ],
  );
}
