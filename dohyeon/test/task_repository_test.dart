import 'package:flutter_test/flutter_test.dart';
import 'package:keepy_prototype/core/models/task.dart';
import 'package:keepy_prototype/core/repositories/in_memory_task_repository.dart';

void main() {
  test('InMemoryTaskRepository supports add, update, and delete', () async {
    final repository = InMemoryTaskRepository();
    final now = DateTime(2026, 11, 9);
    final task = Task(id: 'one', title: '테스트', createdAt: now, updatedAt: now);

    expect(await repository.watchTasks().first, isEmpty);
    await repository.addTask(task);
    expect((await repository.watchTasks().first).single.title, '테스트');

    await repository.updateTask(task.copyWith(isCompleted: true));
    expect((await repository.watchTasks().first).single.isCompleted, isTrue);

    await repository.deleteTask('one');
    expect(await repository.watchTasks().first, isEmpty);
    await repository.dispose();
  });
}
