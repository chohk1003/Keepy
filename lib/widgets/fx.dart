import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 누르면 살짝 작아졌다가 스프링으로 돌아오는 래퍼
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : Motion.med,
        curve: _down ? Curves.easeOut : Motion.spring,
        child: widget.child,
      ),
    );
  }
}

/// 그라데이션 글자
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, this.gradient = K.brand});

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => gradient.createShader(Offset.zero & r.size),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// 반투명 블러 유리
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 0,
    this.opacity = 0.78,
    this.blur = 24,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final double opacity;
  final double blur;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: r,
            border: border
                ? Border.all(color: Colors.white.withValues(alpha: 0.7), width: 0.8)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 천천히 흐르는 그라데이션 배경
class LivingGradient extends StatefulWidget {
  const LivingGradient({
    super.key,
    required this.colors,
    this.radius = 24,
    this.child,
    this.period = const Duration(seconds: 7),
  });

  final List<Color> colors;
  final double radius;
  final Widget? child;
  final Duration period;

  @override
  State<LivingGradient> createState() => _LivingGradientState();
}

class _LivingGradientState extends State<LivingGradient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 0.8, -1),
              end: Alignment(1, 1 - t * 0.8),
              colors: widget.colors,
            ),
            boxShadow: K.glow(widget.colors[1 % widget.colors.length], a: 0.32, blur: 24),
          ),
          child: Stack(
            children: [
              // 움직이는 하이라이트
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
                      gradient: RadialGradient(
                        center: Alignment(0.9 - t * 1.4, -0.9 + t * 0.4),
                        radius: 1.1,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ?child,
            ],
          ),
        );
      },
    );
  }
}

/// 그라데이션 진행 링
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 8,
    this.colors = const [Color(0xFF0A84FF), Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
    this.track = K.fill2,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final List<Color> colors;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 750),
      curve: Motion.spring,
      builder: (context, v, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, stroke, colors, track),
          child: Center(child: child),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.colors, this.track);

  final double v;
  final double stroke;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    final p = v.clamp(0.0, 1.06);
    if (p <= 0.001) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [...colors, colors.first],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v || old.stroke != stroke || old.track != track || old.colors != colors;
}

/// 위아래로 천천히 떠다니는 효과
class Floating extends StatefulWidget {
  const Floating({super.key, required this.child, this.amplitude = 6});

  final Widget child;
  final double amplitude;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (Curves.easeInOut.transform(_c.value) - 0.5) * 2 * widget.amplitude),
        child: child,
      ),
    );
  }
}

/// 숫자가 위아래로 굴러가며 바뀌는 텍스트
class RollingText extends StatelessWidget {
  const RollingText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.med,
      switchInCurve: Motion.spring,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, a) {
        final incoming = child.key == ValueKey(text);
        final slide = Tween<Offset>(
          begin: Offset(0, incoming ? 0.6 : -0.6),
          end: Offset.zero,
        ).animate(a);
        return ClipRect(
          child: SlideTransition(
            position: slide,
            child: FadeTransition(opacity: a, child: child),
          ),
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerRight,
        children: [...previous, ?current],
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

/// 목록 아래 끝(입력 바 바로 위) 영역에 들어온 항목을 살짝 줄이고 흐리게 하며 사라지게 함.
/// 이 영역에 들어온 항목은 터치를 받지 않으므로, 여기서 좌우로 밀면 탭이 바뀜
/// (할 일 블럭의 좌우 제스처와 겹치지 않음).
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child});

  final Widget child;

  /// 사라지는 영역 높이 (할 일 블럭 하나 정도)
  static const zone = 72.0;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  ScrollPosition? _pos;
  double _p = 0;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _pos) {
      _pos?.removeListener(_schedule);
      _pos = pos;
      _pos?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(EdgeFade old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  @override
  void dispose() {
    _pos?.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final box = context.findRenderObject();
    final vp = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || vp is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero, ancestor: vp).dy;
    final center = top + box.size.height / 2;
    final zoneTop = vp.size.height - EdgeFade.zone;
    final p = ((center - zoneTop) / EdgeFade.zone).clamp(0.0, 1.0);
    if ((p - _p).abs() > 0.005) setState(() => _p = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    // 트리 모양을 항상 같게 유지 (바뀌면 안쪽 할 일 블럭의 상태가 초기화됨)
    return IgnorePointer(
      ignoring: p > 0.2,
      child: Opacity(
        opacity: (1 - p * 1.1).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1 - 0.08 * p,
          child: ImageFiltered(
            enabled: p > 0,
            imageFilter: ui.ImageFilter.blur(sigmaX: 7 * p, sigmaY: 7 * p),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
