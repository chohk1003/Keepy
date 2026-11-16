import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'fx.dart';

/// 빈 상태 안내 (UI설계서 06) — 떠다니는 그라데이션 아이콘
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.title = '할 일 없음', this.hint = '아래에서 추가'});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Motion.spring,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Floating(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: K.brand,
                borderRadius: BorderRadius.circular(26),
                boxShadow: K.glow(K.indigo, a: 0.35, blur: 26),
              ),
              child: const Icon(
                CupertinoIcons.checkmark_alt,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: T.title3),
          const SizedBox(height: 6),
          Text(hint, style: T.footnote),
          const SizedBox(height: 10),
          const Floating(
            amplitude: 3,
            child: Icon(CupertinoIcons.chevron_down, size: 18, color: K.label3),
          ),
        ],
      ),
    );
  }
}
