import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../state/task_store.dart';
import '../widgets/basics.dart';

/// 일별 완료 막대 (v0.7) — POOL PARTY 화면 위쪽 4분의 1.
///
/// - 막대 하나 = 하루. 그날 **끝낸** 할 일만 쌓는다 (4개 중 3개 끝냈으면 3칸, 4번째를 끝내면 그 태그 조각이 위로 길어짐).
/// - 막대 안은 태그별 조각: 많은 태그가 아래, 적은 태그가 위. 최대 5조각 (6개 이상·5번째 동률은 '기타').
/// - 막대 위에는 그날 완료율(끝낸 수 / 그날 할 일 수).
/// - 날짜 화면처럼 좌우로 넘기면 가운데 온 날의 막대가 넓어진다. 처음엔 오늘. 막대를 눌러도 그날로 간다.
/// - 보이는 날은 오늘 기준 7일 전 ~ 7일 뒤. 기한보다 미리 끝낸 일은 그 기한 날 막대에 미리 쌓인다.
class DailyDoneChart extends StatefulWidget {
  const DailyDoneChart({super.key, required this.store, required this.tagOrder});

  final TaskStore store;
  final List<String> tagOrder;

  /// 화면이 작으면 이 크기째로 줄인다 (POOL PARTY 화면의 FittedBox).
  static const Size designSize = Size(390, 190);

  /// 태그 색: 설정의 태그 순서대로 고정 (어느 날이든 같은 태그는 같은 색).
  static Color colorOf(DoneSegment s, List<String> tagOrder) {
    if (s.untagged) return const Color(0xFFB8C2D1);
    if (s.other) return const Color(0xFF8E9AAE);
    const palette = <Color>[
      KeepyColors.blue,
      KeepyColors.green,
      KeepyColors.orange,
      Color(0xFFA06BFF),
      KeepyColors.sky,
      Color(0xFFFF6F91),
      Color(0xFF2EC4B6),
      Color(0xFFFFC94D),
    ];
    var i = tagOrder.indexOf(s.tag);
    if (i < 0) i = s.tag.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[i % palette.length];
  }

  @override
  State<DailyDoneChart> createState() => _DailyDoneChartState();
}

class _DailyDoneChartState extends State<DailyDoneChart> {
  static const _visible = 7; // 한 화면에 보이는 막대 수
  static const _barMax = 74.0;

  late List<DateTime> _days = widget.store.chartDays;
  late int _focus = _todayIndex(_days);
  late final PageController _pages = PageController(viewportFraction: 1 / _visible, initialPage: _focus);

  /// 처음엔 오늘 (-7일 ~ +7일의 가운데).
  int _todayIndex(List<DateTime> days) {
    final i = days.indexWhere((d) => isSameDay(d, widget.store.today));
    return i < 0 ? days.length ~/ 2 : i;
  }

  @override
  void didUpdateWidget(DailyDoneChart old) {
    super.didUpdateWidget(old);
    final days = widget.store.chartDays;
    // 자정이 지나 '오늘' 이 바뀌면 범위를 다시 잡고, 보던 날을 유지 (범위 밖이면 오늘)
    if (days.length != _days.length || !isSameDay(days.first, _days.first)) {
      final focused = _days[_focus.clamp(0, _days.length - 1)];
      _days = days;
      final i = days.indexWhere((d) => isSameDay(d, focused));
      _focus = i < 0 ? _todayIndex(days) : i;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_focus);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _pages.animateToPage(i, duration: KeepyMotion.page, curve: KeepyMotion.settle);
  }

