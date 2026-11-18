import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../state/task_store.dart';
import 'basics.dart';

/// 상단 캘린더 (UI 설계서 03-1 / FR-08 / prompts_log #8).
///
/// - 칸은 모서리가 둥근 네모.
/// - 할 일이 있는 날은 점 대신 칸 전체를 색으로 채우고,
///   깃허브 잔디처럼 완료한 개수가 많을수록 초록이 진해진다.
/// - 오늘은 검은 테두리 대신 그라데이션 숫자 + 밑줄.
/// - 행 수 {1,2,3,4} 와 이번 주의 위치는 설정에서 고른다.
/// - 제목(2026년 11월)을 누르면 한 달 전체가 펼쳐진다 (v0.3).
class CalendarPanel extends StatelessWidget {
  const CalendarPanel({
    super.key,
    required this.firstWeekStart,
    required this.rows,
    required this.selected,
    required this.today,
    required this.statOf,
    required this.onSelect,
    required this.onShiftWeeks,
    required this.month,
    this.expanded = false,
    this.onTitleTap,
  });

  final DateTime firstWeekStart;
  final int rows;
  final DateTime selected;
  final DateTime today;
  final DayStat Function(DateTime day) statOf;
  final ValueChanged<DateTime> onSelect;

  /// < > 버튼: 접힘 = 주 단위, 펼침 = 달 단위 이동.
  final ValueChanged<int> onShiftWeeks;

  /// 제목에 보일 달 (펼친 상태에서는 이 달 밖의 날짜를 흐리게).
  final DateTime month;

  /// 한 달 전체를 펼친 상태인지 (v0.3 요청 #5).
  final bool expanded;

  /// '2026년 11월' 제목을 누르면 펼치기/접기.
  final VoidCallback? onTitleTap;

  static int heatLevel(DayStat s) {
    if (s.total == 0) return -1;
    if (s.done == 0) return 0;
    if (s.done == 1) return 1;
    if (s.done == 2) return 2;
    if (s.done == 3) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 34,
          child: Row(
            children: <Widget>[
              GestureDetector(
                key: const Key('month-title'),
                behavior: HitTestBehavior.opaque,
                onTap: onTitleTap,
                child: Row(
                  children: <Widget>[
                    Text(formatYearMonth(month), style: KeepyText.title),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: KeepyMotion.normal,
                      curve: KeepyMotion.settle,
                      child: const Icon(CupertinoIcons.chevron_down, size: 14, color: KeepyColors.blue),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _ChevronButton(icon: CupertinoIcons.chevron_left, onTap: () => onShiftWeeks(-1)),
              _ChevronButton(icon: CupertinoIcons.chevron_right, onTap: () => onShiftWeeks(1)),
            ],
          ),
        ),
        SizedBox(
          height: 18,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: i == 6 ? const Color(0xFFFF6B6B) : KeepyColors.secondaryLabel,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // 위 1/4 안에 행 수와 관계없이 들어가도록 칸 높이를 맞춘다 (최대 46).
              final rowHeight = (c.maxHeight / rows).clamp(0.0, 44.0);
              return Column(
                children: <Widget>[
                  for (var r = 0; r < rows; r++)
                    SizedBox(
                      height: rowHeight,
                      child: Row(
                        children: <Widget>[
                          for (var col = 0; col < 7; col++)
                            Expanded(child: _buildCell(addDays(firstWeekStart, r * 7 + col))),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCell(DateTime day) {
    final stat = statOf(day);
    final level = heatLevel(stat);
    final isSelected = isSameDay(day, selected);
    final isToday = isSameDay(day, today);
    final dim = day.month != month.month;

    final Color? fill = level < 0 ? null : KeepyColors.heat[level];
    final darkFill = level >= 3;
    final textColor = isSelected
        ? Colors.white
        : darkFill
            ? Colors.white
            : (dim ? KeepyColors.tertiaryLabel : KeepyColors.label);

    final number = isToday && !isSelected && !darkFill
        ? GradientText('${day.day}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))
        : Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
              color: textColor,
            ),
          );

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: GestureDetector(
        key: Key('day-${toDateKey(day)}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect(day);
        },
        child: AnimatedContainer(
          duration: KeepyMotion.fast,
          curve: KeepyMotion.settle,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: isSelected ? KeepyGradients.primary : null,
            color: isSelected ? null : fill,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                number,
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    width: 14,
                    height: 2.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: isSelected || darkFill ? null : KeepyGradients.primary,
                      color: isSelected || darkFill ? Colors.white : null,
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

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.85,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 18, color: KeepyColors.blue),
      ),
    );
  }
}
