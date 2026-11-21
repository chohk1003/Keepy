import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/repositories/shared_preferences_task_repository.dart';
import '../../../core/repositories/task_repository.dart';
import '../../../core/services/firebase/firestore_task_repository.dart';
import '../../auth/viewmodels/auth_view_model.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth != null) {
    final uid = ref.watch(
      firebaseUserProvider.select((user) => user.value?.uid),
    );
    if (uid == null) throw StateError('Firebase sign-in is required.');
    final repository = FirestoreTaskRepository(uid: uid, auth: auth);
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = SharedPreferencesTaskRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final taskViewModelProvider = Provider<TaskViewModel>(
  (ref) => TaskViewModel(ref.watch(taskRepositoryProvider)),
);

final tasksProvider = StreamProvider.autoDispose<List<Task>>(
  (ref) => ref.watch(taskViewModelProvider).watchTasks(),
);

class TaskViewModel {
  TaskViewModel(this._repository);
  final TaskRepository _repository;
  final Random _random = Random();

  Stream<List<Task>> watchTasks() => _repository.watchTasks();

  Future<void> add({
    required String title,
    String description = '',
    DateTime? dueAt,
    TaskPriority priority = TaskPriority.normal,
  }) {
    final now = DateTime.now();
    return _repository.addTask(
      Task(
        id: '${now.microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}',
        title: title.trim(),
        description: description.trim(),
        dueAt: dueAt,
        priority: priority,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> edit(
    Task old, {
    required String title,
    required String description,
    required DateTime? dueAt,
    required TaskPriority priority,
  }) => _repository.updateTask(
    Task(
      id: old.id,
      title: title.trim(),
      description: description.trim(),
      dueAt: dueAt,
      priority: priority,
      isCompleted: old.isCompleted,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    ),
  );

  Future<void> toggle(Task task) => _repository.updateTask(
    task.copyWith(isCompleted: !task.isCompleted, updatedAt: DateTime.now()),
  );

  Future<void> delete(String id) => _repository.deleteTask(id);
}