  /// '오늘로' 버튼: 다른 날을 보고 있을 때 오늘 막대로 돌아간다.
  void _goToday() {
    HapticFeedback.selectionClick();
    _goTo(_todayIndex(_days));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tagOrder = widget.tagOrder;
    final day = _days[_focus.clamp(0, _days.length - 1)];
    final isToday = isSameDay(day, store.today);
    final stat = store.statOfDay(day);
    final segments = store.doneSegmentsOn(day, tagOrder: tagOrder);
    var maxDone = 1;
    for (final d in _days) {
      final done = store.statOfDay(d).done;
      if (done > maxDone) maxDone = done;
    }

    // 오른쪽 60 은 비워 둔다: POOL PARTY 화면이 그 자리에 닫기 X 를 띄운다 (막대가 X 밑에 가려지지 않게)
    return SizedBox.fromSize(
      key: const Key('daily-chart'),
      size: DailyDoneChart.designSize,
      child: Padding(
        padding: const EdgeInsets.only(right: 60),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 고른 날 + 그날 완료율 + 닫기
          SizedBox(
            height: 34,
            child: Row(
              children: <Widget>[
                Text('${day.month}월 ${day.day}일', key: const Key('pool-date'), style: KeepyText.headline),
                const SizedBox(width: 6),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: KeepyColors.skyTint, borderRadius: BorderRadius.circular(9)),
                    child: const Text(
                      '오늘',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: KeepyColors.blue),
                    ),
                  )
                else
                  // 다른 날을 보고 있으면 '오늘로' (날짜 화면의 '오늘' 버튼과 같은 모양)
                  PressScale(
                    key: const Key('chart-today'),
                    onTap: _goToday,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
                      decoration: BoxDecoration(gradient: KeepyGradients.primary, borderRadius: BorderRadius.circular(11)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(CupertinoIcons.arrow_uturn_left, size: 11, color: Color(0xFFFFFFFF)),
                          SizedBox(width: 3),
                          Text('오늘로', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  stat.total == 0 ? '할 일 없음' : '${stat.done}/${stat.total} 완료 · ${(stat.done * 100 / stat.total).round()}%',
                  key: const Key('daily-chart-rate'),
                  style: KeepyText.caption.copyWith(color: KeepyColors.blue, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 막대들 (좌우로 넘기기)
          SizedBox(
            height: 124,
            child: PageView.builder(
              controller: _pages,
              itemCount: _days.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _focus = i);
              },
              itemBuilder: (context, i) {
                final d = _days[i];
                return GestureDetector(
                  key: ValueKey<String>('bar-${toDateKey(d)}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _goTo(i),
                  child: _DayBar(
                    day: d,
                    today: store.today,
                    stat: store.statOfDay(d),
                    segments: store.doneSegmentsOn(d, tagOrder: tagOrder),
                    tagOrder: tagOrder,
                    maxDone: maxDone,
                    barMax: _barMax,
                    focused: i == _focus,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // 고른 날의 태그 조각 설명 (아래 → 위 순서 = 많은 순)
          SizedBox(
            height: 20,
            child: segments.isEmpty
                ? Text('이날 끝낸 할 일이 없어요', style: KeepyText.footnote)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (final s in segments) ...<Widget>[
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: DailyDoneChart.colorOf(s, tagOrder),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${s.label} ${s.count}',
                            style: KeepyText.caption.copyWith(fontSize: 11, color: KeepyColors.label, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.today,
    required this.stat,
    required this.segments,
    required this.tagOrder,
    required this.maxDone,
    required this.barMax,
    required this.focused,
  });

  final DateTime day;
  final DateTime today;
  final DayStat stat;
  final List<DoneSegment> segments;
  final List<String> tagOrder;
  final int maxDone;
  final double barMax;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(day, today);
    final rate = stat.total == 0 ? null : (stat.done * 100 / stat.total).round();
    final height = stat.done == 0 ? 3.0 : (stat.done / maxDone * barMax).clamp(6.0, barMax);
    final width = focused ? 30.0 : 15.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        // 막대 위 완료율
        Text(
          rate == null ? '–' : '$rate%',
          maxLines: 1,
          style: TextStyle(
            fontFamily: KeepyText.family,
            fontSize: focused ? 12 : 9.5,
            fontWeight: FontWeight.w800,
            color: focused ? KeepyColors.blue : KeepyColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 3),
        AnimatedContainer(
          duration: KeepyMotion.normal,
          curve: KeepyMotion.settle,
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
            color: stat.done == 0 ? KeepyColors.separator : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: stat.done == 0
              ? null
              : Column(
                  // 위에서부터 그리므로 적은 태그 → 많은 태그 순 (아래가 가장 많은 태그)
                  children: <Widget>[
                    for (final s in segments.reversed)
                      Expanded(
                        flex: s.count,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 1),
                          color: DailyDoneChart.colorOf(s, tagOrder).withValues(alpha: focused ? 1 : 0.6),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        Text(
          isToday ? '오늘' : '${day.day}일',
          maxLines: 1,
          style: TextStyle(
            fontFamily: KeepyText.family,
            fontSize: focused ? 11.5 : 10,
            fontWeight: focused ? FontWeight.w800 : FontWeight.w600,
            color: focused ? KeepyColors.label : KeepyColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}
