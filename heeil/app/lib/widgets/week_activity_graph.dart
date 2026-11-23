import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/companion.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';

/// 한 주의 완료 기록을 활동 4분류로 쌓아 올린 막대그래프.
///
/// 막대 하나를 누르면 그 날로 넘어간다 ([onSelect]). 그래프 자체는 날짜를 바꿔도
/// 같은 주를 계속 보여 준다 — 주가 바뀔 때만 다시 그려진다.
class WeekActivityGraph extends StatelessWidget {
  const WeekActivityGraph({
    super.key,
    required this.state,
    required this.day,
    required this.onSelect,
    this.height = 76,
  });

  final AppState state;

  /// 지금 보고 있는 날 (이 날이 속한 주를 그린다)
  final DateTime day;
  final ValueChanged<DateTime> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final start = weekStart(day);
    final days = [for (var i = 0; i < 7; i++) addDays(start, i)];
    final counts = [for (final d in days) state.tagCreditsOn(d)];
    final totals = [for (final c in counts) c.values.fold(0, (a, b) => a + b)];
    final maximum = math.max(1, totals.fold(0, math.max));
    final today = dayOf(state.now);
    return SizedBox(
      key: const Key('week-activity-graph'),
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _Column(
                day: days[i],
                counts: counts[i],
                total: totals[i],
                maximum: maximum,
                selected: sameDay(days[i], day),
                today: sameDay(days[i], today),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(days[i]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.day,
    required this.counts,
    required this.total,
    required this.maximum,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final Map<TaskTag?, int> counts;
  final int total;
  final int maximum;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = weekdayKo[day.weekday - 1];
    return Semantics(
      label: '${day.month}월 ${day.day}일 완료 $total개',
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('week-bar-${dayKey(day)}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                total == 0 ? '' : '$total',
                style: T.caption.copyWith(
                  fontSize: 10,
                  color: selected ? K.blue : K.label2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final full = box.maxHeight;
                    final bar = total == 0
                        ? 3.0
                        : 3 + (full - 3) * total / maximum;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: Motion.chart,
                        curve: Motion.out,
                        // 폭을 주지 않으면 쌓인 막대가 0폭으로 줄어든다
                        width: double.infinity,
                        height: bar,
                        decoration: BoxDecoration(
                          color: total == 0 ? K.fill : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: total == 0
                            ? null
                            : Column(
                                // stretch 가 없으면 자식이 없는 ColoredBox 가 0폭이 된다
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 아래에서부터 태그 순서대로 쌓고, 미지정은 맨 위
                                  for (final tag in <TaskTag?>[
                                    null,
                                    ...TaskTag.values.reversed,
                                  ])
                                    if ((counts[tag] ?? 0) > 0)
                                      Expanded(
                                        flex: counts[tag]!,
                                        child: ColoredBox(
                                          color: tag?.color ?? K.label3,
                                        ),
                                      ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? K.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label,
                  style: T.caption.copyWith(
                    fontSize: 10,
                    fontWeight: today ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : K.label2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
