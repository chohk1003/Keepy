import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/companion.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/companion_art.dart';
import '../widgets/fx.dart';
import '../widgets/room_scene.dart';
import '../widgets/week_activity_graph.dart';
import 'progress_page.dart';
import 'activity_stats_sheet.dart';

Future<void> openCompanionRoom(
  BuildContext context,
  AppState state, {
  required Rect origin,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  PageRouteBuilder<void>(
    opaque: true,
    settings: const RouteSettings(name: '/companion'),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Motion.expansion,
    reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Motion.navigation,
    pageBuilder: (_, _, _) => CompanionRoom(state: state),
    transitionsBuilder: (context, animation, _, child) => AnimatedBuilder(
      animation: animation,
      builder: (context, _) => ClipPath(
        clipper: _RoomExpansion(
          Rect.lerp(
            origin,
            Offset.zero & MediaQuery.sizeOf(context),
            Curves.easeOutCubic.transform(animation.value),
          )!,
        ),
        child: child,
      ),
    ),
  ),
);

class _RoomExpansion extends CustomClipper<Path> {
  const _RoomExpansion(this.rect);
  final Rect rect;
  @override
  Path getClip(Size size) => Path()..addRect(rect);
  @override
  bool shouldReclip(_RoomExpansion old) => old.rect != rect;
}

class CompanionRoom extends StatefulWidget {
  const CompanionRoom({super.key, required this.state});
  final AppState state;
  @override
  State<CompanionRoom> createState() => _CompanionRoomState();
}

class _CompanionRoomState extends State<CompanionRoom>
    with TickerProviderStateMixin {
  final RoomSim _sim = RoomSim();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  bool _started = false;
  double _drag = 0, _swipe = 0;

  /// 방에서 보고 있는 날 — 좌우로 밀거나 그래프 막대를 눌러 바꾼다.
  /// 목록 화면의 선택일([AppState.selectedDay])은 건드리지 않는다.
  late DateTime _day = dayOf(widget.state.now);

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _sim.step(dt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sim.dispose();
    super.dispose();
  }

  void _goto(DateTime day) {
    final next = dayOf(day);
    if (sameDay(next, _day)) return;
    setState(() => _day = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('companion-room'),
    backgroundColor: K.room,
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final today = dayOf(state.now);
        final counts = state.activityCounts(
          addDays(today, -6),
          addDays(today, 1),
        );
        final stats = state.dayActivityStats(_day);
        var done = 0, total = 0;
        for (final s in stats.values) {
          done += s.done;
          total += s.total;
        }
        final scene = duckSceneOf(done: done, total: total);
        final padding = MediaQuery.paddingOf(context);
        final cardBottom = padding.top + 150;
        _sim
          ..scene = scene
          ..insetTop = cardBottom
          ..insetBottom = padding.bottom + 104;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => _drag = 0,
          onVerticalDragUpdate: (d) => _drag += d.delta.dy,
          onVerticalDragEnd: (d) {
            if (_drag < -65 || (d.primaryVelocity ?? 0) < -600) {
              Navigator.pop(context);
            }
          },
          // 좌우로 밀어 날짜 전환 — 그래프는 같은 주를 계속 보여 준다
          onHorizontalDragStart: (_) => _swipe = 0,
          onHorizontalDragUpdate: (d) => _swipe += d.delta.dx,
          onHorizontalDragEnd: (d) {
            final velocity = d.primaryVelocity ?? 0;
            if (_swipe < -40 || velocity < -400) {
              _goto(addDays(_day, 1));
            } else if (_swipe > 40 || velocity > 400) {
              _goto(addDays(_day, -1));
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              _sim.size = size;
              return Stack(
                children: [
                  // 그림이 화면을 가득 채운다 (아침 방 · 책상 · 수영장)
                  Positioned.fill(
                    child: GestureDetector(
                      key: const Key('room-canvas'),
                      behavior: HitTestBehavior.opaque,
                      // 100% 일 때: 누른 곳으로 오리가 둥실
                      onTapDown: (d) {
                        if (_sim.scene != DuckScene.party) return;
                        HapticFeedback.selectionClick();
                        _sim.target = d.localPosition;
                      },
                      child: CustomPaint(
                        key: ValueKey('room-scene-${scene.name}'),
                        painter: RoomPainter(_sim),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  // 위쪽: 주간 그래프를 글래스 카드로 띄운다
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _GraphCard(
                      state: state,
                      day: _day,
                      done: done,
                      total: total,
                      onSelect: _goto,
                      onToday: sameDay(_day, today) ? null : () => _goto(today),
                    ),
                  ),
                  Positioned(
                    bottom: padding.bottom + 22,
                    left: 18,
                    right: 18,
                    child: _ActivityBars(
                      counts: counts,
                      onSelected: (a) => showActivityStats(context, state, a),
                    ),
                  ),
                  // 모은 성취 수는 '기록과 보상' 화면에서 본다
                  Positioned(
                    bottom: padding.bottom + 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: K.blue.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}

/// 위쪽 글래스 카드 — 날짜·완료율·주간 그래프와 두 버튼.
class _GraphCard extends StatelessWidget {
  const _GraphCard({
    required this.state,
    required this.day,
    required this.done,
    required this.total,
    required this.onSelect,
    required this.onToday,
  });

  final AppState state;
  final DateTime day;
  final int done;
  final int total;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (done * 100 / total).round();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        MediaQuery.paddingOf(context).top + 6,
        10,
        0,
      ),
      child: Glass(
        radius: 22,
        opacity: .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('room-reports'),
                    tooltip: '기록과 보상',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ProgressPage(state: state),
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.chart_bar, color: K.ink),
                  ),
                  Text(
                    mdw(day),
                    key: const Key('room-date'),
                    style: T.headline.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    total == 0 ? '할 일 0개' : '$done/$total · $percent%',
                    key: const Key('room-rate'),
                    style: T.caption.copyWith(
                      color: K.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (onToday != null)
                    TextButton(
                      key: const Key('room-today'),
                      onPressed: onToday,
                      child: Text('오늘', style: T.caption),
                    ),
                  IconButton(
                    key: const Key('room-close'),
                    tooltip: '할 일로 돌아가기',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.chevron_up, color: K.ink),
                  ),
                ],
              ),
              WeekActivityGraph(
                state: state,
                day: day,
                onSelect: onSelect,
                height: 72,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityBars extends StatelessWidget {
  const _ActivityBars({required this.counts, required this.onSelected});
  final Map<ActivityKind, int> counts;
  final ValueChanged<ActivityKind> onSelected;
  @override
  Widget build(BuildContext context) {
    final maximum = counts.values.fold(1, (a, b) => math.max(a, b));
    return Row(
      children: [
        for (final a in ActivityKind.values)
          Expanded(
            child: Semantics(
              label: '${activityLabel(a)} 최근 7일 ${counts[a]}개 통계',
              button: true,
              child: Tooltip(
                message: activityLabel(a),
                child: InkWell(
                  key: ValueKey('activity-indicator-${a.name}'),
                  onTap: () => onSelected(a),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(K.radiusCard),
                      boxShadow: K.cardShadow(.3),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 9,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activityIcon(a),
                          size: 19,
                          color: activityColor(a),
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (counts[a] ?? 0) / maximum,
                            minHeight: 5,
                            color: activityColor(a),
                            backgroundColor: K.blue.withValues(alpha: .1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
