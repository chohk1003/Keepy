import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import 'basics.dart';

/// 할 일 수정 시트의 간편 날짜 선택 (v0.4 요청 2).
///
/// 연·월·일을 하나씩 돌리는 대신, 자주 쓰는 날을 한 번에 고르는 칩과
/// 한 달 달력에서 날짜를 한 번 눌러 고르는 방식.
class QuickDatePicker extends StatefulWidget {
  const QuickDatePicker({
    super.key,
    required this.today,
    required this.selected,
    required this.onChanged,
  });

  final DateTime today;
  final DateTime? selected;

  /// null = 기한 없음.
  final ValueChanged<DateTime?> onChanged;

  @override
  State<QuickDatePicker> createState() => _QuickDatePickerState();
}

class _QuickDatePickerState extends State<QuickDatePicker> {
  late DateTime _month = DateTime((widget.selected ?? widget.today).year, (widget.selected ?? widget.today).month);

  void _pick(DateTime? d) {
    HapticFeedback.selectionClick();
    if (d != null) setState(() => _month = DateTime(d.year, d.month));
    widget.onChanged(d == null ? null : dateOnly(d));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.today;
    // 다음 주 월요일
    final nextMonday = addDays(startOfWeek(t), 7);
    final quick = <(String, DateTime?)>[
      ('오늘', t),
      ('내일', addDays(t, 1)),
      ('모레', addDays(t, 2)),
      ('다음 주', nextMonday),
      ('없음', null),
    ];
    final first = startOfWeek(_month);
    final last = DateTime(_month.year, _month.month + 1, 0);
    final rows = (daysBetween(first, last) ~/ 7) + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: <Widget>[
          // 빠른 선택 칩
          Row(
            children: <Widget>[
              for (final (label, day) in quick)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _QuickChip(
                      label: label,
                      selected: day == null ? widget.selected == null : widget.selected != null && isSameDay(day, widget.selected!),
                      onTap: () => _pick(day),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // 달 이동
          Row(
            children: <Widget>[
              const SizedBox(width: 4),
              Text(formatYearMonth(_month), style: KeepyText.headline),
              const Spacer(),
              _Chevron(icon: CupertinoIcons.chevron_left, onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
              _Chevron(icon: CupertinoIcons.chevron_right, onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
            ],
          ),
          Row(
            children: <Widget>[
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: i == 6 ? const Color(0xFFFF6B6B) : KeepyColors.secondaryLabel,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: <Widget>[
                for (var c = 0; c < 7; c++) Expanded(child: _day(addDays(first, r * 7 + c))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _day(DateTime d) {
    final selected = widget.selected != null && isSameDay(d, widget.selected!);
    final isToday = isSameDay(d, widget.today);
    final inMonth = d.month == _month.month;
    return GestureDetector(
      key: Key('pick-${toDateKey(d)}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _pick(d),
      child: AnimatedContainer(
        duration: KeepyMotion.fast,
        height: 34,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? KeepyGradients.primary : null,
          borderRadius: BorderRadius.circular(9),
        ),
        child: isToday && !selected
            ? GradientText('${d.day}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))
            : Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                  color: selected
                      ? Colors.white
                      : inMonth
                          ? KeepyColors.label
                          : KeepyColors.tertiaryLabel,
                ),
              ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KeepyMotion.fast,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? KeepyGradients.primary : null,
          color: selected ? null : KeepyColors.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : KeepyColors.label,
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.85,
      child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 17, color: KeepyColors.blue)),
    );
  }
}
