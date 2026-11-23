import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme.dart';
import '../../game/duck_painter.dart';
import '../../state/keepy_scope.dart';
import '../../state/task_store.dart';
import '../widgets/basics.dart';
import 'daily_chart.dart';

/// POOL PARTY 장면 (v0.7). 오늘의 할 일 완료율로 정한다.
enum DuckScene {
  /// 50% 미만 (할 일 0개 포함) → 이제 막 일어난 아침 방: 파자마·잠옷 모자 오리가 베개를 끌고 멀뚱멀뚱
  morning,

  /// 50% 이상 → 책상: 셔츠·넥타이 오리가 노트북으로 일하는 중 (책·커피)
  work,

  /// 100% → 화면 가득 찬 수영장: 선글라스·튜브·칵테일·비치볼, 기울기·탭으로 이동
  party,
}

DuckScene duckSceneOf(DayStat stat) {
  final rate = stat.total == 0 ? 0.0 : stat.done / stat.total;
  if (rate >= 1) return DuckScene.party;
  if (rate >= 0.5) return DuckScene.work;
  return DuckScene.morning;
}

/// 휴대폰 기울기 (-1 ~ 1, 화면 기준 오른쪽·아래가 +). 안드로이드·iOS 만 가속도 센서를 쓰고,
/// 웹·PC 에서는 아무 값도 보내지 않는다 (대신 화면을 누른 곳으로 이동).
Stream<Offset> defaultTiltSource() {
  final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (!mobile) return const Stream<Offset>.empty();
  try {
    return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
        .map((e) => Offset((-e.x / 6).clamp(-1.0, 1.0), (e.y / 6).clamp(-1.0, 1.0)));
  } catch (_) {
    return const Stream<Offset>.empty();
  }
}

/// POOL PARTY (v0.7) — 미니게임을 대신하는 상호작용 화면.
///
/// 메인 화면 오른쪽 위 오리 얼굴 아이콘(설정에서 켰을 때)으로 연다. 카메라처럼 3단 화면과 따로 떠 있고 X 로 닫는다.
/// 오늘의 할 일(TaskStore.todayTasks) 완료율에 따라 아침 방 → 책상 → 수영장 파티([DuckScene]) 장면을 화면 가득 보여 준다.
class PoolPage extends StatefulWidget {
  const PoolPage({super.key});

  /// 기울기 입력. 테스트에서는 빈 스트림으로 바꿔 끼운다 (센서 플러그인이 없는 환경).
  static Stream<Offset> Function() tiltSource = defaultTiltSource;

