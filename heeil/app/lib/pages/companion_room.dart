import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/companion.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/companion_art.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _delivery = AnimationController(
    vsync: this,
    duration: Motion.delivery,
  );
  late final int _batch = widget.state.pendingCredits.length;
  bool _started = false;
  double _drag = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.state.deliverCredits();
      if (_batch > 0 && !reduce) {
        HapticFeedback.lightImpact();
        _delivery.forward();
      } else {
        _delivery.value = 1;
      }
    });
  }

  @override
  void dispose() {
    _delivery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('companion-room'),
    backgroundColor: K.room,
    body: AnimatedBuilder(
      animation: Listenable.merge([widget.state, _delivery]),
      builder: (context, _) {
        final state = widget.state;
        final start = addDays(dayOf(state.now), -6);
        final counts = state.activityCounts(
          start,
          addDays(dayOf(state.now), 1),
        );
        final sorted = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final activity = sorted.first.value == 0
            ? ActivityKind.other
            : sorted.first.key;
        final progress = _delivery.value;
        final joy = _batch > 0 && progress > .45 && progress < 1
            ? math.sin((progress - .45) / .55 * math.pi)
            : 0.0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => _drag = 0,
          onVerticalDragUpdate: (d) => _drag += d.delta.dy,
          onVerticalDragEnd: (d) {
            if (_drag < -65 || (d.primaryVelocity ?? 0) < -600) {
              Navigator.pop(context);
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final top = MediaQuery.paddingOf(context).top;
              final animalSize = math.min(size.width * .73, size.height * .43);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoomPainter(state.unlockedRewards),
                    ),
                  ),
                  Positioned(
                    bottom: MediaQuery.paddingOf(context).bottom + 38,
                    left: 24,
                    right: 24,
                    child: _ActivityBars(
                      counts: counts,
                      onSelected: (a) => showActivityStats(context, state, a),
                    ),
                  ),
                  Positioned(
                    left: (size.width - animalSize) / 2,
                    top: size.height * .32,
                    width: animalSize,
                    height: animalSize,
                    child: Hero(
                      tag: 'keepy-companion',
                      child: CompanionArt(
                        kind: state.companion,
                        activity: activity,
                        joy: joy,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: size.height * .32 + animalSize - 5,
                    child: Center(
                      child: _Bowl(
                        count: state.creditedTasks
                            .where((t) => t.credit!.deliveredAt != null)
                            .length,
                      ),
                    ),
                  ),
                  if (_batch > 0 && progress < .85)
                    ...List.generate(math.min(_batch, 12), (i) {
                      final p = ((progress - i * .018) / .75).clamp(0.0, 1.0);
                      final x =
                          size.width / 2 +
                          math.sin(p * math.pi) *
                              ((i % 2 == 0 ? -1 : 1) * (28 + i * 4));
                      final end = size.height * .32 + animalSize;
                      final y =
                          size.height -
                          60 +
                          (end - size.height + 60) *
                              Curves.easeOutCubic.transform(p);
                      return Positioned(
                        left: x - 7,
                        top: y,
                        child: Transform.rotate(
                          angle: p * 3 + i.toDouble(),
                          child: Container(
                            width: 14,
                            height: 10,
                            decoration: BoxDecoration(
                              color: K.crumb,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    }),
                  Positioned(
                    top: top + 4,
                    right: 8,
                    child: IconButton(
                      key: const Key('room-close'),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      tooltip: '할 일로 돌아가기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.chevron_up, color: K.ink),
                    ),
                  ),
                  Positioned(
                    top: top + 4,
                    left: 8,
                    child: IconButton(
                      key: const Key('room-reports'),
                      tooltip: '기록과 보상',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ProgressPage(state: state),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.chart_bar, color: K.ink),
                    ),
                  ),
                  Positioned(
                    bottom: MediaQuery.paddingOf(context).bottom + 20,
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
                    constraints: const BoxConstraints(minHeight: 64),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 13,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activityIcon(a),
                          size: 23,
                          color: activityColor(a),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (counts[a] ?? 0) / maximum,
                            minHeight: 6,
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

class _Bowl extends StatelessWidget {
  const _Bowl({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '전달한 성취 $count개',
    child: SizedBox(
      width: 116,
      height: 56,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: const Offset(0, -10),
            child: ExcludeSemantics(child: CrumbPile(count: count)),
          ),
          Positioned(
            top: 23,
            child: Container(
              width: 100,
              height: 31,
              decoration: const BoxDecoration(
                color: Color(0xFFBD8D6B),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(29),
                  bottomRight: Radius.circular(25),
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(Set<String> rewards) : rewards = Set.of(rewards);
  final Set<String> rewards;
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = K.room);
    final floor = s.height * .72;
    c.drawPath(
      Path()
        ..moveTo(0, floor)
        ..quadraticBezierTo(s.width * .3, floor - 4, s.width * .6, floor + 2)
        ..lineTo(s.width, floor)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close(),
      Paint()..color = K.roomFloor,
    );
    final window = Rect.fromLTWH(
      s.width * .1,
      s.height * .24,
      s.width * .23,
      s.height * .16,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(window.inflate(6), const Radius.circular(35)),
      Paint()..color = const Color(0xFFFFFBF1),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(30)),
      Paint()..color = const Color(0xFF91DFF1),
    );
    c.drawLine(
      Offset(window.center.dx, window.top),
      Offset(window.center.dx, window.bottom),
      Paint()
        ..color = const Color(0xFFFFFBF1)
        ..strokeWidth = 4,
    );
    c.drawLine(
      Offset(window.left, window.center.dy),
      Offset(window.right, window.center.dy),
      Paint()
        ..color = const Color(0xFFFFFBF1)
        ..strokeWidth = 4,
    );
    final shelf = Rect.fromLTWH(
      s.width * .62,
      s.height * .36,
      s.width * .27,
      8,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(shelf, const Radius.circular(3)),
      Paint()..color = const Color(0xFF9B70D9),
    );
    if (rewards.contains('plant')) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(shelf.left + 13, shelf.top - 28, 24, 28),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFFBD8D6B),
      );
      c.drawOval(
        Rect.fromLTWH(shelf.left + 8, shelf.top - 54, 22, 30),
        Paint()..color = K.blue,
      );
      c.drawOval(
        Rect.fromLTWH(shelf.left + 25, shelf.top - 51, 22, 27),
        Paint()..color = const Color(0xFF7C9F72),
      );
    }
    if (rewards.contains('cushion')) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * .12, floor + 60, 65, 32),
          const Radius.circular(16),
        ),
        Paint()..color = const Color(0xFFB8ABD0),
      );
    }
    if (rewards.contains('lamp')) {
      c.drawLine(
        Offset(s.width * .82, 0),
        Offset(s.width * .82, s.height * .2),
        Paint()
          ..color = K.blue
          ..strokeWidth = 2,
      );
      c.drawCircle(
        Offset(s.width * .82, s.height * .2),
        19,
        Paint()..color = const Color(0xFFF0D88C),
      );
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.rewards.length != rewards.length || !old.rewards.containsAll(rewards);
}
