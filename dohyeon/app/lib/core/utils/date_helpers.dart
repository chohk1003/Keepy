import '../models/task.dart';

bool isSameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

String formatDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

int compareTasks(Task a, Task b) {
  if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
  final aDue = a.dueAt ?? DateTime(9999);
  final bDue = b.dueAt ?? DateTime(9999);
  final byDate = aDue.compareTo(bDue);
  if (byDate != 0) return byDate;
  return b.createdAt.compareTo(a.createdAt);
}
