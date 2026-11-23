import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';

/// 막대 한 줄에 필요한 것 — 어디서 모은 수인지는 부르는 쪽이 정한다.
class StatRow {
  const StatRow({
    required this.id,
    required this.label,
    required this.color,
    required this.done,
    required this.total,
  });

  /// 테스트·키에 쓰는 이름 (태그면 태그 이름, 미지정이면 'none')
  final String id;
  final String label;
  final Color color;
  final int done;
  final int total;
}

/// 그 날의 태그별 할 일 — 서윤님 '오늘 통계' 의 막대를 그대로 가져온 모양.
///
/// 한 줄 = 라벨 + 막대 + `완료/전체`. 막대는 옅은 색으로 그 태그의 전체,
/// 그 위에 진한 색으로 끝낸 몫을 겹쳐 그린다. 0인 줄은 접는다.
class StatBars extends StatelessWidget {
  const StatBars({
    super.key,
    required this.rows,
    this.emptyLabel = '이 날은 할 일이 없어요',
    this.maxRows = 5,
  });

  final List<StatRow> rows;
  final String emptyLabel;

  /// 많은 순으로 이만큼만 (서윤님 구현도 상위 5개만 보여 준다)
  final int maxRows;

  /// 그 날의 태그별 통계를 막대 줄로 바꾼다 (미지정은 회색으로 맨 뒤)
  static List<StatRow> fromTags(Map<TaskTag?, ({int done, int total})> stats) {
    final rows = <StatRow>[
      for (final entry in stats.entries)
        if (entry.value.total > 0)
          StatRow(
            id: entry.key?.name ?? 'none',
            label: entry.key?.label ?? '미지정',
            color: entry.key?.color ?? K.label3,
            done: entry.value.done,
            total: entry.value.total,
          ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        emptyLabel,
        key: const Key('stat-bars-empty'),
        style: T.caption,
      );
    }
    final shown = rows.take(maxRows).toList();
    final maximum = shown.first.total;
    return Column(
      key: const Key('stat-bars'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in shown) _Bar(row: row, maximum: maximum),
        if (rows.length > maxRows)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '많은 순 $maxRows개만',
              style: T.caption.copyWith(fontSize: 10, color: K.label3),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.row, required this.maximum});

  final StatRow row;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final share = maximum == 0 ? 0.0 : row.total / maximum;
    final rate = row.total == 0 ? 0.0 : row.done / row.total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.caption.copyWith(
                color: K.label,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: K.fill),
                    FractionallySizedBox(
                      widthFactor: share.clamp(0.0, 1.0),
                      child: Container(
                        color: row.color.withValues(alpha: .28),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: rate.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: Container(color: row.color),
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
              '${row.done}/${row.total}',
              key: Key('stat-bar-${row.id}'),
              textAlign: TextAlign.right,
              style: T.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
