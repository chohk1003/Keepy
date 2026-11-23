import 'package:flutter/cupertino.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'fx.dart';
import 'task_editor.dart';
import 'task_tile.dart';
import 'toast.dart';

/// 지운 것을 되돌릴 토스트는 4초 — 취소 버튼을 알아보고 누를 시간이 필요하다.
/// 완료·날짜·태그처럼 다시 누르면 그만인 동작은 기본(0.6초)으로 짧게 둔다.
const undoToastLife = Duration(seconds: 4);

/// 하단 토스트 (실행 취소 포함) — 0.6초, 다른 동작 시 즉시 사라짐
void showToast(
  BuildContext context,
  String text, {
  IconData icon = CupertinoIcons.checkmark_circle_fill,
  List<Color> colors = const [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
  VoidCallback? undo,
  Duration? life,
}) => Toast.show(
  context,
  text,
  icon: icon,
  colors: colors,
  undo: undo,
  life: life,
);

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
          colors: K.deleteColors,
          life: undoToastLife,
          undo: () => s.restore(i, t),
        );
      },
    ),
  );
}

/// 섹션 머리 (항목이 없으면 접힘) — 서윤님 구현처럼 조용한 캡션 + 개수.
/// [trailing] 은 '완료' 섹션의 접기·비우기처럼 머리에 붙는 조작.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.text,
    this.count, {
    super.key,
    this.color = K.label2,
    this.trailing,
  });

  final String text;
  final int count;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.feedback,
      curve: Motion.out,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Text(
                    text,
                    style: T.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  RollingText(
                    '$count',
                    style: T.caption.copyWith(
                      color: color.withValues(alpha: .7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (trailing != null) ...[const Spacer(), trailing!],
                ],
              ),
            ),
    );
  }
}
