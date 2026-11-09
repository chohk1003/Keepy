import '../models/task.dart';

abstract class TaskRepository {
  Stream<List<Task>> watchTasks();
  Future<void> addTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String taskId);
}
