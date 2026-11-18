import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../state/keepy_scope.dart';
import '../../state/sync_controller.dart';
import '../../state/task_store.dart';
import '../game/stair_game_page.dart';
import '../widgets/basics.dart';
import '../widgets/task_actions.dart';
import 'account_sheet.dart';

enum TaskFilter { all, open, done }

/// 메인 화면 (UI 설계서 02 / FR-02~06).
///
/// 날짜 지정 여부와 관계없이 모든 할 일을 보여 주는 가운데 화면.
/// 지연 → 해야 할 일 → 완료한 일 순으로 나눠 보여 준다.
/// v0.3: '편집'을 누르면 손잡이로 끌어서 구역 안 순서를 바꿀 수 있다.
class MainPage extends StatefulWidget {
  const MainPage({
    super.key,
    required this.actions,
    required this.bottomInset,
    this.onEditingChanged,
    this.onOpenToday,
  });

  final TaskActions actions;

  /// 하단 입력 바·사라짐 영역만큼 리스트 끝에 둘 여백.
  final double bottomInset;

  /// 편집 모드가 바뀔 때 (셸이 열린 스와이프를 닫는 데 씀).
  final ValueChanged<bool>? onEditingChanged;

  /// 오늘 요약 카드의 '오늘' 을 누르면 날짜 화면의 오늘로 (v0.5).
  final VoidCallback? onOpenToday;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with AutomaticKeepAliveClientMixin {
  TaskFilter _filter = TaskFilter.all;
  bool _editing = false;
  bool _doneCollapsed = false; // 완료한 일 접기 (v0.5)

  @override
  bool get wantKeepAlive => true;

  void _toggleEditing() {
    HapticFeedback.selectionClick();
    setState(() => _editing = !_editing);
    widget.onEditingChanged?.call(_editing);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scope = KeepyScope.of(context);
    final store = scope.tasks;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[store, scope.settings]),
        builder: (context, _) {
          final settings = scope.settings.settings;
          final delayed = store.delayedTasks;
          final todo = store.todoTasks;
          final done = store.doneTasks;

          final header = <Widget>[
            _Header(
              showGame: settings.miniGameEnabled,
              onGame: () => StairGamePage.open(context),
              sync: scope.sync,
            ),
            const SizedBox(height: 12),
            Text(formatFull(store.today), style: KeepyText.caption),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                Text('모든 할 일', style: KeepyText.largeTitle),
                const SizedBox(width: 8),
                CountBadge(store.totalCount),
                const Spacer(),
                if (store.totalCount > 0)
                  PressScale(
                    key: const Key('edit-toggle'),
                    onTap: _toggleEditing,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: _editing ? KeepyGradients.primary : null,
                        color: _editing ? null : KeepyColors.skyTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _editing ? '완료' : '편집',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _editing ? Colors.white : KeepyColors.blue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (store.totalCount > 0) ...<Widget>[
              const SizedBox(height: 12),
              // 오늘 요약 (v0.5): 눌러서 바로 이동
              _TodaySummary(
                dueToday: store.dueTodayOpenCount,
                delayed: store.delayedCount,
                doneToday: store.doneTodayCount,
                onToday: widget.onOpenToday,
                onDelayed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filter = TaskFilter.open);
                },
                onDone: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _filter = TaskFilter.done;
                    _doneCollapsed = false;
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            _FilterTabs(
              filter: _filter,
              counts: (store.totalCount, store.openCount, store.doneCount),
              onChanged: (f) {
                HapticFeedback.selectionClick();
                setState(() => _filter = f);
              },
            ),
            if (_editing)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('오른쪽 손잡이(≡)를 끌어 순서를 바꿔요', style: KeepyText.footnote),
              ),
          ];

          final slivers = <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(delegate: SliverChildListDelegate(header)),
            ),
            ..._sections(store, delayed, todo, done),
            SliverToBoxAdapter(child: SizedBox(height: widget.bottomInset)),
          ];

