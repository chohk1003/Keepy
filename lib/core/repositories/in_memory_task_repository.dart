import 'dart:async';

import '../models/task.dart';
import '../utils/date_helpers.dart';
import 'task_repository.dart';

/// Prototype-only implementation: tasks disappear after the app restarts.
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository([Iterable<Task> initialTasks = const []])
      : _tasks = {for (final task in initialTasks) task.id: task};

  factory InMemoryTaskRepository.withSampleTasks() {
    final now = DateTime.now();
    DateTime onDay(int days) => DateTime(now.year, now.month, now.day + days);
    return InMemoryTaskRepository([
      Task(id: 'sample1', title: '모바일 프로젝트 화면 구성',
          description: '메인과 달력 화면 정리', dueAt: onDay(0),
          priority: TaskPriority.high, createdAt: now, updatedAt: now),
      Task(id: 'sample2', title: '네트워크 프로그래밍 주간 보고',
          dueAt: onDay(1), createdAt: now, updatedAt: now),
      Task(id: 'sample3', title: 'OCR 기능 회의 자료 준비',
          dueAt: onDay(3), priority: TaskPriority.low,
          createdAt: now, updatedAt: now),
      Task(id: 'sample4', title: 'Firebase 구조 설계',
          dueAt: onDay(-1), isCompleted: true,
          createdAt: now, updatedAt: now),
    ]);
  }

  final Map<String, Task> _tasks;
  final StreamController<List<Task>> _changes = StreamController.broadcast();

  List<Task> _snapshot() =>
      List.unmodifiable(_tasks.values.toList()..sort(compareTasks));

  @override
  Stream<List<Task>> watchTasks() async* {
    yield _snapshot();
    yield* _changes.stream;
  }

  void _notify() => _changes.add(_snapshot());

  @override
  Future<void> addTask(Task task) async {
    _tasks[task.id] = task;
    _notify();
  }

  @override
  Future<void> updateTask(Task task) async {
    if (!_tasks.containsKey(task.id)) {
      throw StateError('Task does not exist: ${task.id}');
    }
    _tasks[task.id] = task;
    _notify();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _tasks.remove(taskId);
    _notify();
  }

  Future<void> dispose() => _changes.close();
}
