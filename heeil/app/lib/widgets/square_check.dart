import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 네모 체크박스
/// - 누르면 움츠러들고, 체크 시 그라데이션이 차오르며 체크 표시가 그려짐
/// - 체크 순간 입자가 터지는 효과
class SquareCheck extends StatefulWidget {
  const SquareCheck({
    super.key,
    required this.value,
    required this.onTap,
    this.size = 26,
    this.colors = const [Color(0xFF0A84FF), Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
  });

  final bool value;
  final VoidCallback onTap;
  final double size;
  final List<Color> colors;

  @override
  State<SquareCheck> createState() => _SquareCheckState();
}

class _SquareCheckState extends State<SquareCheck> with TickerProviderStateMixin {
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.value ? 1 : 0,
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  bool _pressed = false;

  @override
  void didUpdateWidget(SquareCheck old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (widget.value) {
        _check.forward();
        _burst.forward(from: 0);
      } else {
        _check.reverse();
      }
    }
  }

  @override
  void dispose() {
    _check.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: widget.value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: SizedBox(
          width: 48,
          height: 48,
          child: AnimatedScale(
            scale: _pressed ? 0.78 : 1,
            duration: _pressed ? const Duration(milliseconds: 90) : Motion.slow,
            curve: _pressed ? Curves.easeOut : Motion.spring,
            child: AnimatedBuilder(
              animation: Listenable.merge([_check, _burst]),
              builder: (context, _) => CustomPaint(
                painter: _CheckPainter(
                  t: _check.value,
                  burst: _burst.value,
                  side: widget.size,
                  colors: widget.colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.t,
    required this.burst,
    required this.side,
    required this.colors,
  });

  final double t;
  final double burst;
  final double side;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = side;
    final rect = Rect.fromCenter(center: c, width: s, height: s);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.3));

    // 입자 버스트
    if (burst > 0 && burst < 1) {
      final e = Curves.easeOutCubic.transform(burst);
      final fade = 1 - burst;
      canvas.drawCircle(
        c,
        s * (0.55 + 0.55 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * fade
          ..color = colors[1 % colors.length].withValues(alpha: 0.45 * fade),
      );
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi * 2 / 10 + 0.3;
        final d = s * (0.5 + 0.75 * e) * (i.isEven ? 1 : 0.8);
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * d,
          (i.isEven ? 2.6 : 1.8) * fade,
          Paint()..color = colors[i % colors.length].withValues(alpha: fade),
        );
      }
    }

    // 테두리 (체크될수록 사라짐)
    if (t < 1) {
      canvas.drawRRect(
        rr.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Color.lerp(K.gray3, colors.first, t)!.withValues(alpha: 1 - t * 0.9),
      );
    }

    // 그라데이션 채움 (가운데서 튀어나옴)
    if (t > 0) {
      final grow = Curves.easeOutBack.transform(math.min(1, t * 1.6));
      final fillRect = Rect.fromCenter(center: c, width: s * grow, height: s * grow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, Radius.circular(s * 0.3 * grow)),
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topLeft,
            rect.bottomRight,
            colors,
            _stops(colors.length),
          ),
      );
    }

    // 체크 표시 그리기
    final draw = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    if (draw > 0) {
      final path = Path()
        ..moveTo(rect.left + s * 0.27, rect.top + s * 0.52)
        ..lineTo(rect.left + s * 0.43, rect.top + s * 0.68)
        ..lineTo(rect.left + s * 0.74, rect.top + s * 0.34);
      final out = Path();
      for (final m in path.computeMetrics()) {
        out.addPath(m.extractPath(0, m.length * Curves.easeOut.transform(draw)), Offset.zero);
      }
      canvas.drawPath(
        out,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  static List<double> _stops(int n) =>
      [for (var i = 0; i < n; i++) n == 1 ? 0 : i / (n - 1)];

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.t != t || old.burst != burst || old.side != side || old.colors != colors;
}

/// 제목 위로 취소선이 왼쪽부터 그어지는 텍스트
class StrikeText extends StatelessWidget {
  const StrikeText(
    this.text, {
    super.key,
    required this.struck,
    required this.style,
    this.maxLines = 2,
  });

  final String text;
  final bool struck;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: struck ? 1 : 0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, p, _) {
        final s = style.copyWith(
          color: Color.lerp(style.color ?? K.label, K.label3, p),
        );
        return CustomPaint(
          foregroundPainter: _StrikePainter(text, s, maxLines, p),
          child: Text(
            text,
            style: s,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

class _StrikePainter extends CustomPainter {
  _StrikePainter(this.text, this.style, this.maxLines, this.p);

  final String text;
  final TextStyle style;
  final int maxLines;
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      ellipsis: '\u2026',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final lines = tp.computeLineMetrics();
    tp.dispose();
    final total = lines.fold<double>(0, (a, l) => a + l.width);
    var budget = total * p;
    final paint = Paint()
      ..color = style.color ?? K.label3
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final l in lines) {
      if (budget <= 0) break;
      final w = math.min(budget, l.width);
      final y = l.baseline - l.ascent * 0.32;
      canvas.drawLine(Offset(l.left, y), Offset(l.left + w, y), paint);
      budget -= w;
    }
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.p != p || old.text != text || old.style != style;
}
