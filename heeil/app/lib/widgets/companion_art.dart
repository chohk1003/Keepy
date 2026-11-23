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
  const CompanionArt({super.key, this.faceOnly = false, this.joy = 0});

  /// 얼굴만 (헤더처럼 좁은 자리)
  final bool faceOnly;

  /// 0~1, 할 일을 끝냈을 때 잠깐 커진다
  final double joy;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '오리${joy > 0.2 ? '가 기뻐해요' : '가 할 일을 바라봐요'}',
    child: LayoutBuilder(
      builder: (context, box) {
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
