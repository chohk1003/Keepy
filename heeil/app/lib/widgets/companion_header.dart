import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../pages/companion_room.dart';
import 'activity_bars.dart';
import 'companion_art.dart';

/// Only this region owns the room gesture; task cancellation and list scrolling
/// keep their existing recognizers. The work page stays mounted below the route.
class CompanionHeader extends StatefulWidget {
  const CompanionHeader({super.key});
  @override
  State<CompanionHeader> createState() => _CompanionHeaderState();
}

class _CompanionHeaderState extends State<CompanionHeader>
    with SingleTickerProviderStateMixin {
  double _pull = 0;
  bool _opening = false;
  bool _canPull = false;
  int? _lastCredits;
  late final AnimationController _reaction = AnimationController(
    vsync: this,
    duration: Motion.celebration,
  );
  @override
  void dispose() {
    _reaction.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    setState(() => _pull = 0);
    final state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    final box = context.findRenderObject();
    // 레이아웃 전이면 화면 위 가장자리(높이 0)에서 펼친다.
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : Offset.zero & Size(MediaQuery.sizeOf(context).width, 0);
    await openCompanionRoom(context, state, origin: origin);
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // 할 일을 하나 끝내면 캐릭터가 그 자리에서 바로 반응한다 (전달 과정 없음)
    final credits = state.creditedTasks.length;
    if (_lastCredits != null &&
        credits > _lastCredits! &&
        !MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reaction.forward(from: 0);
      });
    }
    _lastCredits = credits;
    return Semantics(
      label: '캐릭터 방 열기',
      button: true,
      onTap: _open,
      child: GestureDetector(
        key: const Key('companion-header'),
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        onVerticalDragDown: (_) {
          final position = Scrollable.maybeOf(context)?.position;
          _canPull =
              position == null ||
              (!position.isScrollingNotifier.value &&
                  position.pixels <= position.minScrollExtent + .5);
        },
        onVerticalDragUpdate: (d) => setState(
          () => _pull = _canPull ? (_pull + d.delta.dy).clamp(0, 110) : 0,
        ),
        onVerticalDragEnd: (d) {
          if (_canPull && _pull >= 72) {
            _open();
          } else {
            setState(() => _pull = 0);
          }
        },
        onVerticalDragCancel: () => setState(() => _pull = 0),
        child: Container(
          height: 188 + MediaQuery.paddingOf(context).top + _pull * .2,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: K.room,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: MediaQuery.paddingOf(context).top + 14,
                left: 22,
                child: Text('Keepy', style: T.title3.copyWith(color: K.blue)),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                right: 8,
                child: IconButton(
                  key: const Key('room-open'),
                  tooltip: '캐릭터 방 열기',
                  onPressed: _open,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(
                    CupertinoIcons.chevron_down,
                    size: 24,
                    color: K.ink,
                  ),
                ),
              ),
              // 오른쪽: 오늘 통계 카드 (흰 카드가 노란 바탕 위에 떠 보이게)
              Positioned(
                left: 114,
                right: 14,
                top: MediaQuery.paddingOf(context).top + 46,
                bottom: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: K.card,
                    borderRadius: BorderRadius.circular(K.radiusCard),
                    border: Border.all(color: K.hairline, width: 0.8),
                    boxShadow: K.cardShadow(.5),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 228,
                      child: _TodayStats(state: state),
                    ),
                  ),
                ),
              ),
              // 왼쪽: 캐릭터 — 카드 옆에 앉아 아래쪽만 목록 띠에 살짝 가린다
              Positioned(
                left: 6,
                bottom: 2,
                width: 116,
                height: 116,
                child: Transform.translate(
                  offset: Offset(0, _pull * .16),
                  child: AnimatedBuilder(
                    animation: _reaction,
                    builder: (_, _) => Hero(
                      tag: 'keepy-companion',
                      child: CompanionArt(
                        joy: _reaction.isAnimating ? 1 - _reaction.value : 0,
                      ),
                    ),
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

/// 헤더 오른쪽 — 오늘 날짜·완료율과 태그별 막대 (서윤님 '오늘 통계' 배치).
/// 막대는 태그 그대로 세고, 캐릭터 장면만 통합 분류를 쓴다.
class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final today = dayOf(state.now);
    final rows = StatBars.fromTags(state.dayTagStats(today));
    // 완료율은 막대와 같은 범위('그 날의 일')를 보되, 태그가 여러 개여도
    // 할 일 하나는 하나로만 센다 — 그래서 분류별 집계를 합쳐서 쓴다.
    var done = 0, total = 0;
    for (final s in state.dayActivityStats(today).values) {
      done += s.done;
      total += s.total;
    }
    final percent = total == 0 ? 0 : (done * 100 / total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '${today.month}월 ${today.day}일',
              key: const Key('header-date'),
              style: T.headline.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text(
              total == 0 ? '할 일 0개' : '$done/$total · $percent%',
              key: const Key('header-rate'),
              style: T.caption.copyWith(
                color: K.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        StatBars(rows: rows, emptyLabel: '할 일을 추가하면 태그별로 정리해 드려요'),
      ],
    );
  }
}
