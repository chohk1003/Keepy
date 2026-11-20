import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/core/shadows.dart';

/// prompts_log #4 회귀 테스트:
/// 되튐 곡선 값(1 초과 / 0 미만)이 들어와도 그림자 blur 가 음수가 되면 안 된다.
void main() {
  test('되튐 곡선의 모든 구간에서 카드 그림자 값이 0 이상', () {
    const curves = <Curve>[Curves.elasticOut, Curves.elasticIn, Curves.easeOutBack, Curves.easeInBack];
    for (final curve in curves) {
      for (var i = 0; i <= 100; i++) {
        final v = curve.transform(i / 100);
        for (final s in cardShadow(v)) {
          expect(s.blurRadius, greaterThanOrEqualTo(0), reason: '$curve @ ${i / 100} → $v');
          expect(s.spreadRadius, greaterThanOrEqualTo(0));
        }
      }
    }
  });

  test('범위를 크게 벗어난 값도 안전', () {
    for (final v in <double>[-5, -0.3, 1.7, 40]) {
      expect(cardShadow(v).every((s) => s.blurRadius >= 0), isTrue);
      expect(glowShadow(const Color(0xFF2F6BFF), strength: v).every((s) => s.blurRadius >= 0), isTrue);
    }
  });
}
