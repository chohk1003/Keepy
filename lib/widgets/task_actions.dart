import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'fx.dart';
import 'task_editor.dart';
import 'task_tile.dart';
import 'toast.dart';

/// 하단 토스트 (실행 취소 포함) — 0.6초, 다른 동작 시 즉시 사라짐
void showToast(
  BuildContext context,
  String text, {
  IconData icon = CupertinoIcons.checkmark_circle_fill,
  List<Color> colors = const [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
  VoidCallback? undo,
}) =>
    Toast.show(context, text, icon: icon, colors: colors, undo: undo);

/// 화면 공통: 태스크 블럭 + 조작별 토스트
Widget buildTaskTile(BuildContext context, Task t) {
  final s = AppScope.read(context);
  return EdgeFade(
    child: TaskTile(
    key: ValueKey(t.id),
    task: t,
    status: s.statusOf(t),
    tagOrder: s.tagsByUsage(),
    onToggle: () {
      // 체크 후 0.52초 안에 삭제하면 블럭이 사라지면서 지연 커밋이 뒤늦게 들어온다.
      // 이미 목록에 없는 항목이면 완료 처리·완료 기록을 남기지 않는다.
      if (!s.tasks.contains(t)) return;
      final value = !t.done;
      s.setDone(t, value);
      if (value) {
        showToast(context, '완료', undo: () => s.setDone(t, false));
      }
    },
    onTap: () => showTaskEditor(context, t),
    onDial: (d) {
      final prev = t.due;
      s.update(t, due: d);
      showToast(
        context,
        '${mdw(d)} 지정',
        icon: CupertinoIcons.calendar_badge_plus,
        undo: () => s.update(t, due: prev, clearDue: prev == null),
      );
    },
    onTag: (tag) {
      final prev = {...t.tags};
      s.update(t, tags: tag == null ? <TaskTag>{} : {tag});
      showToast(
        context,
        tag == null ? '태그 없음' : '#${tag.label}',
        icon: CupertinoIcons.tag_fill,
        colors: tag?.colors ?? const [Color(0xFF8E8E93), Color(0xFF636366)],
        undo: () => s.update(t, tags: prev),
      );
    },
    onDelete: () {
      final i = s.remove(t);
      showToast(
        context,
        '삭제',
        icon: CupertinoIcons.trash_fill,
        colors: const [Color(0xFFFF453A), Color(0xFFFF2D55)],
        undo: () => s.restore(i, t),
      );
    },
    ),
  );
}

/// 섹션 머리 (항목이 없으면 접힘)
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, this.count, {super.key, this.gradient = K.brand2});

  final String text;
  final int count;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.med,
      curve: Motion.out,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
              child: Row(
                children: [
                  Text(text, style: T.title3),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: RollingText(
                      '$count',
                      style: T.caption.copyWith(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
