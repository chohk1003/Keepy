import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/companion.dart';
import '../theme.dart';

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

/// Temporary vector art: replace this renderer without changing progress,
/// gesture or delivery logic. No asset/plugin dependency is required.
class CompanionArt extends StatelessWidget {
  const CompanionArt({
    super.key,
    required this.kind,
    this.faceOnly = false,
    this.joy = 0,
    this.activity = ActivityKind.other,
  });
  final CompanionKind kind;
  final bool faceOnly;
  final double joy;
  final ActivityKind activity;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        '${kind == CompanionKind.dog ? '강아지' : '고양이'}${joy > 0.2 ? '가 기뻐해요' : '가 할 일을 바라봐요'}',
    child: CustomPaint(painter: _AnimalPainter(kind, faceOnly, joy, activity)),
  );
}

class _AnimalPainter extends CustomPainter {
  _AnimalPainter(this.kind, this.faceOnly, this.joy, this.activity);
  final CompanionKind kind;
  final bool faceOnly;
  final double joy;
  final ActivityKind activity;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / 260,
      size.height / (faceOnly ? 175 : 300),
    );
    canvas.save();
    canvas.translate(
      (size.width - 260 * scale) / 2,
      (size.height - (faceOnly ? 175 : 300) * scale) / 2,
    );
    canvas.scale(scale);
    final fur = Paint()
      ..color = kind == CompanionKind.dog
          ? const Color(0xFFFFF8E9)
          : const Color(0xFFE5DED1);
    final ear = Paint()
      ..color = kind == CompanionKind.dog
          ? const Color(0xFFA5825F)
          : const Color(0xFFB6ADA1);
    final ink = Paint()..color = K.ink;
    final stroke = Paint()
      ..color = K.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (!faceOnly) {
      canvas.drawOval(
        Rect.fromLTWH(62, 261, 142, 18),
        Paint()..color = K.ink.withValues(alpha: .08),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(69, 147, 124, 124),
          const Radius.circular(57),
        ),
        fur,
      );
      canvas.drawOval(Rect.fromLTWH(67, 247, 53, 31), fur);
      canvas.drawOval(Rect.fromLTWH(146, 247, 53, 31), fur);
      canvas.save();
      canvas.translate(190, 219);
      canvas.rotate(math.sin(joy * math.pi * 4) * .4);
      canvas.drawOval(Rect.fromLTWH(-8, -9, 57, 27), ear);
      canvas.restore();
    }
    if (kind == CompanionKind.cat) {
      for (final x in [48.0, 171.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, 58)
            ..lineTo(x + 4, 5)
            ..quadraticBezierTo(x + 33, 15, x + 45, 57)
            ..close(),
          ear,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(35, 27, 191, 143),
        topLeft: const Radius.circular(76),
        topRight: const Radius.circular(72),
        bottomLeft: const Radius.circular(66),
        bottomRight: const Radius.circular(62),
      ),
      fur,
    );
    if (kind == CompanionKind.dog) {
      canvas.save();
      canvas.translate(39, 69);
      canvas.rotate(.2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 52, height: 103),
        ear,
      );
      canvas.restore();
      canvas.save();
      canvas.translate(222, 69);
      canvas.rotate(-.2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 52, height: 103),
        ear,
      );
      canvas.restore();
    }
    for (final x in [92.0, 170.0]) {
      if (joy > .15) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, 91), width: 15, height: 13),
          math.pi,
          math.pi,
          false,
          stroke,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 96), width: 10, height: 14),
          ink,
        );
        canvas.drawCircle(Offset(x + 1, 99), 2, Paint()..color = Colors.white);
      }
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(131, 119), width: 19, height: 12),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(131, 125)
        ..quadraticBezierTo(131, 144, 115, 136)
        ..moveTo(131, 125)
        ..quadraticBezierTo(131, 144, 147, 136),
      stroke,
    );
    if (joy > .1) {
      canvas.drawOval(
        Rect.fromLTWH(125, 139, 13, 15),
        Paint()..color = const Color(0xFFE1A49A),
      );
    }
    for (final x in [74.0, 188.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 123), width: 22, height: 10),
        Paint()..color = const Color(0xFFE8B3A0).withValues(alpha: .6),
      );
    }
    if (!faceOnly) {
      final accent = Paint()..color = activityColor(activity);
      if (activity == ActivityKind.study) {
        canvas.drawPath(
          Path()
            ..moveTo(65, 28)
            ..lineTo(129, 3)
            ..lineTo(197, 27)
            ..lineTo(130, 49)
            ..close(),
          accent,
        );
        canvas.drawLine(
          const Offset(194, 29),
          const Offset(194, 61),
          stroke..color = accent.color,
        );
      } else if (activity == ActivityKind.teamwork) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(92, 195, 78, 52),
            const Radius.circular(5),
          ),
          accent,
        );
        canvas.drawLine(
          const Offset(103, 207),
          const Offset(157, 207),
          stroke..color = Colors.white,
        );
      } else if (activity == ActivityKind.life) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(188, 232, 48, 39),
            const Radius.circular(7),
          ),
          accent,
        );
        canvas.drawArc(
          Rect.fromLTWH(198, 215, 28, 36),
          math.pi,
          math.pi,
          false,
          stroke..color = accent.color,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnimalPainter old) =>
      old.kind != kind ||
      old.faceOnly != faceOnly ||
      old.joy != joy ||
      old.activity != activity;
}

class CrumbPile extends StatelessWidget {
  const CrumbPile({super.key, required this.count, this.color = K.crumb});
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '전달할 성취 $count개',
    child: SizedBox(
      width: 126,
      height: 35,
      child: CustomPaint(painter: _CrumbPainter(count, color)),
    ),
  );
}

class _CrumbPainter extends CustomPainter {
  _CrumbPainter(this.count, this.color);
  final int count;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < math.min(count, 18); i++) {
      final row = i ~/ 6, col = i % 6;
      final x =
          s.width / 2 - math.min(count, 6) * 8 + col * 16 + (row.isOdd ? 4 : 0);
      final y = s.height - 10 - row * 9;
      c.save();
      c.translate(x, y);
      c.rotate((i % 3 - 1) * .15);
      c.drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(0, 0, 13, 9),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(3),
          bottomLeft: const Radius.circular(3),
          bottomRight: const Radius.circular(5),
        ),
        Paint()..color = color,
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_CrumbPainter old) =>
      old.count != count || old.color != color;
}
