import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/companion.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';

/// 7일간의 완료 기록 — 얇은 세로선 막대와 그 정점을 잇는 하얀 선.
///
/// 주식창처럼 **오늘이 맨 오른쪽**이다. 보고 있는 날이 그 창을 벗어나면
/// (스와이프로 더 과거·미래로 갔을 때) 그 날이 맨 오른쪽이 되게 창을 민다.
/// 색은 그 창에서 많이 쓴 **상위 3개 태그**만 쓰고 나머지는 기타(회색)로 묶는다.
///
/// 막대 하나를 누르면 그 날로 넘어간다 ([onSelect]).
class WeekActivityGraph extends StatelessWidget {
  const WeekActivityGraph({
    super.key,
    required this.state,
    required this.day,
    required this.onSelect,
    this.height = 76,
  });

  final AppState state;

  /// 지금 보고 있는 날
  final DateTime day;
  final ValueChanged<DateTime> onSelect;
  final double height;

  /// 한 화면에 보이는 날 수
  static const span = 7;

  /// 색을 그대로 쓰는 태그 수 (나머지는 기타로 묶는다)
  static const colored = 3;

  /// 요일 라벨이 쓰는 높이
  static const _labelBand = 18.0;

  @override
  Widget build(BuildContext context) {
    final today = dayOf(state.now);
    final current = dayOf(day);
    // 오늘이 맨 오른쪽. 창을 벗어난 날을 보고 있으면 그 날을 맨 오른쪽으로.
    final behind = dayDiff(current, today);
    final end = behind < 0 || behind >= span ? current : today;
    final days = [for (var i = span - 1; i >= 0; i--) addDays(end, -i)];
    final counts = [for (final d in days) state.tagCreditsOn(d)];

    // 창 전체에서 많은 순으로 상위 몇 개만 색을 쓴다
    final sums = <TaskTag, int>{};
    for (final c in counts) {
      for (final e in c.entries) {
        if (e.key != null) {
          sums[e.key!] = (sums[e.key!] ?? 0) + e.value;
        }
      }
    }
    final ranked = sums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final palette = [for (final e in ranked.take(colored)) e.key];

    final columns = <_Column>[];
    for (final c in counts) {
      final total = c.values.fold(0, (a, b) => a + b);
      var rest = total;
      final segments = <_Segment>[];
      // 아래에서부터 상위 태그 순서대로, 나머지(기타·미지정)는 맨 위에 회색으로
      for (final tag in palette) {
        final n = c[tag] ?? 0;
        if (n > 0) {
          segments.add(_Segment(vivid(tag.color), n));
          rest -= n;
        }
      }
      if (rest > 0) segments.add(_Segment(K.label3, rest));
      columns.add(_Column(total: total, segments: segments));
    }
    final maximum = math.max(
      1,
      columns.fold(0, (a, c) => math.max(a, c.total)),
    );
    final selected = days.indexWhere((d) => sameDay(d, current));

    return SizedBox(
      key: const Key('week-activity-graph'),
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: _labelBand,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Motion.chart,
                curve: Motion.out,
                builder: (context, grow, _) => CustomPaint(
                  painter: _GraphPainter(
                    columns: columns,
                    maximum: maximum,
                    selected: selected,
                    grow: grow,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < span; i++)
                Expanded(
                  child: _Hit(
                    day: days[i],
                    total: columns[i].total,
                    selected: i == selected,
                    today: sameDay(days[i], today),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(days[i]);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 막대 한 칸의 한 조각 (태그 하나, 또는 묶인 기타)
class _Segment {
  const _Segment(this.color, this.count);
  final Color color;
  final int count;
}

class _Column {
  const _Column({required this.total, required this.segments});
  final int total;
  final List<_Segment> segments;
}

/// 막대·정점 선·정점 점을 한 번에 그린다 (얇은 선 그래프라 위젯으로 쌓지 않는다).
class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.columns,
    required this.maximum,
    required this.selected,
    required this.grow,
  });

  final List<_Column> columns;
  final int maximum;
  final int selected;
  final double grow;

  /// 막대 폭 — '얇은 세로선'
  static const bar = 4.0;

  /// 정점 선·점 색 — 어두운 배경에서는 하양, 밝은 유리 위에서는 잉크
  static Color get _line => isDarkTone ? Colors.white : K.ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || columns.isEmpty) return;
    final slot = size.width / columns.length;
    // 그래프와 요일 사이 기준선
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 0.5, size.width, 1),
      Paint()..color = _line.withValues(alpha: .18),
    );
    // 정점의 점이 잘리지 않게 위를 조금 비워 둔다
    final full = size.height - 5;
    final apex = <Offset>[];

    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      final x = slot * (i + 0.5);
      final tall = column.total == 0
          ? 2.0
          : (3 + (full - 3) * column.total / maximum) * grow;
      final top = size.height - tall;
      apex.add(Offset(x, top));

      if (i == selected) {
        // 고른 날 기준선 (주식창의 십자선)
        canvas.drawRect(
          Rect.fromLTWH(x - 0.5, 0, 1, size.height),
          Paint()..color = _line.withValues(alpha: .3),
        );
      }
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - bar / 2, top, bar, tall),
        const Radius.circular(bar / 2),
      );
      if (column.total == 0) {
        canvas.drawRRect(rect, Paint()..color = K.fill2);
        continue;
      }
      canvas.save();
      canvas.clipRRect(rect);
      var y = size.height;
      for (final segment in column.segments) {
        final part = tall * segment.count / column.total;
        canvas.drawRect(
          Rect.fromLTWH(x - bar / 2, y - part, bar, part),
          Paint()..color = segment.color,
        );
        y -= part;
      }
      canvas.restore();
    }

    // 정점 연결선 — 막대보다 더 얇게
    canvas.drawPath(
      Path()..addPolygon(apex, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = _line.withValues(alpha: .85),
    );
    // 정점 점
    final dot = Paint()..color = _line;
    for (var i = 0; i < apex.length; i++) {
      if (i == selected) {
        canvas.drawCircle(apex[i], 4.2, dot);
        canvas.drawCircle(apex[i], 2.2, Paint()..color = K.blue);
      } else {
        canvas.drawCircle(apex[i], 2.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}

/// 막대 한 칸의 터치 영역 + 아래 요일 라벨
class _Hit extends StatelessWidget {
  const _Hit({
    required this.day,
    required this.total,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final int total;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${day.month}월 ${day.day}일 완료 $total개',
    button: true,
    selected: selected,
    child: GestureDetector(
      key: ValueKey('week-bar-${dayKey(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? K.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              weekdayKo[day.weekday - 1],
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
  );
}
