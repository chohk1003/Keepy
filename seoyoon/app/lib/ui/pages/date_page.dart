import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../state/keepy_scope.dart';
import '../../state/task_store.dart';
import '../widgets/basics.dart';
import '../widgets/calendar_panel.dart';
import '../widgets/completion_indicator.dart';
import '../widgets/task_actions.dart';

/// 날짜 화면 (UI 설계서 03 / FR-08 / CST-01 / prompts_log #7, #8).
///
/// - 위 1/4: 캘린더 (고정). 아래 3/4: 고른 날의 할 일 (스크롤).
/// - 이전날·다음날 버튼은 없다. 좌우 조작은 탭 전환과 겹치기 때문에,
///   목록 끝에서 임계값을 넘겨 위·아래로 끌면 '할 일이 있는 날'로만 이동한다.
class DatePage extends StatefulWidget {
  const DatePage({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.actions,
    required this.bottomInset,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final TaskActions actions;
  final double bottomInset;

  /// 이만큼 넘겨 끌고 놓으면 날짜가 넘어간다.
  static const pullThreshold = 70.0;

  @override
  State<DatePage> createState() => _DatePageState();
}

class _DatePageState extends State<DatePage> with AutomaticKeepAliveClientMixin {
  int _weekOffset = 0;
  bool _expanded = false; // 한 달 전체 펼침 (v0.3 요청 #5)
  DateTime? _month; // 펼친 상태에서 보는 달 (1일)
  double _pull = 0; // 음수: 위에서 끌어내림(이전 날), 양수: 아래에서 끌어올림(다음 날)
  double _dragPull = 0;
  bool _userDragging = false;
  int _direction = 1; // 날짜 전환 애니메이션 방향

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(DatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(oldWidget.selected, widget.selected)) {
      _direction = widget.selected.isAfter(oldWidget.selected) ? 1 : -1;
      _ensureVisible(widget.selected);
      if (_expanded) _month = DateTime(widget.selected.year, widget.selected.month);
    }
  }

  DateTime _firstWeekStart(DateTime today, int weekRow) =>
      addDays(startOfWeek(today), 7 * (_weekOffset - (weekRow - 1)));

  /// 고른 날짜가 캘린더 밖이면 보이도록 주를 옮긴다.
  void _ensureVisible(DateTime day) {
    final scope = KeepyScope.of(context);
    final settings = scope.settings.settings;
    final today = scope.tasks.today;
    final first = _firstWeekStart(today, settings.effectiveWeekRow);
    final diffWeeks = (daysBetween(first, startOfWeek(day)) / 7).round();
    if (diffWeeks < 0) {
      _weekOffset += diffWeeks;
    } else if (diffWeeks >= settings.calendarRows) {
      _weekOffset += diffWeeks - settings.calendarRows + 1;
    }
  }

  void _goAdjacent(int direction) {
    final store = KeepyScope.of(context).tasks;
    final target = store.adjacentTaskDate(widget.selected, direction);
    if (target == null) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onSelect(target);
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      _month = DateTime(widget.selected.year, widget.selected.month);
    });
  }

  /// 한 달 보기: 그 달 1일이 있는 주의 월요일부터, 마지막 날이 있는 주까지.
  (DateTime first, int rows) _monthGrid(DateTime month) {
    final first = startOfWeek(DateTime(month.year, month.month, 1));
    final last = DateTime(month.year, month.month + 1, 0);
    final rows = (daysBetween(first, last) ~/ 7) + 1;
    return (first, rows);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final m = n.metrics;
    double over = 0;
    if (m.pixels < m.minScrollExtent) over = m.pixels - m.minScrollExtent;
    if (m.pixels > m.maxScrollExtent) over = m.pixels - m.maxScrollExtent;

    if (n is ScrollStartNotification && n.dragDetails != null) {
      _userDragging = true;
      _dragPull = 0;
    } else if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) {
        _userDragging = true;
        _dragPull = over;
      } else if (_userDragging) {
        // 손을 뗀 순간
        _userDragging = false;
        _release();
      }
    } else if (n is ScrollEndNotification && _userDragging) {
      _userDragging = false;
      _release();
    }
    if ((over - _pull).abs() > 0.5) setState(() => _pull = over);
    return false;
  }

  void _release() {
    final pull = _dragPull;
    _dragPull = 0;
    if (pull <= -DatePage.pullThreshold) {
      _goAdjacent(-1);
    } else if (pull >= DatePage.pullThreshold) {
      _goAdjacent(1);
    }
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
          final today = store.today;
          final month = _month ?? DateTime(widget.selected.year, widget.selected.month);
          final DateTime first;
          final int rows;
          if (_expanded) {
            final grid = _monthGrid(month);
            first = grid.$1;
            rows = grid.$2;
          } else {
            first = _firstWeekStart(today, settings.effectiveWeekRow);
            rows = settings.calendarRows;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // CST-01: 세로 화면 기준 위 1/4 은 캘린더로 고정.
              // 제목을 눌러 한 달을 펼치면 그만큼 아래 목록 영역이 줄어든다.
              final collapsed = constraints.maxHeight * 0.25;
              final full = math.min(constraints.maxHeight * 0.62, 34 + 18 + 2 + 10 + rows * 44.0);
              final calendarHeight = _expanded ? math.max(collapsed, full) : collapsed;
              return Column(
                children: <Widget>[
                  AnimatedContainer(
                    duration: KeepyMotion.page,
                    curve: KeepyMotion.settle,
                    height: calendarHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 10, 6),
                      child: CalendarPanel(
                        firstWeekStart: first,
                        rows: rows,
                        month: _expanded ? month : widget.selected,
                        expanded: _expanded,
                        onTitleTap: _toggleExpanded,
                        selected: widget.selected,
                        today: today,
                        statOf: store.statOn,
                        onSelect: widget.onSelect,
                        onShiftWeeks: (d) => setState(() {
                          if (_expanded) {
                            _month = DateTime(month.year, month.month + d);
                          } else {
                            _weekOffset += d;
                          }
                        }),
                      ),
                    ),
                  ),
                  Container(height: 0.6, color: KeepyColors.separator),
                  Expanded(child: _buildList(store, today, settings.completionStyle)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildList(TaskStore store, DateTime today, CompletionStyle completionStyle) {
    final day = widget.selected;
    final tasks = store.tasksOn(day);
    final stat = store.statOn(day);
    final weekStart = startOfWeek(day);
    final weekStats = <DayStat>[for (var i = 0; i < 7; i++) store.statOn(addDays(weekStart, i))];
    final prev = store.adjacentTaskDate(day, -1);
    final next = store.adjacentTaskDate(day, 1);

    final content = Column(
      key: ValueKey<String>(toDateKey(day)),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DayHeader(
          day: day,
          today: today,
          onToday: () {
            HapticFeedback.selectionClick();
            widget.onSelect(today);
          },
        ),
        const SizedBox(height: 14),
        KeepyCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: CompletionIndicator(
            style: completionStyle,
            stat: stat,
            weekStats: weekStats,
            selectedIndex: day.weekday - 1,
          ),
        ),
        SectionHeader(
          '태스크',
          count: tasks.length,
          trailing: Text('${stat.done}개 완료', style: KeepyText.footnote),
        ),
        if (tasks.isEmpty)
          const EmptyState(
            title: '이 날짜에 할 일이 없어요',
            message: '아래 입력창에 쓰면 이 날짜로 등록돼요\n목록을 위·아래로 끌면 일정이 있는 날로 이동해요',
          )
        else
          ...tasks.map(widget.actions.tile),
      ],
    );

    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomInset),
            children: <Widget>[
              AnimatedSwitcher(
                duration: KeepyMotion.normal,
                switchInCurve: KeepyMotion.settle,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  final incoming = child.key == content.key;
                  final dir = _direction.toDouble();
                  final begin = Offset(0, (incoming ? 0.06 : -0.06) * dir);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  );
                },
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[...previous, if (current != null) current],
                ),
                child: content,
              ),
            ],
          ),
        ),
        // 위에서 끌어내릴 때: 이전 일정 안내
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: _PullHint(
            progress: (-_pull / DatePage.pullThreshold).clamp(0.0, 1.0),
            up: true,
            label: prev == null ? '이전 일정 없음' : '${relativeDayLabel(prev, today)} 일정으로',
            enabled: prev != null,
          ),
        ),
        // 아래에서 끌어올릴 때: 다음 일정 안내
        Positioned(
          bottom: widget.bottomInset - 56,
          left: 0,
          right: 0,
          child: _PullHint(
            progress: (_pull / DatePage.pullThreshold).clamp(0.0, 1.0),
            up: false,
            label: next == null ? '다음 일정 없음' : '${relativeDayLabel(next, today)} 일정으로',
            enabled: next != null,
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today, required this.onToday});
  final DateTime day;
  final DateTime today;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(day, today);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('선택한 날짜', style: KeepyText.caption),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(formatMonthDay(day), style: KeepyText.largeTitle.copyWith(fontSize: 27)),
                  const SizedBox(width: 6),
                  Text('${weekdayKo(day)}요일', style: KeepyText.caption.copyWith(fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: KeepyMotion.fast,
          child: isToday
              ? const Padding(
                  key: ValueKey<String>('is-today'),
                  padding: EdgeInsets.only(bottom: 6),
                  child: Pill('오늘'),
                )
              : PressScale(
                  key: const ValueKey<String>('go-today'),
                  onTap: onToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: KeepyGradients.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(CupertinoIcons.arrow_uturn_left, size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text('오늘', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PullHint extends StatelessWidget {
  const _PullHint({required this.progress, required this.up, required this.label, required this.enabled});
  final double progress;
  final bool up;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.02) return const SizedBox.shrink();
    final ready = progress >= 1 && enabled;
    return IgnorePointer(
      child: Opacity(
        opacity: progress,
        child: Center(
          child: AnimatedContainer(
            duration: KeepyMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: ready ? KeepyGradients.primary : null,
              color: ready ? null : KeepyColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  up ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
                  size: 13,
                  color: ready ? Colors.white : KeepyColors.secondaryLabel,
                ),
                const SizedBox(width: 4),
                Text(
                  ready ? '놓으면 이동' : label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ready ? Colors.white : KeepyColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
