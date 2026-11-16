import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'fx.dart';

/// 날짜 화면 상단 캘린더 (UI설계서 03-1, CST-01 상단 1/4)
/// - 좌우로 밀면 주 단위로 스냅 이동
/// - 점: 남은 태스크 / 체크: 전건 완료 / 그라데이션 원: 선택 날짜
class WeekCalendar extends StatefulWidget {
  const WeekCalendar({super.key});

  @override
  State<WeekCalendar> createState() => _WeekCalendarState();
}

class _WeekCalendarState extends State<WeekCalendar> {
  static const _origin = 10000;
  PageController? _pages;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _sync(int offset) {
    final p = _pages;
    if (p == null || !p.hasClients) return;
    final target = _origin + offset;
    if ((p.page ?? target.toDouble()).round() != target) {
      p.animateToPage(target, duration: Motion.med, curve: Motion.out);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    _pages ??= PageController(initialPage: _origin + s.weekOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(s.weekOffset);
    });

    final today = dayOf(DateTime.now());
    final anchor = addDays(weekStart(today), s.weekOffset * 7);
    final top = MediaQuery.paddingOf(context).top;
    final sel = s.selectedDay;

    return Container(
      decoration: const BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: K.shadow,
      ),
      padding: EdgeInsets.fromLTRB(10, top + 2, 10, 10),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 8),
                GradientText('${anchor.month}월', style: T.title2),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${anchor.year}', style: T.footnote),
                ),
                const Spacer(),
                _Chevron(
                  icon: CupertinoIcons.chevron_left,
                  onTap: () => s.setWeekOffset(s.weekOffset - 1),
                ),
                _Chevron(
                  icon: CupertinoIcons.chevron_right,
                  onTap: () => s.setWeekOffset(s.weekOffset + 1),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekHeaderKo[i],
                      style: T.caption.copyWith(
                        fontSize: 11,
                        color: i == 0
                            ? K.red
                            : i == 6
                                ? K.blue
                                : K.label3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              onPageChanged: (p) {
                HapticFeedback.selectionClick();
                s.setWeekOffset(p - _origin);
              },
              itemBuilder: (context, p) {
                final offset = p - _origin;
                final first = addDays(
                  addDays(weekStart(today), offset * 7),
                  -(s.thisWeekRow - 1) * 7,
                );
                return Column(
                  children: [
                    for (var r = 0; r < s.calendarRows; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: _cell(s, addDays(first, r * 7 + i), sel, today),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 22, child: RateView(state: s)),
        ],
      ),
    );
  }

  Widget _cell(AppState s, DateTime d, DateTime sel, DateTime today) {
    return _DayCell(
      date: d,
      selected: sameDay(d, sel),
      today: sameDay(d, today),
      counts: s.dayCounts(d),
      onTap: () {
        HapticFeedback.selectionClick();
        s.selectDay(d, syncWeek: false);
      },
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.8,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: K.blue),
      ),
    );
  }
}

/// 날짜 칸 (둥근 네모)
/// - 선택: 그라데이션
/// - 할 일 있음: 파란색 채움 (할 일이 많을수록 진하게)
/// - 전부 완료: 초록색 채움 (깃허브 잔디처럼 완료가 많을수록 진하게)
/// - 오늘: 그라데이션 숫자 + 아래 짧은 막대
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final ({int done, int total}) counts;
  final VoidCallback onTap;

  static const _greens = [
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
  ];
  static const _blues = [
    Color(0xFFDCE7FF),
    Color(0xFFB4CCFF),
    Color(0xFF7FA6FF),
    Color(0xFF4F7FF5),
  ];

  @override
  Widget build(BuildContext context) {
    final total = counts.total;
    final allDone = total > 0 && counts.done == total;
    final level = math.min(allDone ? counts.done : total, 4) - 1; // 0~3
    final Color? fill = selected || total == 0
        ? null
        : (allDone ? _greens : _blues)[level];
    final darkFill = fill != null && (allDone ? level >= 1 : level >= 2);

    final wd = date.weekday % 7; // 0: 일
    final fg = selected || darkFill
        ? Colors.white
        : wd == 0
            ? K.red
            : wd == 6
                ? K.blue
                : K.label;

    return Pressable(
      onTap: onTap,
      haptic: false,
      scale: 0.85,
      child: LayoutBuilder(
        builder: (context, box) {
          final size =
              (math.min(box.maxWidth, box.maxHeight) - 4).clamp(18.0, 46.0).toDouble();
          return Center(
            child: AnimatedContainer(
              duration: Motion.med,
              curve: Motion.out,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.3),
                gradient: selected ? K.brand : null,
                color: selected ? null : (fill ?? Colors.transparent),
                boxShadow: selected ? K.glow(K.indigo, a: 0.4, blur: 12) : const [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 오늘: 그라데이션 숫자 + 아래 짧은 막대
                  if (today && !selected && !darkFill)
                    GradientText('${date.day}', style: _numStyle(size, true))
                  else
                    Text('${date.day}', style: _numStyle(size, today).copyWith(color: fg)),
                  if (today)
                    Positioned(
                      bottom: size * 0.13,
                      child: Container(
                        width: size * 0.34,
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: selected || darkFill ? null : K.brand,
                          color: selected || darkFill ? Colors.white : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

TextStyle _numStyle(double size, bool bold) => TextStyle(
      fontFamily: K.font,
      fontSize: size * 0.38,
      height: 1,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
    );

/// 선택 날짜 완료율: 바 / 원형 / 그래프(이번 주 7일)
class RateView extends StatelessWidget {
  const RateView({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final list = s.onDay(s.selectedDay);
    final done = list.where((t) => t.done).length;
    final r = list.isEmpty ? 0.0 : done / list.length;
    final label = list.isEmpty ? '일정 없음' : '$done/${list.length} · ${(r * 100).round()}%';

    final Widget visual = switch (s.rateStyle) {
      RateStyle.bar => Expanded(child: _Bar(value: r)),
      RateStyle.ring => ProgressRing(value: r, size: 20, stroke: 4),
      RateStyle.graph => Expanded(child: _WeekGraph(state: s)),
    };

    return Row(
      children: [
        const SizedBox(width: 8),
        visual,
        if (s.rateStyle == RateStyle.ring) const Spacer(),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: Motion.fast,
          child: Text(label, key: ValueKey(label), style: T.caption),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(color: K.fill2, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value),
        duration: const Duration(milliseconds: 650),
        curve: Motion.spring,
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: v.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: K.brand,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekGraph extends StatelessWidget {
  const _WeekGraph({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final start = weekStart(state.selectedDay);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final d = addDays(start, i);
              final v = state.dayRate(d);
              final on = sameDay(d, state.selectedDay);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: v),
                  duration: const Duration(milliseconds: 600),
                  curve: Motion.spring,
                  builder: (context, x, _) => Container(
                    height: 4 + 16 * x.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: on ? K.brand : null,
                      color: on ? null : K.indigo.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
