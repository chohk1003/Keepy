import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
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
    final empty = overdue.isEmpty && pending.isEmpty && late.isEmpty && doneOk.isEmpty;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // 목록은 입력 바 위에서 끝남 (입력 바 아래로 비치지 않게)
        Padding(
          padding: EdgeInsets.only(bottom: bottom + QuickInputBar.height),
          child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: GradientText('Keepy', style: T.largeTitle),
              middle: Text('Keepy', style: T.headline),
              alwaysShowMiddle: false,
              backgroundColor: K.bg.withValues(alpha: 0.82),
              border: null,
              transitionBetweenRoutes: false,
            ),
            SliverToBoxAdapter(child: _TodayCard(state: s)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
            DiffSliverList<Task>(items: overdue, idOf: (t) => t.id, itemBuilder: buildTaskTile),
            SliverToBoxAdapter(child: SectionHeader('할 일', pending.length)),
            DiffSliverList<Task>(items: pending, idOf: (t) => t.id, itemBuilder: buildTaskTile),
            SliverToBoxAdapter(
              child: SectionHeader('늦은 완료', late.length, gradient: K.late),
            ),
            DiffSliverList<Task>(items: late, idOf: (t) => t.id, itemBuilder: buildTaskTile),
            SliverToBoxAdapter(
              child: SectionHeader('완료', doneOk.length, gradient: K.success),
            ),
            DiffSliverList<Task>(items: doneOk, idOf: (t) => t.id, itemBuilder: buildTaskTile),
            if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: EdgeFade.zone),
                  child: Center(
                    child: EmptyState(title: s.tasks.isEmpty ? '할 일 없음' : '해당 없음'),
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

/// 오늘 진행 카드 — 흐르는 그라데이션 + 링
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final today = dayOf(DateTime.now());
    final list = state.onDay(today);
    final doneN = list.where((t) => t.done).length;
    final left = list.length - doneN;
    final r = list.isEmpty ? 0.0 : doneN / list.length;
    final overdue = state.ofStatus(TaskStatus.overdue).length;
    const white = Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: LivingGradient(
        colors: const [Color(0xFF0A84FF), Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      longKo(today),
                      style: T.footnote.copyWith(color: white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RollingText(
                          '$left',
                          style: T.largeTitle.copyWith(color: white, fontSize: 40, height: 1),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '남음',
                            style: T.headline.copyWith(color: white.withValues(alpha: 0.9)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(icon: CupertinoIcons.checkmark_alt, text: '완료 $doneN'),
                        if (overdue > 0)
                          _Chip(icon: CupertinoIcons.exclamationmark, text: '지연 $overdue'),
                      ],
                    ),
                  ],
                ),
              ),
              ProgressRing(
                value: r,
                size: 84,
                stroke: 10,
                colors: const [Colors.white, Color(0xFFE0E7FF), Colors.white],
                track: white.withValues(alpha: 0.25),
                child: RollingText(
                  '${(r * 100).round()}%',
                  style: T.headline.copyWith(color: white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: T.caption.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
