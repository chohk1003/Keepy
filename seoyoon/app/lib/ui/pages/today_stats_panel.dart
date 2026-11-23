import 'package:flutter/cupertino.dart';

import '../../core/theme.dart';
import '../../game/duck_painter.dart';
import '../../state/task_store.dart';
import '../widgets/basics.dart';

/// 오늘 통계 (v0.7) — POOL PARTY 화면 위쪽 4분의 1.
///
/// 오늘의 할 일(완료한 일은 완료한 날, 안 끝낸 일은 오늘 기한 + 기한 없이 오늘 만든 일)을 태그별로 모아
/// 많은 순으로 최대 5개까지 막대로 보여 준다. 사용자가 만든 태그도 모두 세고, 태그 없는 일은 '미지정'.
/// 공간이 모자라면 통째로 줄여(FittedBox) 넘치지 않는다.
class TodayStatsHeader extends StatelessWidget {
  const TodayStatsHeader({
    super.key,
    required this.store,
    required this.tagOrder,
    required this.onClose,
  });

  final TaskStore store;

  /// 설정의 태그 순서 (같은 개수일 때 정렬 기준).
  final List<String> tagOrder;
  final VoidCallback onClose;

  static const _barColors = <Color>[
    KeepyColors.blue,
    KeepyColors.green,
    KeepyColors.orange,
    Color(0xFFA06BFF),
    KeepyColors.sky,
  ];

  @override
  Widget build(BuildContext context) {
    final stat = store.todayStat;
    final summary = store.todayTagStats(tagOrder: tagOrder);
    final percent = stat.total == 0 ? 0 : (stat.done * 100 / stat.total).round();
    final top = summary.top;
    final today = store.today;

    // 안내 문구와 태그를 나눠서: '오늘 가장 많이 한 일' + [#수업] 칩
    final String lead;
    if (stat.total == 0) {
      lead = '오늘 할 일이 아직 없어요';
    } else if (top == null || top.done == 0) {
      lead = '오늘 가장 많은 일';
    } else {
      lead = '오늘 가장 많이 한 일';
    }

    return SizedBox(
      key: const Key('today-stats'),
      width: 390,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 날짜 + 완료율 + 닫기
          Row(
            children: <Widget>[
              Text('${today.month}월 ${today.day}일', key: const Key('pool-date'), style: KeepyText.headline),
              const SizedBox(width: 8),
              Text(
                stat.total == 0 ? '할 일 0개' : '${stat.done}/${stat.total} 완료 · $percent%',
                style: KeepyText.caption.copyWith(color: KeepyColors.blue, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              PressScale(
                key: const Key('pool-close'),
                onTap: onClose,
                scale: 0.88,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: KeepyColors.fill, shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.xmark, color: KeepyColors.label, size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const DuckView(size: 104, look: DuckLook(glasses: true, cap: true, thumbUp: true)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(child: Text(lead, key: const Key('today-stats-headline'), style: KeepyText.caption)),
                        if (stat.total > 0 && top != null) ...<Widget>[
                          const SizedBox(width: 6),
                          TagChip(stat: top, key: const Key('today-stats-top')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (summary.stats.isEmpty)
                      Text('할 일을 추가하면 태그별로 정리해 드려요.', style: KeepyText.caption)
                    else
                      for (var i = 0; i < summary.stats.length; i++)
                        _TagBar(
                          stat: summary.stats[i],
                          max: summary.stats.first.total,
                          color: _barColors[i % _barColors.length],
                        ),
                    Text('상위 5개만 출력', key: const Key('today-stats-note'), style: KeepyText.footnote),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 태그다운 태그 칩: 둥근 알약 + 옅은 하늘 바탕 + 파란 '#태그'. 태그 없는 일은 회색 '미지정'.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.stat});
  final TagStat stat;

  @override
  Widget build(BuildContext context) {
    final untagged = stat.untagged;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: untagged ? KeepyColors.fill : KeepyColors.skyTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: untagged ? KeepyColors.separator : KeepyColors.blue.withValues(alpha: 0.35)),
      ),
      child: Text(
        stat.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: KeepyText.family,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: untagged ? KeepyColors.secondaryLabel : KeepyColors.blue,
        ),
      ),
    );
  }
}

class _TagBar extends StatelessWidget {
  const _TagBar({required this.stat, required this.max, required this.color});
  final TagStat stat;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final totalFactor = max == 0 ? 0.0 : stat.total / max;
    final doneFactor = stat.total == 0 ? 0.0 : stat.done / stat.total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 74,
            child: Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KeepyText.caption.copyWith(color: KeepyColors.label, fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: <Widget>[
                    Container(color: KeepyColors.fill),
                    // 그 태그의 할 일 수 (옅게) 위에 끝낸 수 (진하게)
                    FractionallySizedBox(
                      widthFactor: totalFactor.clamp(0.0, 1.0),
                      child: Container(
                        color: color.withValues(alpha: 0.28),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: doneFactor.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: Container(color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text(
              '${stat.done}/${stat.total}',
              textAlign: TextAlign.right,
              style: KeepyText.caption.copyWith(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