          return CustomScrollView(
            key: const PageStorageKey<String>('main-list'),
            slivers: slivers,
          );
        },
      ),
    );
  }

  List<Widget> _sections(TaskStore store, List<Task> delayed, List<Task> todo, List<Task> done) {
    Widget pad(Widget sliver) => SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: sliver);
    Widget box(Widget child) => pad(SliverToBoxAdapter(child: child));

    if (store.totalCount == 0) return <Widget>[box(const EmptyState())];

    final showOpen = _filter != TaskFilter.done;
    final showDone = _filter != TaskFilter.open;
    final out = <Widget>[];

    void section(String title, List<Task> tasks, {Color? color}) {
      if (tasks.isEmpty) return;
      out.add(box(color == null
          ? SectionHeader(title, count: tasks.length)
          : SectionHeader(title, count: tasks.length, color: color)));
      out.add(pad(_list(store, tasks)));
    }

    if (showOpen) section('지연', delayed, color: KeepyColors.orange);
    if (showOpen) section('해야 할 일', todo);
    if (showDone && done.isNotEmpty) {
      // 완료한 일: 접기·펼치기 + 비우기 (v0.5)
      out.add(box(_DoneHeader(
        count: done.length,
        collapsed: _doneCollapsed && _filter != TaskFilter.done,
        onToggle: _filter == TaskFilter.done
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() => _doneCollapsed = !_doneCollapsed);
              },
        onClear: () => _confirmClearDone(done.length),
      )));
      if (!(_doneCollapsed && _filter != TaskFilter.done)) out.add(pad(_list(store, done)));
    }

    if (out.isEmpty) {
      return <Widget>[
        box(_filter == TaskFilter.done
            ? const EmptyState(title: '아직 완료한 일이 없어요', message: '체크박스를 누르면 여기로 옮겨져요')
            : const EmptyState(title: '남은 할 일이 없어요', message: '모두 끝냈어요!\n새로운 할 일은 아래에서 추가해 보세요')),
      ];
    }
    return out;
  }

  void _confirmClearDone(int count) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('완료한 일 $count개를 지울까요?'),
        content: const Text('지운 직후 알림에서 \'취소\'로 되돌릴 수 있어요.'),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              widget.actions.clearDone();
            },
            child: const Text('비우기'),
          ),
        ],
      ),
    );
  }

  /// 한 구역의 할 일 목록. 편집 모드면 끌어서 순서를 바꿀 수 있다.
  Widget _list(TaskStore store, List<Task> tasks) {
    if (!_editing) {
      return SliverList(
        delegate: SliverChildListDelegate(<Widget>[for (final t in tasks) widget.actions.tile(t)]),
      );
    }
    final ids = <String>[for (final t in tasks) t.id];
    return SliverReorderableList(
      itemCount: tasks.length,
      itemBuilder: (context, i) => widget.actions.tile(tasks[i], editing: true, index: i),
      onReorder: (oldIndex, newIndex) {
        HapticFeedback.selectionClick();
        store.reorder(ids, oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
          child: Material(color: Colors.transparent, child: child),
        ),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showGame, required this.onGame, required this.sync});
  final bool showGame;
  final VoidCallback onGame;
  final SyncController sync;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          const KeepyLogo(),
          const Spacer(),
          // MP3: 로그인했을 때만 동기화 상태 아이콘 (누르면 계정 · 동기화).
          // 동기화 상태가 바뀌어도 목록 전체가 아니라 이 배지만 다시 그린다.
          ListenableBuilder(
            listenable: sync,
            builder: (context, _) => !sync.isSignedIn
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(right: showGame ? 8 : 0),
                    child: _SyncBadge(sync: sync),
                  ),
          ),
          // 미니게임 바로가기 (설정에서 켰을 때만). v0.4: 옆의 계정 'K' 동그라미는 쓰임이 없어 뺐다.
          if (showGame)
            PressScale(
              key: const Key('game-shortcut'),
              onTap: onGame,
              scale: 0.88,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: KeepyColors.skyTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: StairsIcon(size: 18)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 상태 탭: 전체 / 미완료 / 완료 (UI 설계서 02-1 / FR-05).
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.filter, required this.counts, required this.onChanged});

  final TaskFilter filter;
  final (int, int, int) counts;
  final ValueChanged<TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <(TaskFilter, String, int)>[
      (TaskFilter.all, '전체', counts.$1),
      (TaskFilter.open, '미완료', counts.$2),
      (TaskFilter.done, '완료', counts.$3),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KeepyColors.separator, width: 0.8)),
      ),
      child: Row(
        children: <Widget>[
          for (final (f, label, count) in items)
            GestureDetector(
              key: Key('filter-${f.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(f),
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 4),
                    f == filter
                        ? GradientText('$label $count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))
                        : Text(
                            '$label $count',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: KeepyColors.secondaryLabel,
                            ),
                          ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: KeepyMotion.fast,
                      curve: KeepyMotion.settle,
                      height: 2.5,
                      width: f == filter ? 28 : 0,
                      decoration: BoxDecoration(
                        gradient: KeepyGradients.primary,
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

/// 오늘 요약 카드 (v0.5): 오늘 할 일 / 지연 / 오늘 완료. 누르면 해당 목록으로.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.dueToday,
    required this.delayed,
    required this.doneToday,
    required this.onToday,
    required this.onDelayed,
    required this.onDone,
  });

  final int dueToday;
  final int delayed;
  final int doneToday;
  final VoidCallback? onToday;
  final VoidCallback onDelayed;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int value, Color color, VoidCallback? onTap, Key key) => Expanded(
          child: PressScale(
            key: key,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(label, style: KeepyText.footnote),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: value == 0 ? KeepyColors.tertiaryLabel : color),
                  ),
                ],
              ),
            ),
          ),
        );
    Widget divider() => Container(width: 0.6, height: 34, color: KeepyColors.separator);

    return KeepyCard(
      child: Row(
        children: <Widget>[
          cell('오늘 할 일', dueToday, KeepyColors.blue, onToday, const Key('sum-today')),
          divider(),
          cell('지연', delayed, KeepyColors.orange, onDelayed, const Key('sum-delayed')),
          divider(),
          cell('오늘 완료', doneToday, KeepyColors.green, onDone, const Key('sum-done')),
        ],
      ),
    );
  }
}

