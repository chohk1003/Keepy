import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../utils/date_helpers.dart';
import 'task_repository.dart';

/// MP2 local storage. The existing TaskRepository contract stays unchanged.
/// Queue/backup ideas reviewed in 서윤's TaskStore/LocalTaskRepository;
/// implemented here so every caller shares the same persistence guarantees.
class SharedPreferencesTaskRepository implements TaskRepository {
  SharedPreferencesTaskRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const storageKey = 'keepy.dohyeon.tasks.v1';
  static const backupKey = '$storageKey.corrupt';
  final SharedPreferencesAsync _preferences;
  final _changes = StreamController<List<Task>>.broadcast();
  Map<String, Task> _tasks = {};
  Future<void>? _loading;
  Future<void> _pending = Future<void>.value();
  bool _disposed = false;

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await _preferences.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Expected a task list');
      final loaded = <String, Task>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            item['title'] is! String ||
            (item['title'] as String).trim().isEmpty ||
            item['isCompleted'] is! bool ||
            !TaskPriority.values.any((p) => p.name == item['priority'])) {
          throw const FormatException('Invalid task');
        }
        for (final field in ['createdAt', 'updatedAt', 'dueAt']) {
          if (field == 'dueAt' && item[field] == null) continue;
          if (item[field] is! String ||
              DateTime.tryParse(item[field]) == null) {
            throw FormatException('Invalid $field');
          }
        }
        final task = Task.fromJson(item['id'] as String, item);
        if (loaded.containsKey(task.id)) {
          throw const FormatException('Duplicate task ID');
        }
        loaded[task.id] = task;
      }
      _tasks = loaded;
    } catch (_) {
      // Keep the original too; never silently replace damaged data with [].
      await _preferences.setString(backupKey, raw);
      throw const FormatException('저장 데이터가 손상되었습니다. 원본과 백업을 보존했습니다.');
    }
  }

  List<Task> _snapshot() =>
      List.unmodifiable(_tasks.values.toList()..sort(compareTasks));

  @override
  Stream<List<Task>> watchTasks() => Stream.multi((controller) {
    if (_disposed) {
      controller.close();
      return;
    }
    // Subscribe before loading/snapshotting so no intervening write is lost.
    final subscription = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
    _ensureLoaded().then(
      (_) {
        if (!_disposed) controller.add(_snapshot());
      },
      onError: (Object error, StackTrace stack) {
        controller.addError(error, stack);
      },
    );
  });

  Future<void> _write(void Function(Map<String, Task>) change) {
    if (_disposed) return Future.error(StateError('Repository is disposed'));
    final operation = _pending.then((_) async {
      await _ensureLoaded();
      final next = Map<String, Task>.of(_tasks);
      change(next);
      final raw = jsonEncode([
        for (final task in next.values) {'id': task.id, ...task.toJson()},
      ]);
      await _preferences.setString(storageKey, raw);
      // A failed write must not appear successful in the UI.
      _tasks = next;
      _changes.add(_snapshot());
    });
    // Recover the queue, while returning the failure to this operation's caller.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> addTask(Task task) => _write((tasks) {
    if (tasks.containsKey(task.id)) {
      throw StateError('Duplicate task: ${task.id}');
    }
    tasks[task.id] = task;
  });

  @override
  Future<void> updateTask(Task task) => _write((tasks) {
    if (!tasks.containsKey(task.id)) {
      throw StateError('Task does not exist: ${task.id}');
    }
    tasks[task.id] = task;
  });

  @override
  Future<void> deleteTask(String taskId) =>
      _write((tasks) => tasks.remove(taskId));

  Future<void> dispose() async {
    _disposed = true;
    await _pending;
    await _changes.close();
  }
}
