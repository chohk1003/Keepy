import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/companion_header.dart';
import '../widgets/diff_sliver_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/fx.dart';
import '../widgets/quick_input_bar.dart';
import '../widgets/task_actions.dart';
import 'ocr_pages.dart';

/// 메인 화면 (UI설계서 02)
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final todo = s.todo;
    final done = s.done;
    final showTodo = s.filter != TaskFilter.done;
    final showDone = s.filter != TaskFilter.todo;
    // 분류: 지연 · 할 일 · 늦은 완료 · 완료 (각각 날짜순)
    const none = <Task>[];
    final overdue = showTodo ? s.ofStatus(TaskStatus.overdue) : none;
    final pending = showTodo ? s.ofStatus(TaskStatus.pending) : none;
    final late = showDone ? s.ofStatus(TaskStatus.late) : none;
    final doneOk = showDone ? s.ofStatus(TaskStatus.done) : none;
    final empty =
        overdue.isEmpty && pending.isEmpty && late.isEmpty && doneOk.isEmpty;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // 목록은 입력 바 위에서 끝남 (입력 바 아래로 비치지 않게)
        Padding(
          padding: EdgeInsets.only(bottom: bottom + QuickInputBar.height),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: CompanionHeader()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<TaskFilter>(
                      groupValue: s.filter,
                      onValueChanged: (v) {
                        if (v == null) return;
                        HapticFeedback.selectionClick();
                        s.setFilter(v);
                      },
                      children: {
                        TaskFilter.all: _Seg('전체', s.tasks.length),
                        TaskFilter.todo: _Seg('미완료', todo.length),
                        TaskFilter.done: _Seg('완료', done.length),
                      },
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader('지연', overdue.length, gradient: K.danger),
              ),
              DiffSliverList<Task>(
                items: overdue,
                idOf: (t) => t.id,
                itemBuilder: buildTaskTile,
              ),
              SliverToBoxAdapter(child: SectionHeader('할 일', pending.length)),
              DiffSliverList<Task>(
                items: pending,
                idOf: (t) => t.id,
                itemBuilder: buildTaskTile,
              ),
              SliverToBoxAdapter(
                child: SectionHeader('늦은 완료', late.length, gradient: K.late),
              ),
              DiffSliverList<Task>(
                items: late,
                idOf: (t) => t.id,
                itemBuilder: buildTaskTile,
              ),
              SliverToBoxAdapter(
                child: SectionHeader('완료', doneOk.length, gradient: K.success),
              ),
              DiffSliverList<Task>(
                items: doneOk,
                idOf: (t) => t.id,
                itemBuilder: buildTaskTile,
              ),
              if (empty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: EdgeFade.zone),
                    child: Center(
                      child: EmptyState(
                        title: s.tasks.isEmpty ? '할 일 없음' : '해당 없음',
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: EdgeFade.zone + 8),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: QuickInputBar(
            onSubmit: (title, tags) => s.add(title, tags: tags),
            onCamera: () => openCapture(context),
          ),
        ),
      ],
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: T.subhead.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          RollingText('$count', style: T.subhead.copyWith(color: K.label2)),
        ],
      ),
    );
  }
}
