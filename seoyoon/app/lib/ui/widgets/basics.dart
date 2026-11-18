import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/shadows.dart';
import '../../core/theme.dart';

/// 그라데이션 글자 (오늘 날짜 숫자, 로고 점, 활성 탭 등).
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, this.gradient = KeepyGradients.primary});

  final String text;
  final TextStyle style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, style: style),
    );
  }
}

/// 그라데이션 아이콘.
class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, this.size = 24, this.gradient = KeepyGradients.primary});

  final IconData icon;
  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

/// 누르면 살짝 작아지는 애플식 눌림 피드백.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      onTap: active ? widget.onTap : null,
      onLongPress: active ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: KeepyMotion.fast,
        curve: KeepyMotion.settle,
        child: widget.child,
      ),
    );
  }
}

/// 흰 카드 바탕.
class KeepyCard extends StatelessWidget {
  const KeepyCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// null 이면 모드에 맞는 카드 색.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? KeepyColors.card,
        borderRadius: BorderRadius.circular(KeepyRadius.card),
        border: Border.all(color: KeepyColors.hairline, width: 0.8),
        boxShadow: cardShadow(0),
      ),
      child: child,
    );
  }
}

/// 둥근 네모 체크박스 (prompts_log #3: 원형 대신 네모).
class KeepyCheckbox extends StatelessWidget {
  const KeepyCheckbox({
    super.key,
    required this.checked,
    this.onTap,
    this.size = 24,
    this.warning = false,
  });

  final bool checked;
  final VoidCallback? onTap;
  final double size;

  /// 지연 상태면 테두리를 주황으로.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: KeepyMotion.fast,
      curve: KeepyMotion.settle,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: checked ? KeepyGradients.primary : null,
        color: checked ? null : KeepyColors.card,
        border: checked
            ? null
            : Border.all(
                color: warning ? KeepyColors.orange : KeepyColors.tertiaryLabel,
                width: 1.6,
              ),
      ),
      child: AnimatedScale(
        scale: checked ? 1 : 0.4,
        duration: KeepyMotion.normal,
        curve: KeepyMotion.pop, // 위치·스케일에만 되튐 사용
        child: AnimatedOpacity(
          opacity: checked ? 1 : 0,
          duration: KeepyMotion.fast,
          child: Icon(CupertinoIcons.checkmark_alt, size: size * 0.72, color: Colors.white),
        ),
      ),
    );
    if (onTap == null) return Padding(padding: const EdgeInsets.all(10), child: box);
    return Semantics(
      checked: checked,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: box),
      ),
    );
  }
}

/// 작은 알약 배지 (오늘 / 지연 / 늦은 완료 / 날짜).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = KeepyColors.blue, this.background, this.gradient});

  final String text;
  final Color color;
  final Color? background;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: gradient == null ? (background ?? color.withValues(alpha: 0.1)) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: gradient == null ? color : Colors.white,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// keepy 로고 (글자 + 그라데이션 점).
class KeepyLogo extends StatelessWidget {
  const KeepyLogo({super.key, this.size = 23});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          'keepy',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: KeepyColors.label,
            height: 1,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 2, bottom: size * 0.12),
          child: Container(
            width: size * 0.24,
            height: size * 0.24,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: KeepyGradients.primary),
          ),
        ),
      ],
    );
  }
}

/// 계정 동그라미 (K).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initial, this.size = 32});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[
            KeepyColors.blue.withValues(alpha: 0.14),
            KeepyColors.sky.withValues(alpha: 0.14),
          ],
        ),
      ),
      child: GradientText(
        initial,
        style: TextStyle(fontSize: size * 0.44, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 개수 배지 (제목 옆 숫자).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: KeepyMotion.fast,
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
      child: Container(
        key: ValueKey<int>(count),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: KeepyColors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: GradientText('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// 섹션 머리 (해야 할 일 4).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.count, this.trailing, this.color});
  final String title;
  final int? count;
  final Widget? trailing;

  /// null 이면 모드에 맞는 보조 글자색.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? KeepyColors.secondaryLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: <Widget>[
          Text(title, style: KeepyText.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
          if (count != null) ...<Widget>[
            const SizedBox(width: 6),
            Text('$count', style: KeepyText.caption.copyWith(color: color.withValues(alpha: 0.7))),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 빈 상태 안내 (UI 설계서 06, FR-06).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title = '등록된 태스크가 없습니다',
    this.message = '기억하고 싶은 할 일이 있나요?\n아래에서 첫 태스크를 추가해 보세요',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  KeepyColors.blue.withValues(alpha: 0.12),
                  KeepyColors.sky.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: const Center(child: GradientIcon(CupertinoIcons.checkmark_alt, size: 28)),
          ),
          const SizedBox(height: 18),
          Text(title, style: KeepyText.headline, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: KeepyText.caption.copyWith(height: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// 그라데이션 큰 버튼 (OCR '선택한 N개 추가', 저장 등).
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.onPressed, this.gradient = KeepyGradients.primary});
  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PressScale(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: KeepyMotion.fast,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled ? glowShadow(KeepyColors.blue) : null,
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
        ),
      ),
    );
  }
}
