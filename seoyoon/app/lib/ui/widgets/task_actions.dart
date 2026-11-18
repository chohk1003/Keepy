import 'package:flutter/widgets.dart';

import '../../core/dates.dart';
import '../../models/task.dart';
import '../../state/task_store.dart';
import 'scroll_aware.dart';
import 'task_tile.dart';
import 'undo_toast.dart';

/// 할 일 조작 + 되돌리기 알림을 한곳에 모은 도우미.
/// 메인·날짜 화면이 같은 동작을 공유한다.
class TaskActions {
  TaskActions({required this.store, required this.toast, required this.openEditor});

  final TaskStore store;
  final ToastController toast;
  final void Function(Task task) openEditor;

  void toggle(Task task) {
    final before = task;
    store.toggle(task.id);
    final after = store.byId(task.id);
    if (after == null) return;
    final text = after.done
        ? (after.completedLate ? '늦은 완료로 옮겼어요' : '완료했어요')
        : '다시 할 일로 옮겼어요';
    toast.show(text, actionLabel: '취소', onAction: () => store.put(before));
  }

  void delete(Task task) {
    final removed = store.remove(task.id);
    if (removed == null) return;
    toast.show('삭제했어요', actionLabel: '취소', onAction: () => store.restore(removed));
  }

  void setDue(Task task, DateTime due) {
    final before = task;
    store.setDue(task.id, due);
    toast.show('${relativeDayLabel(due, store.today)}로 옮겼어요', actionLabel: '취소', onAction: () => store.put(before));
  }

  /// 완료한 일 모두 지우기 + 되돌리기 (v0.5).
  void clearDone() {
    final removed = store.removeDone();
    if (removed.isEmpty) return;
    toast.show('완료한 일 ${removed.length}개를 지웠어요', actionLabel: '취소', onAction: () => store.restoreAll(removed));
  }

  /// 리스트 한 줄: 하단 사라짐 효과 + 스와이프 블럭.
  /// [editing] 이면 순서 바꾸기 손잡이가 붙는다 ([index] = 구역 안 위치).
  Widget tile(Task task, {bool editing = false, int? index}) {
    return EdgeFade(
      key: ValueKey<String>('fade-${task.id}'),
      child: TaskTile(
        key: ValueKey<String>(task.id),
        task: task,
        status: store.statusOf(task),
        today: store.today,
        editing: editing,
        reorderIndex: index,
        onToggle: () => toggle(task),
        onSetDue: (d) => setDue(task, d),
        onDelete: () => delete(task),
        onOpen: () => openEditor(task),
      ),
    );
  }
}
