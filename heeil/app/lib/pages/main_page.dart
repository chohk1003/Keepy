import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/companion_header.dart';
import '../widgets/diff_sliver_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/fx.dart';
import '../widgets/quick_input_bar.dart';
import '../widgets/task_actions.dart';
import 'ocr_pages.dart';

/// 메인 화면 (UI설계서 02) — 레이아웃은 서윤님 구현을 따른다.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  /// '완료' 섹션 접기 (서윤님 구현의 완료한 일 머리)
  bool _doneOpen = true;

  void _clearDone(AppState s) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('완료한 일 비우기'),
        content: const Text('목록에서만 지워요. 기록과 보상은 그대로예요.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            key: const Key('clear-done-confirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('비우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final snapshot = s.clearDone();
    if (snapshot.isEmpty) return;
    showToast(
      context,
      '${snapshot.length}개 비움',
      icon: CupertinoIcons.trash_fill,
      colors: K.deleteColors,
      life: undoToastLife,
      undo: () => s.restoreAll(snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
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
              SliverToBoxAdapter(child: _TodaySummary(state: s)),
              SliverToBoxAdapter(child: _FilterTabs(state: s)),
              SliverToBoxAdapter(
                child: SectionHeader('지연', overdue.length, color: K.orange),
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
                child: SectionHeader('늦은 완료', late.length, color: K.lateInk),
              ),
              DiffSliverList<Task>(
                items: late,
                idOf: (t) => t.id,
                itemBuilder: buildTaskTile,
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  '완료',
                  doneOk.length,
                  trailing: Row(
                    children: [
                      GestureDetector(
                        key: const Key('done-collapse'),
                        onTap: () => setState(() => _doneOpen = !_doneOpen),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 13,
                          ),
                          child: AnimatedRotation(
                            turns: _doneOpen ? 0 : -0.25,
                            duration: Motion.feedback,
                            child: const Icon(
                              CupertinoIcons.chevron_down,
                              size: 13,
                              color: K.label2,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        key: const Key('done-clear'),
                        onTap: () => _clearDone(s),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 13, 2, 13),
                          child: Text(
                            '비우기',
                            style: T.caption.copyWith(
                              color: K.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DiffSliverList<Task>(
                items: _doneOpen ? doneOk : none,
                idOf: (t) => t.id,
                itemBuilder: buildTaskTile,
              ),
              if (empty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: EdgeFade.zone),
                    child: Center(
                      child: s.tasks.isEmpty
                          ? const EmptyState(
                              title: '등록된 할 일이 없어요',
                              message: '기억하고 싶은 일이 있나요?\n아래에서 첫 할 일을 추가해 보세요',
                            )
                          : EmptyState(
                              title: s.filter == TaskFilter.done
                                  ? '아직 완료한 일이 없어요'
                                  : '남은 할 일이 없어요',
                              message: s.filter == TaskFilter.done
                                  ? '네모를 누르면 여기로 옮겨져요'
                                  : '모두 끝냈어요!',
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

/// 오늘 요약 — 오늘 할 일 · 지연 · 오늘 완료 (서윤님 `_TodaySummary`)
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.tasks.isEmpty) return const SizedBox.shrink();
    final today = dayOf(state.now);
    final todo = state.tasks
        .where((t) => !t.done && sameDay(t.due, today))
        .length;
    final overdue = state.ofStatus(TaskStatus.overdue).length;
    final done = state.tasks
        .where((t) => t.done && sameDay(t.credit?.at ?? t.doneAt, today))
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: K.card,
          borderRadius: BorderRadius.circular(K.radiusCard),
          border: Border.all(color: K.hairline, width: 0.8),
          boxShadow: K.cardShadow(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _Cell(
              key: const Key('summary-today'),
              label: '오늘 할 일',
              count: todo,
              color: K.blue,
              onTap: () => state.setFilter(TaskFilter.todo),
            ),
            const _Divider(),
            _Cell(
              key: const Key('summary-overdue'),
              label: '지연',
              count: overdue,
              color: K.orange,
              onTap: () => state.setFilter(TaskFilter.todo),
            ),
            const _Divider(),
            _Cell(
              key: const Key('summary-done'),
              label: '오늘 완료',
              count: done,
              color: K.green,
              onTap: () => state.setFilter(TaskFilter.done),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 0.6, height: 34, color: K.separator);
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label $count개',
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: .94,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(label, style: T.caption),
              ],
            ),
            const SizedBox(height: 2),
            RollingText(
              '$count',
              style: T.title3.copyWith(
                fontWeight: FontWeight.w800,
                color: count == 0 ? K.label3 : K.label,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 전체 · 미완료 · 완료 — 선택한 탭에 그라데이션 밑줄 (서윤님 `_FilterTabs`)
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = {
      TaskFilter.all: ('전체', state.tasks.length),
      TaskFilter.todo: ('미완료', state.todo.length),
      TaskFilter.done: ('완료', state.done.length),
    };
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: K.separator, width: 0.8)),
      ),
      child: Row(
        children: [
          for (final entry in items.entries)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                key: ValueKey('filter-${entry.key.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (state.filter == entry.key) return;
                  HapticFeedback.selectionClick();
                  state.setFilter(entry.key);
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Text(
                            entry.value.$1,
                            style: T.subhead.copyWith(
                              fontWeight: FontWeight.w700,
                              color: state.filter == entry.key
                                  ? K.blue
                                  : K.label2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          RollingText(
                            '${entry.value.$2}',
                            style: T.caption.copyWith(
                              color: state.filter == entry.key
                                  ? K.blue
                                  : K.label3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: Motion.feedback,
                      curve: Motion.out,
                      height: 2.5,
                      width: state.filter == entry.key ? 28 : 0,
                      decoration: BoxDecoration(
                        gradient: K.brand,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
