import 'dart:ui' show lerpDouble;

import 'package:flutter/painting.dart';

/// 카드 그림자.
///
/// prompts_log #4: 탄성 곡선 값(1 초과, 0 미만)이 그대로 들어오면
/// blurRadius 가 음수가 되어 오류가 났다. 입력을 0~1로 묶어 어떤 곡선이
/// 들어와도 그림자 값은 항상 0 이상이 되도록 한다.
List<BoxShadow> cardShadow(double elevation) {
  final e = elevation.clamp(0.0, 1.0);
  return <BoxShadow>[
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04 + 0.06 * e),
      blurRadius: lerpDouble(10, 24, e)!,
      offset: Offset(0, lerpDouble(2, 8, e)!),
    ),
  ];
}

/// 그라데이션 버튼 아래 은은한 색 그림자.
List<BoxShadow> glowShadow(Color color, {double strength = 1}) {
  final s = strength.clamp(0.0, 1.0);
  return <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.28 * s),
      blurRadius: 14 * s,
      offset: Offset(0, 5 * s),
    ),
  ];
}