  static Future<void> open(BuildContext context) {
    HapticFeedback.selectionClick();
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => const PoolPage(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  State<PoolPage> createState() => _PoolPageState();
}

class _PoolPageState extends State<PoolPage> with SingleTickerProviderStateMixin {
  final _PoolSim _sim = _PoolSim();
  late final Ticker _ticker = createTicker(_onTick);
  StreamSubscription<Offset>? _tilt;
  Offset? _tiltBase; // 처음 들고 있던 자세를 0 으로 (비스듬히 들고 봐도 오리가 한쪽으로 쏠리지 않게)
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _tilt = PoolPage.tiltSource().listen(
      (o) {
        final base = _tiltBase ??= o;
        final d = o - base;
        _sim.tilt = Offset(d.dx.clamp(-1.0, 1.0), d.dy.clamp(-1.0, 1.0));
      },
      onError: (Object _) {},
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _tilt?.cancel();
    _ticker.dispose();
    _sim.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _sim.step(dt);
  }

  @override
  Widget build(BuildContext context) {
    final scope = KeepyScope.of(context);
    final dark = KeepyPalette.dark;
    final padding = MediaQuery.paddingOf(context);
    final screenH = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: KeepyColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[scope.tasks, scope.settings]),
          builder: (context, _) {
            final scene = duckSceneOf(scope.tasks.todayStat);
            _sim
              ..scene = scene
              ..night = dark
              ..insetTop = 0 // 장면 위에 떠 있는 버튼이 없다 (날짜·닫기는 위쪽 막대 영역에)
              ..insetBottom = padding.bottom;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Column(
              children: <Widget>[
                // 위쪽 4분의 1: 일별 완료 막대 (공간이 모자라면 통째로 줄어든다)
                SizedBox(
                  height: screenH * 0.25,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: DailyDoneChart(
                          store: scope.tasks,
                          tagOrder: scope.settings.settings.tags,
                        ),
                      ),
                    ),
                  ),
                ),
                // 나머지 4분의 3: 오리 장면 (아침 방 · 책상 · 수영장 파티)
                // 통계와 장면 사이는 곧은 한 줄
                Container(height: 1, color: KeepyColors.separator),
                Expanded(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _sim.size = constraints.biggest;
                        return GestureDetector(
                          key: const Key('pool-canvas'),
                          behavior: HitTestBehavior.opaque,
                          // 100% 일 때: 누른 곳으로 오리가 둥실 (웹·PC 는 기울기 대신 이것)
                          onTapDown: (d) {
                            if (_sim.scene != DuckScene.party) return;
                            HapticFeedback.selectionClick();
                            _sim.target = d.localPosition;
                          },
                          child: CustomPaint(
                            key: ValueKey<String>('pool-scene-${scene.name}'),
                            size: Size.infinite,
                            painter: _PoolPainter(_sim),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
                ),
                // 닫기 X: 메인 화면 POOL PARTY 버튼과 같은 자리·같은 크기·같은 모양 (여는 버튼 = 닫는 버튼)
                // 메인: SafeArea + 목록 여백(위 8, 좌우 16) + 머리 줄 40 안 가운데 36 → 위 10, 오른쪽 16, 1.2배
                Positioned(
                  top: padding.top + 10,
                  right: 16,
                  child: PressScale(
                    key: const Key('pool-close'),
                    onTap: () => Navigator.pop(context),
                    scale: 0.9,
                    child: Transform.scale(
                      scale: 1.2,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: KeepyColors.skyTint,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.close_rounded, size: 22, color: KeepyColors.blue),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 창밖 해: 이제 막 뜬 해 / 중천의 해.
enum _Sun { rise, noon }

/// 커튼: 양쪽 열림 / 한쪽 닫힘 / 모두 닫힘.
enum _Curtains { open, half, closed }

/// 장면 크기·위치 (그리기와 움직임 계산이 같은 값을 쓴다). 화면 전체를 쓴다.
class _PoolGeo {
  _PoolGeo(this.size, this.insetTop, this.insetBottom);

  final Size size;
  final double insetTop;
  final double insetBottom;

  double get w => size.width;
  double get h => size.height;

  /// 수영장 오리 크기
  double get ds => math.min(w * 0.42, h * 0.23); // 수영장 오리는 조금 크게

  /// 방 장면 오리 크기
  double get roomDs => math.min(w * 0.36, h * 0.2);

  /// 오리가 갈 수 있는 범위
  double get minY => insetTop + 10 + ds * 0.6;
  double get maxY => h - insetBottom - 12 - ds * 0.5;
  double get minX => ds * 0.72;
  double get maxX => math.max(minX, w - ds * 0.72);

  /// 비치볼 반지름
  double get ballR => ds * 0.24;
}

/// 오리·비치볼 위치 계산 (프레임마다). 움직임은 수영장 파티에서만.
class _PoolSim extends ChangeNotifier {
  double time = 0;
  DuckScene scene = DuckScene.morning;
  bool night = false;
  Size size = Size.zero;
  double insetTop = 0;
  double insetBottom = 0;
  double x = double.nan;
  double y = double.nan;
  double vx = 0;
  double vy = 0;
  Offset tilt = Offset.zero;
  Offset? target;
  // 비치볼
  double bx = double.nan;
  double by = double.nan;
  double bvx = -0.6;
  double bvy = 0.4;
  double spin = 0;

  void step(double dt) {
    time += dt;
    final f = dt * 60; // 60fps 기준 한 프레임 = 1
    if (scene == DuckScene.party && size.width > 0 && size.height > 0) _party(_PoolGeo(size, insetTop, insetBottom), f);
    notifyListeners();
  }

  void _party(_PoolGeo g, double f) {
    if (x.isNaN || y.isNaN) {
      x = g.w / 2;
      y = (g.minY + g.maxY) / 2;
    }
    // 오리: 가만히 있어도 천천히 떠다니고, 기울기·탭한 곳으로 둥실 미끄러진다.
    var ax = tilt.dx * 0.55 + math.sin(time * 0.37) * 0.05 + math.sin(time * 0.13 + 1) * 0.04;
    var ay = tilt.dy * 0.55 + math.cos(time * 0.29) * 0.04;
    final t = target;
    if (t != null) {
      ax += (t.dx - x) * 0.006;
      ay += (t.dy - y) * 0.006;
      if ((t - Offset(x, y)).distance < 12) target = null;
    }
    vx += ax * f;
    vy += ay * f;
    final damp = math.pow(0.95, f).toDouble();
    vx *= damp;
    vy *= damp;
    x += vx * f;
    y += vy * f;
    if (x < g.minX) {
      x = g.minX;
      vx = vx.abs() * 0.5;
    } else if (x > g.maxX) {
      x = g.maxX;
      vx = -vx.abs() * 0.5;
    }
    if (y < g.minY) {
      y = g.minY;
      vy = vy.abs() * 0.5;
    } else if (y > g.maxY) {
      y = g.maxY;
      vy = -vy.abs() * 0.5;
    }

    // 비치볼: 혼자 둥둥, 벽과 오리에 부딪히면 통 튕긴다
    final r = g.ballR;
    if (bx.isNaN || by.isNaN) {
      bx = g.w * 0.75;
      by = g.minY + (g.maxY - g.minY) * 0.25;
    }
    bvx += (math.sin(time * 0.5 + 2) * 0.02 + tilt.dx * 0.3) * f;
    bvy += (math.cos(time * 0.41) * 0.02 + tilt.dy * 0.3) * f;
    final bd = math.pow(0.985, f).toDouble();
    bvx *= bd;
    bvy *= bd;
    bx += bvx * f;
    by += bvy * f;
    final bMinY = insetTop + 8 + r;
    final bMaxY = math.max(bMinY, g.h - insetBottom - r);
    if (bx < r) {
      bx = r;
      bvx = bvx.abs() * 0.8;
    } else if (bx > g.w - r) {
      bx = g.w - r;
      bvx = -bvx.abs() * 0.8;
    }
    if (by < bMinY) {
      by = bMinY;
      bvy = bvy.abs() * 0.8;
    } else if (by > bMaxY) {
      by = bMaxY;
      bvy = -bvy.abs() * 0.8;
    }
    final cy = y + g.ds * 0.05;
    final dx = bx - x;
    final dy = by - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final reach = r + g.ds * 0.55;
    if (dist < reach && dist > 0.01) {
      final nx = dx / dist;
      final ny = dy / dist;
      bx = x + nx * reach;
      by = cy + ny * reach;
      final rel = (bvx - vx) * nx + (bvy - vy) * ny;
      if (rel < 0) {
        bvx += -1.8 * rel * nx + nx * 0.8;
        bvy += -1.8 * rel * ny + ny * 0.8;
      }
    }
    spin += bvx * 0.02 * f;
  }
}

class _PoolPainter extends CustomPainter {
  _PoolPainter(this.sim) : super(repaint: sim);
  final _PoolSim sim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final g = _PoolGeo(size, sim.insetTop, sim.insetBottom);
    switch (sim.scene) {
      case DuckScene.morning:
        _paintMorning(canvas, g, sim.time, night: sim.night);
      case DuckScene.work:
        _paintWork(canvas, g, sim.time, night: sim.night);
      case DuckScene.party:
        if (!sim.x.isNaN && !sim.bx.isNaN) _paintParty(canvas, g, sim.time);
    }
  }

  @override
  bool shouldRepaint(_PoolPainter old) => old.sim != sim;

  // ------------------------------------------------------------ 그리기 도우미

  static void _rr(Canvas c, double x, double y, double w, double h, double r, Color? fill, {Color? stroke, double sw = 2}) {
    _rrc(c, x, y, w, h, Radius.circular(r), Radius.circular(r), fill, stroke: stroke, sw: sw);
  }

  /// 위쪽 모서리 [top], 아래쪽 모서리 [bottom] 반지름이 다른 둥근 네모.
  static void _rrc(Canvas c, double x, double y, double w, double h, Radius top, Radius bottom, Color? fill,
      {Color? stroke, double sw = 2}) {
    final r = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, y, w, h),
      topLeft: top,
      topRight: top,
      bottomLeft: bottom,
      bottomRight: bottom,
    );
    if (fill != null) c.drawRRect(r, Paint()..color = fill);
    if (stroke != null) {
      c.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = stroke,
      );
    }
  }

  static Paint _line(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  /// 벽 + 마룻바닥 + 걸레받이
  static void _room(Canvas c, _PoolGeo g, double floorTop, Color wall1, Color wall2, Color floor) {
    c.drawRect(
      Rect.fromLTWH(0, 0, g.w, floorTop),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[wall1, wall2],
        ).createShader(Rect.fromLTWH(0, 0, g.w, floorTop)),
    );
    c.drawRect(Rect.fromLTWH(0, floorTop, g.w, g.h - floorTop), Paint()..color = floor);
    final plank = _line(const Color(0x2EA06E3C), 1.5);
    var yy = floorTop + 22;
    for (var i = 0; yy < g.h; i++) {
      c.drawLine(Offset(0, yy), Offset(g.w, yy), plank);
      yy += 26 + i * 4;
    }
    c.drawRect(Rect.fromLTWH(0, floorTop - 7, g.w, 7), Paint()..color = const Color(0xB3FFFFFF));
  }

  /// 창문. [sun]: 이제 막 뜬 해(rise) / 중천의 해(noon). [curtains]: 양쪽 열림 / 한쪽 닫힘 / 모두 닫힘.
  /// [colors] = (커튼, 주름, 끈). [dim] 이면 창틀도 조금 어둡게 (다크 모드 방).
  static void _window(
    Canvas c,
    double x,
    double y,
    double w,
    double h,
    double t, {
    required _Sun sun,
    required _Curtains curtains,
    required (Color, Color, Color) colors,
    bool dim = false,
  }) {
    _rr(c, x - 4, y + 6, w + 8, h + 4, 10, const Color(0x0F000000));
    final rise = sun == _Sun.rise;
    final glass = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(8));
    c.drawRRect(
      glass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: rise
              ? const <Color>[Color(0xFF8FCBFF), Color(0xFFD6ECFF), Color(0xFFFFD3A6)]
              : const <Color>[Color(0xFF6EC2FF), Color(0xFFD3EFFF)],
          stops: rise ? const <double>[0, 0.6, 1] : null,
        ).createShader(glass.outerRect),
    );
    c.save();
    c.clipRRect(glass);
    final sr = math.min(w, h) * (rise ? 0.2 : 0.14);
    final sx = rise ? x + w * 0.62 : x + w * 0.5;
    final sy = rise ? y + h * 0.86 : y + h * 0.26;
    if (rise) {
      c.drawRect(
        glass.outerRect,
        Paint()
          ..shader = RadialGradient(
            colors: const <Color>[Color(0xB3FFD678), Color(0x00FFD678)],
            stops: const <double>[0.19, 1],
          ).createShader(Rect.fromCircle(center: Offset(sx, sy), radius: sr * 2.6)),
      );
    }
    final ray = _line(rise ? const Color(0xFFFFB84D) : const Color(0xFFFFD54A), 3);
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2 + t * 0.25;
      c.drawLine(
        Offset(sx + math.cos(a) * sr * 1.35, sy + math.sin(a) * sr * 1.35),
        Offset(sx + math.cos(a) * sr * 1.75, sy + math.sin(a) * sr * 1.75),
        ray,
      );
    }
    c.drawCircle(Offset(sx, sy), sr, Paint()..color = rise ? const Color(0xFFFFC24D) : const Color(0xFFFFD54A));
    c.drawCircle(Offset(sx - sr * 0.3, sy - sr * 0.3), sr * 0.35, Paint()..color = const Color(0x59FFFFFF));
    if (rise) {
      // 해가 걸친 언덕
      c.drawPath(
        Path()
          ..moveTo(x, y + h)
          ..quadraticBezierTo(x + w * 0.25, y + h * 0.72, x + w * 0.5, y + h * 0.86)
          ..quadraticBezierTo(x + w * 0.78, y + h * 0.98, x + w, y + h * 0.8)
          ..lineTo(x + w, y + h)
          ..close(),
        Paint()..color = const Color(0xFF9ED28E),
      );
      c.drawPath(
        Path()
          ..moveTo(x, y + h * 0.95)
          ..quadraticBezierTo(x + w * 0.4, y + h * 0.86, x + w * 0.7, y + h)
          ..lineTo(x, y + h)
          ..close(),
        Paint()..color = const Color(0xFF86C477),
      );
    }
    final cx = x + w * (rise ? 0.22 : 0.24) + math.sin(t * 0.2) * w * 0.05;
    final cy = y + h * (rise ? 0.3 : 0.62);
    final cloud = Paint()..color = const Color(0xF2FFFFFF);
    c.drawCircle(Offset(cx, cy), w * 0.09, cloud);
    c.drawCircle(Offset(cx + w * 0.08, cy - h * 0.05), w * 0.108, cloud);
    c.drawCircle(Offset(cx + w * 0.18, cy), w * 0.081, cloud);
    c.restore();
    final frame = dim ? const Color(0xFFC9CFDA) : const Color(0xFFFFFFFF);
    c.drawRRect(glass, _line(frame, 6));
    final bar = _line(frame, 4);
    c.drawLine(Offset(x + w / 2, y), Offset(x + w / 2, y + h), bar);
    c.drawLine(Offset(x, y + h / 2), Offset(x + w, y + h / 2), bar);
    _rr(c, x - 10, y + h, w + 20, 9, 4, frame);

    // 커튼 봉
    final (base, fold, tie) = colors;
    c.drawLine(Offset(x - 18, y - 12), Offset(x + w + 18, y - 12), _line(const Color(0xFFB57A4B), 4));
    c.drawCircle(Offset(x - 20, y - 12), 5, Paint()..color = const Color(0xFFB57A4B));
    c.drawCircle(Offset(x + w + 20, y - 12), 5, Paint()..color = const Color(0xFFB57A4B));
    final top = y - 12;
    final bot = y + h + 22;
    final foldLine = _line(fold, 2);
    // 닫힌 커튼 한 폭: [from] 벽 쪽 → [to] 창 가운데 쪽
    void closed(double from, double to) {
      final dir = (to - from).sign;
      final path = Path()
        ..moveTo(from, top)
        ..lineTo(to, top);
      for (var i = 0; i <= 8; i++) {
        path.lineTo(to + math.sin(i * 1.3 + t * 0.8) * 3 * dir, top + (bot - top) * i / 8);
      }
      for (var i = 0; i <= 6; i++) {
        path.lineTo(to - (to - from) * i / 6, bot + (i.isOdd ? 6 : 0));
      }
      path.close();
      c.drawPath(path, Paint()..color = base);
      for (var i = 1; i < 4; i++) {
        final fx = from + (to - from) * i / 4;
        c.drawPath(
          Path()
            ..moveTo(fx, top + 4)
            ..quadraticBezierTo(fx + 4, (top + bot) / 2, fx - 2, bot),
          foldLine,
        );
      }
    }

    // 묶어서 걷은 커튼 한 폭: [side] -1 왼쪽, 1 오른쪽
    void open(double side) {
      final ox = side < 0 ? x - 14 : x + w + 14;
      final ix = side < 0 ? x + w * 0.1 : x + w - w * 0.1;
      final mid = y + h * 0.55;
      c.drawPath(
        Path()
          ..moveTo(ox, top)
          ..lineTo(ix, top)
          ..quadraticBezierTo(ix - side * w * 0.04, y + h * 0.3, ox - side * (w * 0.02 + 2), mid)
          ..quadraticBezierTo(ox - side * 14, bot - 6, ox, bot)
          ..close(),
        Paint()..color = base,
      );
      c.drawPath(
        Path()
          ..moveTo((ox + ix) / 2, top + 4)
          ..quadraticBezierTo((ox + ix) / 2, y + h * 0.3, ox - side * 6, mid),
        foldLine,
      );
      _rr(c, side < 0 ? x - 16 : x + w - 4, mid - 4, 20, 7, 3, tie);
    }

    switch (curtains) {
      case _Curtains.open:
        open(-1);
        open(1);
      case _Curtains.half:
        closed(x - 14, x + w * 0.52);
        open(1);
      case _Curtains.closed:
        closed(x - 14, x + w / 2 + 2);
        closed(x + w + 14, x + w / 2 - 2);
    }
  }

