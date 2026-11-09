import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/repositories/in_memory_task_repository.dart';
import '../../../core/repositories/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => InMemoryTaskRepository.withSampleTasks(),
);

final taskViewModelProvider = Provider<TaskViewModel>(
  (ref) => TaskViewModel(ref.watch(taskRepositoryProvider)),
);

final tasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskViewModelProvider).watchTasks(),
);

class TaskViewModel {
  TaskViewModel(this._repository);
  final TaskRepository _repository;

  Stream<List<Task>> watchTasks() => _repository.watchTasks();

  Future<void> add({
    required String title,
    String description = '',
    DateTime? dueAt,
    TaskPriority priority = TaskPriority.normal,
  }) {
    final now = DateTime.now();
    return _repository.addTask(Task(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim(),
      description: description.trim(),
      dueAt: dueAt,
      priority: priority,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> edit(Task old, {
    required String title,
    required String description,
    required DateTime? dueAt,
    required TaskPriority priority,
  }) => _repository.updateTask(Task(
        id: old.id,
        title: title.trim(),
        description: description.trim(),
        dueAt: dueAt,
        priority: priority,
        isCompleted: old.isCompleted,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      ));

  Future<void> toggle(Task task) => _repository.updateTask(
        task.copyWith(isCompleted: !task.isCompleted, updatedAt: DateTime.now()),
      );

  Future<void> delete(String id) => _repository.deleteTask(id);
}
