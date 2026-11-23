import 'package:flutter/material.dart';

import '../theme.dart';

/// 상태·태그를 나타내는 작은 알약 (서윤님 `basics.dart` 의 Pill).
///
/// 글자 색만 주면 바탕은 그 색 12%로 깔린다. [gradient] 를 주면 글자는 흰색.
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color,
    this.background,
    this.gradient,
  });

  final String label;
  final Color? color;
  final Color? background;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final fg = gradient != null ? Colors.white : (color ?? K.label2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient != null
            ? null
            : (background ?? fg.withValues(alpha: .12)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: T.caption.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
