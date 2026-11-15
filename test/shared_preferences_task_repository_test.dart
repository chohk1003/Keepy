import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keepy_prototype/core/models/task.dart';
import 'package:keepy_prototype/core/repositories/shared_preferences_task_repository.dart';
import 'package:keepy_prototype/features/task/viewmodels/task_view_model.dart';

// Mutable controls intentionally simulate slow and failing platform writes.
// ignore: must_be_immutable
class FakePreferences implements SharedPreferencesAsync {
  final data = <String, String>{};
  Completer<void>? gate;
  bool fail = false;
  int activeWrites = 0;
  int maxWrites = 0;

  @override
  Future<String?> getString(String key) async => data[key];

  @override
  Future<void> setString(String key, String value) async {
    activeWrites++;
    if (activeWrites > maxWrites) maxWrites = activeWrites;
    try {
      await gate?.future;
      if (fail) throw StateError('Disk full');
      data[key] = value;
    } finally {
      activeWrites--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePreferences prefs;
  SharedPreferencesTaskRepository boot() {
    final repo = SharedPreferencesTaskRepository(preferences: prefs);
    addTearDown(repo.dispose);
    return repo;
  }

  setUp(() => prefs = FakePreferences());

  test(
    'first launch is empty; every subscriber receives current state',
    () async {
      final repo = boot();
      expect(await repo.watchTasks().first, isEmpty);
      await TaskViewModel(repo).add(title: '과제');
      expect((await repo.watchTasks().first).single.title, '과제');
      expect((await repo.watchTasks().first).single.title, '과제');
    },
  );

  test(
    'CRUD, completion, dates and timestamps survive repository restart',
    () async {
      final repo = boot();
      final vm = TaskViewModel(repo);
      await vm.add(
        title: ' 과제 ',
        description: ' 메모 ',
        dueAt: DateTime(2026, 11, 20),
        priority: TaskPriority.high,
      );
      final original = (await repo.watchTasks().first).single;
      await vm.toggle(original);
      final completed = (await repo.watchTasks().first).single;
      await vm.edit(
        completed,
        title: '수정 과제',
        description: '새 메모',
        dueAt: null,
        priority: TaskPriority.low,
      );
      final restored = (await boot().watchTasks().first).single;
      expect(restored.id, original.id);
      expect(restored.title, '수정 과제');
      expect(restored.description, '새 메모');
      expect(restored.isCompleted, isTrue);
      expect(restored.dueAt, isNull);
      expect(restored.priority, TaskPriority.low);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt.isBefore(original.updatedAt), isFalse);
      await vm.delete(restored.id);
      expect(await boot().watchTasks().first, isEmpty);
      expect(
        jsonDecode(prefs.data[SharedPreferencesTaskRepository.storageKey]!),
        isEmpty,
      );
    },
  );

  test('overlapping requests serialize and preserve all changes', () async {
    final repo = boot();
    final vm = TaskViewModel(repo);
    prefs.gate = Completer<void>();
    final first = vm.add(title: 'A');
    final second = vm.add(title: 'B');
    await Future<void>.delayed(Duration.zero);
    expect(prefs.activeWrites, 1);
    prefs.gate!.complete();
    await Future.wait([first, second]);
    expect(prefs.maxWrites, 1);
    final tasks = await repo.watchTasks().first;
    expect(tasks.map((t) => t.title), unorderedEquals(['A', 'B']));
    await Future.wait([vm.toggle(tasks[0]), vm.delete(tasks[1].id)]);
    final restored = await boot().watchTasks().first;
    expect(restored, hasLength(1));
    expect(restored.single.isCompleted, isTrue);
  });

  test(
    'failed write leaves memory and disk unchanged; next write succeeds',
    () async {
      final repo = boot();
      final vm = TaskViewModel(repo);
      await vm.add(title: '기존');
      final saved = prefs.data[SharedPreferencesTaskRepository.storageKey];
      prefs.fail = true;
      await expectLater(vm.add(title: '실패'), throwsStateError);
      expect((await repo.watchTasks().first).single.title, '기존');
      expect(prefs.data[SharedPreferencesTaskRepository.storageKey], saved);
      prefs.fail = false;
      await vm.add(title: '성공');
      expect(await boot().watchTasks().first, hasLength(2));
    },
  );

  test('malformed data is backed up and never silently overwritten', () async {
    for (final raw in ['broken json', '{}', '[{"id":"missing-fields"}]']) {
      prefs.data[SharedPreferencesTaskRepository.storageKey] = raw;
      final repo = boot();
      await expectLater(repo.watchTasks().first, throwsFormatException);
      await expectLater(
        TaskViewModel(repo).add(title: '새 항목'),
        throwsFormatException,
      );
      expect(prefs.data[SharedPreferencesTaskRepository.storageKey], raw);
      expect(prefs.data[SharedPreferencesTaskRepository.backupKey], raw);
    }
  });

  test(
    'stream publishes only committed snapshots, supports cancellation',
    () async {
      final repo = boot();
      final snapshots = <List<Task>>[];
      final subscription = repo.watchTasks().listen(snapshots.add);
      await Future<void>.delayed(Duration.zero);
      prefs.gate = Completer<void>();
      final saving = TaskViewModel(repo).add(title: '저장 중');
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last, isEmpty);
      prefs.gate!.complete();
      await saving;
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last.single.title, '저장 중');
      await subscription.cancel();
    },
  );

  test(
    'missing updates and duplicate IDs do not replace existing data',
    () async {
      final repo = boot();
      await TaskViewModel(repo).add(title: '기존');
      final task = (await repo.watchTasks().first).single;
      await expectLater(repo.addTask(task), throwsStateError);
      await repo.deleteTask(task.id);
      await expectLater(repo.updateTask(task), throwsStateError);
      expect(await boot().watchTasks().first, isEmpty);
    },
  );
}
