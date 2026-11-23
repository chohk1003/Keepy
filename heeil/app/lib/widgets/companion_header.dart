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
  /// 상반신 그림의 폭 (높이는 이 값 × [CompanionArt.bustRatio])
  static const _bust = 148.0;

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
          height: 148 + MediaQuery.paddingOf(context).top + _pull * .2,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: K.room,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              // 캐릭터 뒤 은은한 빛 — 어두운 띠에서 오리가 조명을 받는 것처럼
              Positioned(
                left: -34,
                bottom: -40,
                width: _bust + 80,
                height: _bust + 60,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 22,
                child: Text(
                  'Keepy',
                  style: T.title3.copyWith(color: K.onRoom, letterSpacing: 0.2),
                ),
              ),
              // 오른쪽 아래: 오늘 통계 — 카드 없이 바탕 위에 바로 올린다
              Positioned(
                left: _bust + 4,
                right: 16,
                bottom: 14,
                child: _TodayStats(state: state),
              ),
              // 왼쪽: 캐릭터 — 얼굴·상반신만. 가슴 아래는 띠 끝에서 잘려
              // 목록 위로 빼꼼 내다보는 구도가 된다.
              Positioned(
                left: 0,
                bottom: 0,
                width: _bust,
                height: _bust * CompanionArt.bustRatio,
                child: Transform.translate(
                  offset: Offset(0, _pull * .16),
                  child: AnimatedBuilder(
                    animation: _reaction,
                    builder: (_, _) => Hero(
                      tag: 'keepy-companion',
                      child: CompanionArt(
                        bust: true,
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
        // 할 일이 많은 날에는 '10/10 · 100%' 처럼 길어지므로 둘 다 줄어들 수 있게
        Row(
          children: [
            Flexible(
              child: Text(
                '${today.month}월 ${today.day}일',
                key: const Key('header-date'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: T.caption.copyWith(
                  color: K.onRoom,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                total == 0 ? '할 일 0개' : '$done/$total · $percent%',
                key: const Key('header-rate'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: T.caption.copyWith(
                  fontSize: 10,
                  color: K.onRoomAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // 방을 열면 이 막대가 그대로 아래로 내려가며 폭을 꽉 채운다
        statsHero(
          child: StatBars(
            rows: rows,
            compact: true,
            maxRows: 4,
            emptyLabel: '할 일을 추가하면 태그별로 정리해 드려요',
          ),
        ),
      ],
    );
  }
}