/// '완료한 일' 머리: 누르면 접기·펼치기, 오른쪽 '비우기' (v0.5).
class _DoneHeader extends StatelessWidget {
  const _DoneHeader({required this.count, required this.collapsed, required this.onToggle, required this.onClear});
  final int count;
  final bool collapsed;
  final VoidCallback? onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
      child: Row(
        children: <Widget>[
          GestureDetector(
            key: const Key('done-toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Row(
              children: <Widget>[
                Text('완료한 일', style: KeepyText.caption.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('$count', style: KeepyText.caption.copyWith(color: KeepyColors.secondaryLabel.withValues(alpha: 0.7))),
                if (onToggle != null) ...<Widget>[
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: KeepyMotion.fast,
                    child: Icon(CupertinoIcons.chevron_down, size: 12, color: KeepyColors.secondaryLabel),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          PressScale(
            key: const Key('done-clear'),
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('비우기', style: KeepyText.caption.copyWith(color: KeepyColors.red, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 메인 머리의 동기화 상태 (MP3). 맞춰짐 ✓ / 동기화 중 ↻ / 올릴 변경 ↑ / 오프라인 / 오류.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.sync});
  final SyncController sync;

  @override
  Widget build(BuildContext context) {
    final pending = sync.pendingCount;
    final (IconData icon, Color color) = switch (sync.phase) {
      SyncPhase.syncing => (CupertinoIcons.arrow_2_circlepath, KeepyColors.blue),
      SyncPhase.offline => (CupertinoIcons.wifi_slash, KeepyColors.orange),
      SyncPhase.error => (CupertinoIcons.exclamationmark_circle, KeepyColors.red),
      _ => pending > 0
          ? (CupertinoIcons.arrow_up, KeepyColors.orange)
          : (CupertinoIcons.checkmark_alt, KeepyColors.green),
    };
    return Semantics(
      label: '동기화: ${sync.statusText}',
      button: true,
      child: PressScale(
        key: const Key('sync-status'),
        onTap: () => showAccountSheet(context),
        scale: 0.88,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: KeepyColors.skyTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(CupertinoIcons.cloud, size: 17, color: KeepyColors.blue),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: KeepyMotion.fast,
                child: Icon(icon, key: ValueKey<IconData>(icon), size: 13, color: color),
              ),
              if (pending > 0 && sync.phase != SyncPhase.syncing) ...<Widget>[
                const SizedBox(width: 2),
                Text('$pending', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
