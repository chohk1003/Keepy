import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../state/task_store.dart';
import 'basics.dart';

/// 선택한 날의 완료율 (UI 설계서 03-1, 설정 '금일 완료율 형태': 바 / 원형 / 그래프).
class CompletionIndicator extends StatelessWidget {
  const CompletionIndicator({
    super.key,
    required this.style,
    required this.stat,
    required this.weekStats,
    required this.selectedIndex,
  });

  final CompletionStyle style;
  final DayStat stat;

  /// 그래프 형태용: 선택한 날이 들어 있는 주(월~일)의 통계.
  final List<DayStat> weekStats;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final percent = (stat.rate * 100).round();
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('완료율', style: KeepyText.caption.copyWith(color: KeepyColors.label, fontWeight: FontWeight.w600)),
        Text('${stat.done} / ${stat.total} 완료', style: KeepyText.footnote),
      ],
    );
    final percentText = GradientText(
      '$percent%',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4),
    );

    return AnimatedSwitcher(
      duration: KeepyMotion.normal,
      child: switch (style) {
        CompletionStyle.bar => Row(
            key: const ValueKey<String>('bar'),
            children: <Widget>[
              label,
              const SizedBox(width: 14),
              Expanded(child: _Bar(rate: stat.rate)),
              const SizedBox(width: 12),
              percentText,
            ],
          ),
        CompletionStyle.ring => Row(
            key: const ValueKey<String>('ring'),
            children: <Widget>[
              _Ring(rate: stat.rate, size: 44),
              const SizedBox(width: 12),
              label,
              const Spacer(),
              percentText,
            ],
          ),
        CompletionStyle.graph => Row(
            key: const ValueKey<String>('graph'),
            children: <Widget>[
              label,
              const SizedBox(width: 14),
              Expanded(child: _WeekGraph(stats: weekStats, selected: selectedIndex)),
              const SizedBox(width: 12),
              percentText,
            ],
          ),
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.rate});
  final double rate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: rate.clamp(0.0, 1.0)),
      duration: KeepyMotion.page,
      curve: KeepyMotion.settle,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, c) => Container(
            height: 8,
            decoration: BoxDecoration(color: KeepyColors.fill, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.centerLeft,
            child: Container(
              width: c.maxWidth * value,
              decoration: BoxDecoration(gradient: KeepyGradients.primary, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.rate, required this.size});
  final double rate;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: rate.clamp(0.0, 1.0)),
      duration: KeepyMotion.page,
      curve: KeepyMotion.settle,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(value),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = KeepyColors.fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..shader = const SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: <Color>[KeepyColors.blue, KeepyColors.sky, KeepyColors.blue],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

class _WeekGraph extends StatelessWidget {
  const _WeekGraph({required this.stats, required this.selected});
  final List<DayStat> stats;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (var i = 0; i < stats.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: KeepyMotion.page,
                      curve: KeepyMotion.settle,
                      height: 4 + 22 * stats[i].rate,
                      decoration: BoxDecoration(
                        gradient: i == selected ? KeepyGradients.primary : null,
                        color: i == selected
                            ? null
                            : (stats[i].total == 0 ? KeepyColors.fill : KeepyColors.blue.withValues(alpha: 0.25)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                        color: i == selected ? KeepyColors.blue : KeepyColors.tertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