  /// 다크 모드: 방을 어둡게 덮는다 (창문·오리·조명은 이 위에 그려 밝게 남긴다).
  static void _dim(Canvas c, _PoolGeo g, double alpha) {
    c.drawRect(Offset.zero & g.size, Paint()..color = const Color(0xFF0E162C).withValues(alpha: alpha));
  }

  // ------------------------------------------------------------ 아침 방 (50% 미만)

  /// 이제 막 일어난 아침: 침대 앞에서 파자마·잠옷 모자 오리가 베개를 끌고 멀뚱멀뚱 서 있다.
  /// 라이트: 커튼 양쪽 열림 + 막 뜬 해 / 다크: 어두운 방, 커튼 한쪽만 열림 + 막 뜬 해.
  static void _paintMorning(Canvas c, _PoolGeo g, double t, {required bool night}) {
    final w = g.w;
    final h = g.h;
    final ds = g.roomDs;
    final floorTop = h * 0.64;
    final feetY = h * 0.85;
    _room(c, g, floorTop, const Color(0xFFFFF6EA), const Color(0xFFFDE6CF), const Color(0xFFE8C9A2));

    // 침대 (왼쪽 뒤)
    final bx0 = w * 0.03;
    final bx1 = w * 0.58;
    final bb = floorTop + (feetY - floorTop) * 0.36;
    final k = h * 0.01;
    const wood = Color(0xFFC98F5E);
    const woodDark = Color(0xFFA9713F);
    _rrc(c, bx0, bb - k * 30, w * 0.065, k * 30, const Radius.circular(16), const Radius.circular(3), wood, stroke: woodDark);
    _rr(c, bx0 + w * 0.012, bb - k * 26, w * 0.04, k * 8, 6, const Color(0xFFDDA877));
    _rrc(c, bx1 - w * 0.05, bb - k * 15, w * 0.05, k * 15, const Radius.circular(12), const Radius.circular(3), wood, stroke: woodDark);
    for (final lx in <double>[bx0 + w * 0.07, bx1 - w * 0.09]) {
      _rr(c, lx, bb - k * 3, w * 0.025, k * 3, 2, woodDark);
    }
    _rr(c, bx0 + w * 0.04, bb - k * 7.5, bx1 - bx0 - w * 0.07, k * 4.5, 4, const Color(0xFFB57A4B));
    _rr(c, bx0 + w * 0.055, bb - k * 13, bx1 - bx0 - w * 0.095, k * 6.5, 8, const Color(0xFFFFFFFF), stroke: const Color(0xFFE3D6C6), sw: 1.5);
    // 이불: 부풀어 오른 채 흐트러짐 + 접힌 시트
    final t0 = bx0 + w * 0.17;
    final t1 = bx1 - w * 0.04;
    final tw = t1 - t0;
    final quilt = Path()
      ..moveTo(t0, bb - k * 12.5)
      ..quadraticBezierTo(t0 + tw * 0.2, bb - k * 19, t0 + tw * 0.42, bb - k * 16.5)
      ..quadraticBezierTo(t0 + tw * 0.62, bb - k * 14, t0 + tw * 0.78, bb - k * 17)
      ..quadraticBezierTo(t0 + tw * 0.95, bb - k * 19, t1, bb - k * 13)
      ..lineTo(t1 + w * 0.005, bb - k * 4);
    for (var i = 1; i <= 5; i++) {
      final xx = t1 - tw * i / 5;
      quilt.quadraticBezierTo(xx + tw * 0.1, bb - k * (i.isOdd ? 2.2 : 3.8), xx, bb - k * 3.4);
    }
    quilt.close();
    c.drawPath(quilt, Paint()..color = const Color(0xFFFFC2D1));
    c.drawPath(quilt, _line(const Color(0xFFF09AB0), 1.5));
    final dot = Paint()..color = const Color(0xD9FFFFFF);
    for (final d in const <List<double>>[
      <double>[0.2, 13],
      <double>[0.45, 10],
      <double>[0.7, 12],
      <double>[0.88, 8.5],
      <double>[0.33, 6],
      <double>[0.6, 6.5],
    ]) {
      c.drawCircle(Offset(t0 + tw * d[0], bb - k * d[1]), k * 0.9, dot);
    }
    final sheet = Path()
      ..moveTo(t0 - w * 0.035, bb - k * 12)
      ..quadraticBezierTo(t0 - w * 0.01, bb - k * 15, t0 + w * 0.01, bb - k * 12.5)
      ..lineTo(t0 + w * 0.005, bb - k * 3.6)
      ..lineTo(t0 - w * 0.03, bb - k * 4.2)
      ..close();
    c.drawPath(sheet, Paint()..color = const Color(0xFFFFFFFF));
    c.drawPath(sheet, _line(const Color(0xFFE3D6C6), 1.5));
    // 러그
    c.drawOval(
      Rect.fromCenter(center: Offset(w * 0.6, feetY + 2), width: ds * 2.2, height: ds * 0.4),
      Paint()..color = const Color(0x73FFAABE),
    );
    if (night) _dim(c, g, 0.55);

    // 창문 + 햇살
    final wx = w * 0.5;
    final wy = h * 0.15;
    final ww = w * 0.42;
    final wh = h * 0.22;
    final beamL = night ? wx + ww * 0.55 : wx + ww * 0.15;
    final beamR = wx + ww * 0.95;
    c.drawPath(
      Path()
        ..moveTo(beamL, wy + wh)
        ..lineTo(beamR, wy + wh)
        ..lineTo(beamR - ww * 0.55, feetY)
        ..lineTo(beamL - ww * 0.6, feetY)
        ..close(),
      Paint()..color = night ? const Color(0x29FFD296) : const Color(0x66FFECC8),
    );
    _window(
      c,
      wx,
      wy,
      ww,
      wh,
      t,
      sun: _Sun.rise,
      curtains: night ? _Curtains.half : _Curtains.open,
      colors: night
          ? (const Color(0xFFB9728A), const Color(0x73784B4B), const Color(0xFF9A5570))
          : (const Color(0xFFFF9FB2), const Color(0x73D65C7A), const Color(0xFFE76F8E)),
      dim: night,
    );

    // 오리
    final dx = w * 0.66;
    final dy = feetY - ds * 0.455;
    c.drawOval(
      Rect.fromCenter(center: Offset(dx - ds * 0.1, feetY + 3), width: ds, height: ds * 0.14),
      Paint()..color = const Color(0x14000000),
    );
    paintDuck(
      c,
      Offset(dx, dy),
      ds,
      time: t,
      look: DuckLook(
        feet: true,
        pajamas: true,
        nightcap: true,
        bedhead: true,
        sleepy: true,
        pillow: true,
        wing: DuckWing.down,
        blink: (t % 5) < 0.18,
        tilt: math.sin(t * 1.1) * 0.025,
      ),
    );
  }

