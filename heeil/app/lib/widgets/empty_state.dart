import 'package:flutter/cupertino.dart';

import '../theme.dart';
import 'fx.dart';

/// 빈 상태 안내 (UI설계서 06) — 서윤님 구현처럼 작은 아이콘 상자 + 두 줄 안내
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title = '할 일 없음',
    this.message = '아래에서 추가해 보세요',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.chart,
      curve: Motion.out,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Floating(
              amplitude: 4,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      K.blue.withValues(alpha: .14),
                      K.duck.withValues(alpha: .5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 28,
                  color: K.blue,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: T.headline, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: T.caption.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
