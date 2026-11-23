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

/// 헤더 오른쪽의 태그 막대가 방 아래로 **이동하며 넓어지는** 전환.
///
/// 두 자리의 폭이 달라 나는 중간 크기에서는 막대가 들어가지 않으므로,
/// 날아가는 동안에는 도착할 모습을 한 장으로 그려 크기에 맞춰 줄인다.
Widget statsHero({required Widget child}) => Hero(
  tag: 'keepy-stats',
  flightShuttleBuilder: (_, _, _, _, toContext) => FittedBox(
    fit: BoxFit.contain,
    alignment: Alignment.topLeft,
    child: SizedBox(width: 320, child: (toContext.widget as Hero).child),
  ),
  child: child,
);

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
    this.compact = false,
  });

  final List<StatRow> rows;
  final String emptyLabel;

  /// 많은 순으로 이만큼만 (서윤님 구현도 상위 5개만 보여 준다)
  final int maxRows;

  /// 캐릭터 영역용 — 카드 없이 작게. 분수를 빼고 막대만 남긴다.
  final bool compact;

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
        style: compact
            ? T.caption.copyWith(fontSize: 10, color: K.onRoomDim)
            : T.caption,
      );
    }
    final shown = rows.take(maxRows).toList();
    final maximum = shown.first.total;
    return Column(
      key: const Key('stat-bars'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in shown)
          _Bar(row: row, maximum: maximum, compact: compact),
        if (rows.length > maxRows && !compact)
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

/// 한 줄 — 라벨 + 얇은 직사각형 막대 (+ 넓은 자리에서는 `완료/전체`).
///
/// 막대는 세 겹이다: 아주 옅은 바탕(전체 중 이 태그가 아닌 몫) · 흐린 색(아직 못 끝낸
/// 몫) · 네온 색(끝낸 몫). 흐린 쪽을 더 내려서 끝낸 몫만 눈에 들어오게 했다.
class _Bar extends StatelessWidget {
  const _Bar({required this.row, required this.maximum, this.compact = false});

  final StatRow row;
  final int maximum;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final share = maximum == 0 ? 0.0 : row.total / maximum;
    final rate = row.total == 0 ? 0.0 : row.done / row.total;
    final color = vivid(row.color);
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 3 : 4),
      child: Row(
        key: compact ? Key('stat-bar-${row.id}') : null,
        children: [
          SizedBox(
            width: compact ? 46 : 58,
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.caption.copyWith(
                fontSize: compact ? 10 : null,
                color: compact ? K.onRoomDim : K.label,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: compact ? 5 : 6),
          Expanded(
            child: SizedBox(
              height: compact ? 5 : 8,
              child: Stack(
                children: [
                  ColoredBox(
                    // 어두운 띠 위에서는 바탕을 흰색 쪽으로 아주 살짝만 띄운다
                    color: compact
                        ? const Color(0xFFFFFFFF).withValues(alpha: .13)
                        : K.ink.withValues(alpha: .06),
                    child: const SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: share.clamp(0.0, 1.0),
                    child: Container(
                      color: color.withValues(alpha: compact ? .34 : .2),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: rate.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!compact) ...[
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
        ],
      ),
    );
  }
}