  // ------------------------------------------------------------ 책상 (50% 이상)

  /// POOL PARTY 사진 액자 (책상 장면 벽, 시계 자리).
  static void _photo(Canvas c, double x, double y, double w, double h) {
    final string = _line(const Color(0xFF8A6A4F), 1.5);
    c.drawLine(Offset(x + w * 0.2, y), Offset(x + w / 2, y - h * 0.22), string);
    c.drawLine(Offset(x + w / 2, y - h * 0.22), Offset(x + w * 0.8, y), string);
    c.drawCircle(Offset(x + w / 2, y - h * 0.22), 3, Paint()..color = const Color(0xFF8A6A4F));
    c.save();
    c.translate(x + w / 2, y + h / 2);
    c.rotate(-0.03);
    _rr(c, -w / 2, -h / 2, w, h, 6, const Color(0xFFC98F5E), stroke: const Color(0xFFA9713F));
    _rr(c, -w / 2 + 6, -h / 2 + 6, w - 12, h - 12, 3, const Color(0xFFFFFFFF));
    final px = -w / 2 + 11;
    final py = -h / 2 + 11;
    final pw = w - 22;
    final ph = h - 22;
    final ds = math.min(pw * 0.55, ph * 0.62);
    final pic = Rect.fromLTWH(px, py, pw, ph);
    c.save();
    c.clipRect(pic);
    c.drawRect(
      pic,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF7FD3F7), Color(0xFF3E9FE6)],
        ).createShader(pic),
    );
    final wave = _line(const Color(0x66FFFFFF), 1.2);
    for (var i = 0; i < 4; i++) {
      final yy = py + ph * (0.2 + i * 0.22);
      final xx = px + pw * ((i * 0.37) % 1);
      c.drawPath(
        Path()
          ..moveTo(xx, yy)
          ..quadraticBezierTo(xx + 6, yy - 3, xx + 12, yy),
        wave,
      );
    }
    final center = Offset(px + pw * 0.5, py + ph * 0.6);
    void ring(bool front) {
      final rect = Rect.fromCenter(center: center + Offset(0, ds * 0.16), width: ds * 1.12, height: ds * 0.4);
      for (var i = 0; i < 8; i++) {
        final a0 = i / 8 * math.pi * 2;
        final a1 = (i + 1) / 8 * math.pi * 2;
        if ((math.sin((a0 + a1) / 2) > 0) != front) continue;
        c.drawArc(
          rect,
          a0,
          a1 - a0,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ds * 0.14
            ..color = i.isOdd ? const Color(0xFFFFFFFF) : const Color(0xFFFF6F91),
        );
      }
    }

    ring(false);
    paintDuck(c, center, ds, look: const DuckLook(shades: true));
    ring(true);
    _ball(c, Offset(px + pw * 0.85, py + ph * 0.28), ds * 0.2, 0);
    c.restore();
    c.drawPath(
      Path()
        ..moveTo(px, py)
        ..lineTo(px + pw * 0.45, py)
        ..lineTo(px, py + ph * 0.6)
        ..close(),
      Paint()..color = const Color(0x2EFFFFFF),
    );
    c.restore();
  }

  /// 책상에서 일하는 오리. 오리·의자·책상·노트북·커피·책·스탠드를 모두 **옆에서 본 시점**으로 맞췄다.
  /// 라이트: 커튼 양쪽 열림 + 중천의 해(오후) / 다크: 커튼 모두 닫힘, 스탠드와 노트북 불빛.
  static void _paintWork(Canvas c, _PoolGeo g, double t, {required bool night}) {
    final w = g.w;
    final h = g.h;
    final ds = math.min(w * 0.32, h * 0.19);
    final k = ds / 100;
    final floorTop = h * 0.66;
    final floorY = h * 0.88;
    final deskTop = h * 0.62;
    _room(c, g, floorTop, const Color(0xFFEEF4FB), const Color(0xFFE1EBF6), const Color(0xFFD9C2A3));
    final wx = w * 0.06;
    final wy = h * 0.14;
    final ww = w * 0.36;
    final wh = h * 0.19;
    if (!night) {
      c.drawPath(
        Path()
          ..moveTo(wx + ww * 0.15, wy + wh)
          ..lineTo(wx + ww * 0.9, wy + wh)
          ..lineTo(wx + ww * 1.05, floorY)
          ..lineTo(wx + ww * 0.35, floorY)
          ..close(),
        Paint()..color = const Color(0x59FFF5D7),
      );
    }
    _window(
      c,
      wx,
      wy,
      ww,
      wh,
      t,
      sun: _Sun.noon,
      curtains: night ? _Curtains.closed : _Curtains.open,
      colors: night
          ? (const Color(0xFF5E7FA6), const Color(0x801E3250), const Color(0xFF4A6A90))
          : (const Color(0xFF9CC3EA), const Color(0x664678B4), const Color(0xFF6E9AD6)),
      dim: night,
    );
    // 선반 + 화분 + 책
    final shX = w * 0.56;
    final shY = h * 0.36;
    _rr(c, shX, shY, w * 0.38, 8, 3, const Color(0xFFC98F5E));
    _rrc(c, shX + w * 0.04, shY - 22, 22, 22, const Radius.circular(3), const Radius.circular(8), const Color(0xFFFF9A6B));
    final leaf = Paint()..color = const Color(0xFF7BD389);
    for (final l in const <Offset>[Offset(-8, -10), Offset(0, -18), Offset(8, -11)]) {
      c.save();
      c.translate(shX + w * 0.04 + 11 + l.dx, shY - 22 + l.dy);
      c.rotate(l.dx * 0.08);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 22), leaf);
      c.restore();
    }
    const shelfBooks = <(Color, double)>[(Color(0xFF64B5F6), 30.0), (Color(0xFFFFB74D), 26.0), (Color(0xFF7BD389), 32.0)];
    for (var i = 0; i < shelfBooks.length; i++) {
      final (col, bh) = shelfBooks[i];
      _rr(c, shX + w * 0.25 + i * 13, shY - bh, 11, bh, 2, col);
    }
    // POOL PARTY 사진 액자 (시계 자리)
    final fw = math.min(w * 0.24, h * 0.17);
    _photo(c, w * 0.73 - fw / 2, h * 0.13, fw, fw * 0.8);
    if (night) _dim(c, g, 0.6);

    final dx = w * 0.24;
    final dy = deskTop - 12 * k;
    final x1 = math.min(w * 0.97, dx + 216 * k);
    final lampX = dx + 196 * k;
    final lampFits = lampX + 14 * k < x1;
    // 스탠드 불빛 (다크)
    if (night && lampFits) {
      final glowAt = Offset(lampX - 30 * k, deskTop);
      c.drawRect(
        Offset.zero & g.size,
        Paint()
          ..shader = RadialGradient(
            colors: const <Color>[Color(0x8CFFD68C), Color(0x00FFD68C)],
            stops: const <double>[0.06, 1],
          ).createShader(Rect.fromCircle(center: glowAt, radius: 170 * k)),
      );
    }
    // 의자 (옆모습: 등받이 + 방석 + 기둥 + 바퀴)
    const chair = Color(0xFF6E9AD6);
    const chairLine = Color(0xFF557FBA);
    const metal = Color(0xFF8899AA);
    c.save();
    c.translate(dx - 52 * k, dy + 36 * k);
    c.rotate(-0.1);
    _rr(c, -6 * k, -72 * k, 13 * k, 74 * k, 6 * k, chair, stroke: chairLine);
    c.restore();
    _rr(c, dx - 58 * k, dy + 34 * k, 88 * k, 10 * k, 5 * k, chair, stroke: chairLine);
    _rr(c, dx - 12 * k, dy + 44 * k, 7 * k, math.max(0.0, floorY - dy - 44 * k - 10), 2, metal);
    _rr(c, dx - 44 * k, floorY - 12, 70 * k, 6, 3, metal);
    for (final wheel in <double>[dx - 40 * k, dx + 22 * k]) {
      c.drawCircle(Offset(wheel, floorY - 4), 5, Paint()..color = const Color(0xFF5B6B7C));
    }
    // 오리 (앞으로 뻗은 날개는 노트북을 그린 뒤 따로)
    final look = DuckLook(tie: true, glasses: true, wing: DuckWing.forward, blink: (t % 4) < 0.12);
    paintDuck(c, Offset(dx, dy), ds, time: t, look: look, part: DuckPart.body);
    // 책상 (옆모습: 상판 + 다리 + 가로대)
    final deskX0 = dx + 26 * k;
    final legH = floorY - deskTop;
    for (final lx in <double>[deskX0 + 4 * k, x1 - 12 * k]) {
      _rr(c, lx, deskTop + 6 * k, 7 * k, math.max(0.0, legH - 6 * k), 2, const Color(0xFFA9713F));
    }
    _rr(c, deskX0 + 8 * k, deskTop + legH * 0.72, x1 - deskX0 - 18 * k, 5 * k, 2, const Color(0xFFB57A4B));
    _rr(c, deskX0, deskTop, x1 - deskX0, 7 * k, 3, const Color(0xFFDDA877), stroke: const Color(0xFFB57A4B), sw: 1.5);
    // 노트북 (옆모습: 바닥판 + 오리 쪽을 향해 열린 화면)
    if (night) {
      c.drawPath(
        Path()
          ..moveTo(dx + 100 * k, deskTop - 6 * k)
          ..lineTo(dx + 112 * k, deskTop - 52 * k)
          ..lineTo(dx + 10 * k, dy - 50 * k)
          ..lineTo(dx + 14 * k, dy - 4 * k)
          ..close(),
        Paint()..color = const Color(0x3896C8FF),
      );
    }
    _rr(c, dx + 44 * k, deskTop - 4 * k, 62 * k, 4 * k, 2 * k, const Color(0xFFC9D3E0), stroke: const Color(0xFF9FB0C6), sw: 1.2);
    final lid = Path()
      ..moveTo(dx + 100 * k, deskTop - 4 * k)
      ..lineTo(dx + 107 * k, deskTop - 4 * k)
      ..lineTo(dx + 120 * k, deskTop - 54 * k)
      ..lineTo(dx + 113 * k, deskTop - 56 * k)
      ..close();
    c.drawPath(lid, Paint()..color = const Color(0xFFAEB9C9));
    c.drawPath(lid, _line(const Color(0xFF8D9AAE), 1.5));
    c.drawLine(
      Offset(dx + 101 * k, deskTop - 7 * k),
      Offset(dx + 113.5 * k, deskTop - 53 * k),
      _line(night ? const Color(0xFFBFE3FF) : const Color(0xFF8FD0FF), 2.2),
    );
    c.drawCircle(Offset(dx + 110 * k, deskTop - 30 * k), 2.2 * k, Paint()..color = const Color(0xFFFF8FA8));
    // 커피 (김이 모락모락)
    final mx = dx + 128 * k;
    _rrc(c, mx - 8 * k, deskTop - 20 * k, 16 * k, 20 * k, Radius.circular(2 * k), Radius.circular(5 * k), const Color(0xFFFFFFFF),
        stroke: const Color(0xFFC9D3E0), sw: 1.5);
    _rr(c, mx - 8 * k, deskTop - 14 * k, 16 * k, 4 * k, 0, const Color(0xFFFF9A6B));
    c.drawArc(Rect.fromCircle(center: Offset(mx + 9 * k, deskTop - 10 * k), radius: 5 * k), -1.3, 2.6, false,
        _line(const Color(0xFFC9D3E0), 3 * k));
    final steam = _line(const Color(0x99A0AABE), 2);
    for (var i = 0; i < 2; i++) {
      final o = i == 0 ? -3.0 : 3.0;
      final path = Path();
      for (var j = 0; j <= 10; j++) {
        final yy = deskTop - 23 * k - j * 2.4 * k;
        final xx = mx + o * k + math.sin(j * 0.8 + t * 3 + i) * 2.5 * k;
        if (j == 0) {
          path.moveTo(xx, yy);
        } else {
          path.lineTo(xx, yy);
        }
      }
      c.drawPath(path, steam);
    }
    // 책 (책등이 보이게 쌓음)
    const books = <(Color, double)>[(Color(0xFF7BD389), 36.0), (Color(0xFFFFB74D), 32.0), (Color(0xFF64B5F6), 34.0)];
    for (var i = 0; i < books.length; i++) {
      final (col, bw) = books[i];
      final by = deskTop - (i + 1) * 8 * k;
      final bx = dx + 144 * k + (i.isOdd ? 3 * k : 0);
      _rr(c, bx, by, bw * k, 8 * k, 2, col, stroke: const Color(0x26000000), sw: 1);
      _rr(c, bx + 4 * k, by + 3 * k, bw * k - 8 * k, 1.6 * k, 1, const Color(0xB3FFFFFF));
    }
    // 스탠드 (다크 모드에서는 켜짐)
    if (lampFits) {
      const ink = Color(0xFF2E3A55);
      c.drawOval(Rect.fromCenter(center: Offset(lampX, deskTop - 2 * k), width: 22 * k, height: 6 * k), Paint()..color = ink);
      c.drawPath(
        Path()
          ..moveTo(lampX, deskTop - 3 * k)
          ..lineTo(lampX - 4 * k, deskTop - 40 * k)
          ..lineTo(lampX - 22 * k, deskTop - 56 * k),
        _line(ink, 3 * k),
      );
      c.save();
      c.translate(lampX - 22 * k, deskTop - 56 * k);
      c.rotate(-0.5);
      c.drawPath(
        Path()
          ..moveTo(-12 * k, 10 * k)
          ..lineTo(12 * k, 10 * k)
          ..lineTo(5 * k, -4 * k)
          ..lineTo(-5 * k, -4 * k)
          ..close(),
        Paint()..color = night ? const Color(0xFFFFD27A) : const Color(0xFFFF9A6B),
      );
      c.restore();
      if (night) {
        c.drawPath(
          Path()
            ..moveTo(lampX - 30 * k, deskTop - 50 * k)
            ..lineTo(lampX - 22 * k, deskTop - 44 * k)
            ..lineTo(lampX - 20 * k, deskTop)
            ..lineTo(lampX - 78 * k, deskTop)
            ..close(),
          Paint()..color = const Color(0x47FFDC96),
        );
      }
    }
    // 노트북 자판 위 날개 (타닥타닥)
    paintDuck(c, Offset(dx, dy), ds, time: t, look: look, part: DuckPart.frontWing);
  }

  // ------------------------------------------------------------ 수영장 파티 (100%)

  void _paintParty(Canvas canvas, _PoolGeo g, double t) {
    // 100% 수영장은 라이트·다크 모드 같은 화면
    final full = Offset.zero & g.size;
    canvas.drawRect(full, Paint()..color = const Color(0xFFD7F0FB));
    final grid = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x3850A0C8);
    for (var gx = 0.0; gx < g.w; gx += 24) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, g.h), grid);
    }
    for (var gy = 0.0; gy < g.h; gy += 24) {
      canvas.drawLine(Offset(0, gy), Offset(g.w, gy), grid);
    }
    canvas.drawRect(
      Rect.fromLTWH(g.w * 0.5 - 3, 0, 6, g.h),
      Paint()..color = const Color(0x1A2F7BFF),
    );
    // 화면 가득 찬 물
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x8C5CCCF5), Color(0x8C288CE1)],
        ).createShader(full),
    );
    final ripple = _line(const Color(0x59FFFFFF), 1.6);
    final depth = math.max(10.0, g.h - 20);
    for (var i = 0; i < 14; i++) {
      final yy = 18 + ((i * 53 + t * 9) % depth);
      final xx = (i * 83.0) % g.w;
      canvas.drawPath(
        Path()
          ..moveTo(xx, yy)
          ..quadraticBezierTo(xx + 10, yy - 4 + math.sin(t * 2 + i) * 2, xx + 22, yy),
        ripple,
      );
    }
    final bubble = _line(const Color(0x8CFFFFFF), 1.2);
    for (var i = 0; i < 12; i++) {
      final by = g.h - ((t * 28 + i * 97) % (g.h + 20));
      final bx = (i * 73.3) % g.w + math.sin(t * 1.3 + i) * 6;
      canvas.drawCircle(Offset(bx, by), 2.0 + i % 3, bubble);
    }

    final ds = g.ds;
    final tilt = (sim.vx * 0.03).clamp(-0.22, 0.22).toDouble();
    final ringCenter = Offset(sim.x, sim.y + ds * 0.16);
    // 칵테일: 오리와 따로 천천히 떠다닌다
    _cocktail(
      canvas,
      Offset(
        g.w * 0.3 + math.sin(t * 0.31) * g.w * 0.2,
        (g.minY + g.maxY) / 2 + math.sin(t * 0.23 + 2) * (g.maxY - g.minY) * 0.4,
      ),
      math.sin(t * 1.3) * 0.12,
    );
    // 튜브 뒤쪽 → 오리 → 튜브 앞쪽
    _ring(canvas, ringCenter, ds, tilt, front: false);
    paintDuck(
      canvas,
      Offset(sim.x, sim.y),
      ds,
      time: t,
      look: DuckLook(shades: true, blink: (t % 4) < 0.12, flip: sim.vx < -0.3, tilt: tilt),
    );
    _ring(canvas, ringCenter, ds, tilt, front: true);
    _ball(canvas, Offset(sim.bx, sim.by), g.ballR, sim.spin);
    // 반짝이
    const colors = <Color>[Color(0xFFFFD54A), Color(0xFFFF6F91), Color(0xFF7BD389), Color(0xFFFFFFFF)];
    for (var i = 0; i < 10; i++) {
      final a = t * 1.5 + i;
      final sx = (i * 97.0 + t * 14) % g.w;
      final sy = g.minY + ((i * 151.0 + t * 6) % math.max(1.0, g.maxY - g.minY));
      final r = 2.5 + 1.5 * math.sin(a * 2).abs();
      final p = _line(colors[i % 4].withValues(alpha: 0.4 + 0.5 * math.sin(a * 2).abs()), 1.6);
      canvas.drawLine(Offset(sx - r, sy), Offset(sx + r, sy), p);
      canvas.drawLine(Offset(sx, sy - r), Offset(sx, sy + r), p);
    }
  }

  /// 빨강·노랑·파랑·흰 조각 비치볼 (굴러가는 만큼 돈다).
  static void _ball(Canvas canvas, Offset c, double r, double spin) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    const cols = <Color>[
      Color(0xFFFF5D5D),
      Color(0xFFFFFFFF),
      Color(0xFFFFD54A),
      Color(0xFFFFFFFF),
      Color(0xFF4CA8FF),
      Color(0xFFFFFFFF),
    ];
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    for (var i = 0; i < 6; i++) {
      canvas.drawArc(rect, i / 6 * math.pi * 2, math.pi / 3, true, Paint()..color = cols[i]);
    }
    canvas.drawCircle(Offset.zero, r * 0.2, Paint()..color = const Color(0xFFFFFFFF));
    canvas.restore();
    canvas.drawCircle(c, r, _line(const Color(0x592E3A55), 1.5));
    canvas.save();
    canvas.translate(c.dx - r * 0.35, c.dy - r * 0.4);
    canvas.rotate(-0.6);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.5, height: r * 0.28), Paint()..color = const Color(0x8CFFFFFF));
    canvas.restore();
  }

  /// 분홍·흰 줄무늬 튜브. 뒤쪽 반을 먼저, 앞쪽 반을 오리 다음에 그려 오리가 튜브 안에 들어간 것처럼 보인다.
  void _ring(Canvas canvas, Offset c, double ds, double tilt, {required bool front}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final rect = Rect.fromCenter(center: Offset.zero, width: ds * 1.12, height: ds * 0.4);
    const seg = 8;
    for (var i = 0; i < seg; i++) {
      final a0 = i / seg * math.pi * 2;
      final a1 = (i + 1) / seg * math.pi * 2;
      final isFront = math.sin((a0 + a1) / 2) > 0;
      if (isFront != front) continue;
      canvas.drawArc(
        rect,
        a0,
        a1 - a0,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ds * 0.14
          ..color = i.isOdd ? const Color(0xFFFFFFFF) : const Color(0xFFFF6F91),
      );
    }
    canvas.restore();
  }

  void _cocktail(Canvas canvas, Offset c, double rot) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    final fill = Paint();
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 4), width: 36, height: 12), fill..color = const Color(0xFFFFFFFF));
    final glass = Path()
      ..moveTo(-14, -26)
      ..lineTo(14, -26)
      ..lineTo(2, -8)
      ..lineTo(2, 2)
      ..lineTo(-2, 2)
      ..lineTo(-2, -8)
      ..close();
    canvas.drawPath(glass, fill..color = const Color(0xD9FFFFFF));
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF9FD7EE),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-11, -23)
        ..lineTo(11, -23)
        ..lineTo(1, -11)
        ..lineTo(-1, -11)
        ..close(),
      fill..color = const Color(0xFFFF9A6B),
    );
    canvas.drawLine(
      const Offset(4, -22),
      const Offset(12, -38),
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFFFF5D8F),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-14, -34)
        ..quadraticBezierTo(-4, -46, 6, -34)
        ..close(),
      fill..color = const Color(0xFFFF5D8F),
    );
    canvas.drawLine(
      const Offset(-4, -34),
      const Offset(-6, -22),
      Paint()
        ..strokeWidth = 1.2
        ..color = const Color(0xFFB23A6A),
    );
    canvas.drawCircle(const Offset(9, -27), 3.5, fill..color = const Color(0xFF7BD389));
    canvas.restore();
  }
}
