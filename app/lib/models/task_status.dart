import '../core/dates.dart';
import 'task.dart';

/// 할 일 상태 분류 (prompts_log #11).
///
/// - todo: 해야 할 일
/// - delayed: 지연 — 기한이 지났거나, 기한 없이 만든 지 N일이 지난 일.
///   '못함'은 실패로 단정하는 말이라 아직 끝낼 수 있다는 뜻이 남는 '지연'을 쓴다.
/// - done: 완료
/// - lateDone: 늦은 완료 — 지연 상태에서 완료한 일.
enum TaskStatus { todo, delayed, done, lateDone }

extension TaskStatusLabel on TaskStatus {
  String get label => switch (this) {
        TaskStatus.todo => '해야 할 일',
        TaskStatus.delayed => '지연',
        TaskStatus.done => '완료',
        TaskStatus.lateDone => '늦은 완료',
      };

  bool get isOpen => this == TaskStatus.todo || this == TaskStatus.delayed;
}

/// 아직 완료하지 않은 일이 '지연'인지.
///
/// 기한 있음: 기한 다음 날 0시부터 지연.
/// 기한 없음: 만든 뒤 [delayDays]일이 지나면 지연 (설정에서 변경, 기본 3일).
bool isDelayed(Task task, {required DateTime now, required int delayDays}) {
  if (task.done) return false;
  final due = task.due;
  if (due != null) return daysBetween(due, now) > 0;
  return now.difference(task.createdAt) >= Duration(days: delayDays);
}

TaskStatus statusOf(Task task, {required DateTime now, required int delayDays}) {
  if (task.done) return task.completedLate ? TaskStatus.lateDone : TaskStatus.done;
  return isDelayed(task, now: now, delayDays: delayDays)
      ? TaskStatus.delayed
      : TaskStatus.todo;
}
