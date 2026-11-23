import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../models/companion.dart';
import '../theme.dart';
import 'duck_art.dart';

Color activityColor(ActivityKind activity) => switch (activity) {
  ActivityKind.study => const Color(0xFF7952D6),
  ActivityKind.teamwork => const Color(0xFFCE572B),
  ActivityKind.life => const Color(0xFF007F93),
  ActivityKind.other => K.blue,
};

IconData activityIcon(ActivityKind activity) => switch (activity) {
  ActivityKind.study => CupertinoIcons.book,
  ActivityKind.teamwork => CupertinoIcons.person_2,
  ActivityKind.life => CupertinoIcons.house,
  ActivityKind.other => CupertinoIcons.sparkles,
};

String activityLabel(ActivityKind activity) => switch (activity) {
  ActivityKind.study => '학습',
  ActivityKind.teamwork => '협업',
  ActivityKind.life => '생활',
  ActivityKind.other => '기타',
};

/// Keepy 캐릭터 그림 — 오리 하나뿐이다 (서윤님 벡터 그림, duck_art.dart).
/// 진척·제스처 로직은 그림과 무관하므로 이 렌더러만 갈아 끼우면 된다.
class CompanionArt extends StatelessWidget {
  const CompanionArt({
    super.key,
    this.faceOnly = false,
    this.bust = false,
    this.joy = 0,
  });

  /// 얼굴만 (헤더처럼 좁은 자리)
  final bool faceOnly;

  /// 얼굴·상반신만 — 가슴 아래를 잘라 '빼꼼' 보이게 한다 (메인화면).
  /// 자리의 높이는 폭의 [bustRatio] 배로 잡으면 가슴선이 딱 맞는다.
  final bool bust;

  /// 상반신 높이 ÷ 폭 — 오리 몸 가운데(0.62h)에서 가슴까지 더한 비율
  static const bustRatio = 0.745;

  /// 0~1, 할 일을 끝냈을 때 잠깐 커진다
  final double joy;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '오리${joy > 0.2 ? '가 기뻐해요' : '가 할 일을 바라봐요'}',
    child: LayoutBuilder(
      builder: (context, box) {
        if (bust) {
          final side = box.maxWidth;
          return ClipRect(
            child: Transform.scale(
              scale: 1 + joy * .06,
              alignment: Alignment.topCenter,
              // 자리보다 큰 그림을 위에 맞춰 그리고 아래를 잘라낸다
              child: OverflowBox(
                maxWidth: side,
                maxHeight: side * 0.92,
                alignment: Alignment.topCenter,
                child: DuckView(
                  size: side,
                  // 모자는 어두운 띠에서 실루엣이 묻혀 뺐다 — 얼굴과 안경만
                  look: const DuckLook(glasses: true),
                ),
              ),
            ),
          );
        }
        final side = math.min(box.maxWidth, box.maxHeight);
        return Center(
          child: Transform.scale(
            scale: 1 + joy * .06,
            child: faceOnly
                ? DuckFaceIcon(size: side)
                : DuckView(
                    size: side,
                    look: const DuckLook(
                      feet: true,
                      glasses: true,
                      cap: true,
                      thumbUp: true,
                    ),
                  ),
          ),
        );
      },
    ),
  );
}
