import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 날개 자세 (v0.7).
enum DuckWing {
  /// 몸 옆에 붙인 날개 (살랑살랑)
  normal,

  /// 아래로 늘어뜨려 베개를 끄는 날개 (아침 방)
  down,

  /// 앞으로 뻗어 노트북을 두드리는 날개 (책상)
  forward,
}

/// 어느 부분을 그릴지. 책상 장면에서 노트북 위에 날개를 얹으려고 몸과 앞 날개를 따로 그린다.
enum DuckPart { all, body, frontWing }

/// Keepy 오리 캐릭터 (v0.7) — POOL PARTY 장면과 오늘 통계에 쓰는 새 마스코트.
///
/// 벡터로 그려서 어떤 크기에서도 둥글고 매끈하다. 미리보기(preview/index.html 의 drawDuck)와 같은 좌표를 쓴다.
/// 좌표는 몸통 가운데를 원점으로 한 100 단위 상자 기준이고, [paintDuck] 의 size 로 늘린다.
class DuckLook {
  const DuckLook({
    this.feet = false,
    this.shades = false,
    this.glasses = false,
    this.cap = false,
    this.thumbUp = false,
    this.blink = false,
    this.flip = false,
    this.tilt = 0,
    this.wing = DuckWing.normal,
    this.pajamas = false,
    this.nightcap = false,
    this.bedhead = false,
    this.sleepy = false,
    this.pillow = false,
    this.tie = false,
  });

  /// 날개 자세
  final DuckWing wing;

  /// 줄무늬 파자마 (아침 방)
  final bool pajamas;

  /// 잠옷 모자 (방울 달린 긴 모자)
  final bool nightcap;

  /// 부스스한 깃털 (자다 일어난 머리)
  final bool bedhead;

  /// 반쯤 감긴 졸린 눈 (멀뚱멀뚱)
  final bool sleepy;

  /// 왼쪽 아래에 끌고 있는 베개 ([DuckWing.down] 과 함께)
  final bool pillow;

  /// 흰 셔츠 깃 + 넥타이 (말끔한 차림)
  final bool tie;

  /// 서 있을 때 발 (물에 떠 있으면 안 보임)
  final bool feet;

  /// 선글라스 (수영장 100%)
  final bool shades;

  /// 동그란 안경 (오늘 통계)
  final bool glasses;

  /// 학사모 (오늘 통계)
  final bool cap;

  /// 날개로 엄지 척 (오늘 통계)
  final bool thumbUp;

  /// 눈 깜빡임
  final bool blink;

  /// 왼쪽을 보게 뒤집기
  final bool flip;

  /// 기울기 (라디안)
  final double tilt;
}

const _yellow = Color(0xFFFFD54A);
const _yellowDark = Color(0xFFF5BE2E);
const _outline = Color(0xFFC98A1E);
const _orange = Color(0xFFFF9A3C);
const _beakLine = Color(0xFFD9741C);
const _ink = Color(0xFF2E3A55);
const _pj = Color(0xFFA9CCF5); // 파자마
const _pjWing = Color(0xFF97BFF0);
const _pjLine = Color(0xFF6E9AD6);
const _pjStripe = Color(0xFF8DB8EE);

/// [center] 에 몸통 가운데가 오도록, 몸 너비가 대략 [size] 인 오리를 그린다.
void paintDuck(
  Canvas canvas,
  Offset center,
  double size, {
  DuckLook look = const DuckLook(),
  double time = 0,
  DuckPart part = DuckPart.all,
}) {
  final k = size / 100;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(look.tilt);
  canvas.scale(look.flip ? -k : k, k);

  final fill = Paint()..style = PaintingStyle.fill;
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _outline;

  void oval(double cx, double cy, double rx, double ry, Color color, {double rotation = 0, Color? stroke}) {
    canvas.save();
    canvas.translate(cx, cy);
    if (rotation != 0) canvas.rotate(rotation);
    final r = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    canvas.drawOval(r, fill..color = color);
    if (stroke != null) canvas.drawOval(r, line..color = stroke);
    canvas.restore();
  }

  void shape(Path path, Color color, {Color? stroke = _outline}) {
    canvas.drawPath(path, fill..color = color);
    if (stroke != null) canvas.drawPath(path, line..color = stroke);
  }

  final bodyColor = look.pajamas ? _pj : _yellow;
  final bodyLine = look.pajamas ? _pjLine : _outline;
  final wingColor = look.pajamas ? _pjWing : _yellowDark;

  void frontWing() {
    final bob = math.sin(time * 14);
    oval(42, 6 + bob * 1.4, 18, 7, wingColor, rotation: 0.28 + bob * 0.06, stroke: bodyLine);
  }

  if (part == DuckPart.frontWing) {
    if (look.wing == DuckWing.forward) frontWing();
    canvas.restore();
    return;
  }

  // 끌고 다니는 베개
  if (look.pillow) {
    canvas.save();
    canvas.translate(-62, 33);
    canvas.rotate(-0.12);
    final pillow = RRect.fromRectAndRadius(const Rect.fromLTWH(-25, -14, 50, 28), const Radius.circular(11));
    canvas.drawRRect(pillow, fill..color = const Color(0xFFFFFFFF));
    canvas.drawRRect(pillow, line..color = const Color(0xFFC9D3E0));
    canvas.drawPath(
      Path()
        ..moveTo(-18, -4)
        ..quadraticBezierTo(0, 2, 18, -4),
      line..color = const Color(0xFFDDE4EE),
    );
    canvas.restore();
  }
  // 발
  if (look.feet) {
    oval(-14, 40, 11, 5.5, _orange, stroke: _beakLine);
    oval(12, 40, 11, 5.5, _orange, stroke: _beakLine);
  }
  // 꼬리
  shape(
    Path()
      ..moveTo(-36, 2)
      ..quadraticBezierTo(-56, -14, -50, -22)
      ..quadraticBezierTo(-40, -10, -30, -6)
      ..close(),
    _yellow,
  );
  // 몸 (파자마면 줄무늬 + 단추)
  oval(0, 12, 42, 30, bodyColor);
  if (look.pajamas) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCenter(center: const Offset(0, 12), width: 84, height: 60)));
    final stripe = Paint()
      ..strokeWidth = 3.2
      ..color = _pjStripe;
    for (var sx = -40.0; sx <= 40; sx += 10) {
      canvas.drawLine(Offset(sx, -20), Offset(sx, 44), stripe);
    }
    for (final b in const <Offset>[Offset(25, -1), Offset(28, 11), Offset(26, 23)]) {
      canvas.drawCircle(b, 2.3, fill..color = const Color(0xFFFFFFFF));
    }
    canvas.restore();
  }
  canvas.drawOval(Rect.fromCenter(center: const Offset(0, 12), width: 84, height: 60), line..color = bodyLine);
  // 셔츠 깃 + 넥타이
  if (look.tie) {
    shape(
      Path()
        ..moveTo(5, -5)
        ..lineTo(16, 3)
        ..lineTo(12, -8)
        ..close(),
      const Color(0xFFFFFFFF),
      stroke: const Color(0xFFC9D3E0),
    );
    shape(
      Path()
        ..moveTo(16, 3)
        ..lineTo(28, -6)
        ..lineTo(22, -9)
        ..close(),
      const Color(0xFFFFFFFF),
      stroke: const Color(0xFFC9D3E0),
    );
    shape(
      Path()
        ..moveTo(13, 1)
        ..lineTo(19, 1)
        ..lineTo(18, 5)
        ..lineTo(14, 5)
        ..close(),
      KeepyDuckColors.tie,
      stroke: const Color(0xFF1E5EEB),
    );
    shape(
      Path()
        ..moveTo(14, 5)
        ..lineTo(18, 5)
        ..lineTo(21, 20)
        ..lineTo(16, 25)
        ..lineTo(12, 20)
        ..close(),
      KeepyDuckColors.tie,
      stroke: const Color(0xFF1E5EEB),
    );
  }
  // 날개 · 엄지 척
  if (look.thumbUp) {
    canvas.save();
    canvas.translate(26, 0);
    canvas.rotate(-0.5);
    oval(0, -6, 10, 16, _yellowDark, stroke: _outline);
    final thumb = RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -34, 10, 18), const Radius.circular(5));
    canvas.drawRRect(thumb, fill..color = _yellow);
    canvas.drawRRect(thumb, line..color = _outline);
    canvas.restore();
  } else {
    switch (look.wing) {
      case DuckWing.normal:
        oval(-6, 14, 17, 11, wingColor, rotation: -0.25 + math.sin(time * 3) * 0.06, stroke: bodyLine);
      case DuckWing.down:
        oval(-27, 22, 8, 15, wingColor, rotation: 0.9, stroke: bodyLine);
      case DuckWing.forward:
        if (part == DuckPart.all) frontWing();
    }
  }
  // 머리 · 깃털
  canvas.drawCircle(const Offset(12, -26), 25, fill..color = _yellow);
  canvas.drawCircle(const Offset(12, -26), 25, line..color = _outline);
  if (!look.nightcap) {
    shape(
      Path()
        ..moveTo(8, -50)
        ..quadraticBezierTo(4, -62, 14, -60)
        ..quadraticBezierTo(10, -54, 16, -50),
      _yellow,
    );
  }
  // 볼
  oval(-2, -16, 6, 4, const Color(0x73FF808C));
  oval(30, -16, 6, 4, const Color(0x73FF808C));
  // 부리
  oval(32, -20, 13, 6.5, _orange, rotation: 0.08, stroke: _beakLine);
  canvas.drawPath(
    Path()
      ..moveTo(21, -19)
      ..quadraticBezierTo(32, -16, 43, -20),
    line..color = _beakLine,
  );
  // 눈
  for (final ex in <double>[4, 24]) {
    if (look.sleepy && !look.blink) {
      // 졸린 눈: 위쪽 반을 눈꺼풀이 덮고, 반짝임 없이 멀뚱멀뚱
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(ex - 6, -30.2, 12, 8));
      oval(ex, -30, 4.4, 4.8, _ink);
      canvas.restore();
      canvas.drawLine(
        Offset(ex - 5.2, -30.4),
        Offset(ex + 5.2, -30.4),
        Paint()
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
      continue;
    }
    oval(ex, -30, 4.4, look.blink ? 0.8 : 4.8, _ink);
    if (!look.blink) canvas.drawCircle(Offset(ex + 1.5, -31.7), 1.5, fill..color = const Color(0xFFFFFFFF));
  }
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..color = _ink;
  // 동그란 안경
  if (look.glasses) {
    canvas.drawCircle(const Offset(4, -30), 8.5, ink);
    canvas.drawCircle(const Offset(24, -30), 8.5, ink);
    canvas.drawLine(const Offset(12.5, -30), const Offset(15.5, -30), ink);
  }
  // 선글라스
  if (look.shades) {
    for (final gx in <double>[-6, 15]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(gx, -36, 16, 11), const Radius.circular(5)),
        fill..color = const Color(0xFF1F2633),
      );
    }
    canvas.drawLine(const Offset(10, -32), const Offset(15, -32), ink);
    final shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x8CFFFFFF);
    canvas.drawLine(const Offset(-2, -29), const Offset(3, -34), shine);
    canvas.drawLine(const Offset(19, -29), const Offset(24, -34), shine);
  }
  // 학사모 (v0.7: 머리 위에 크게)
  if (look.cap) {
    canvas.save();
    canvas.translate(14, -48);
    canvas.scale(1.5);
    canvas.translate(-14, 46);
    shape(
      Path()
        ..moveTo(-14, -50)
        ..lineTo(14, -60)
        ..lineTo(42, -50)
        ..lineTo(14, -40)
        ..close(),
      _ink,
      stroke: null,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2, -50, 24, 8), const Radius.circular(3)),
      fill..color = _ink,
    );
    final tassel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFC94D);
    canvas.drawPath(
      Path()
        ..moveTo(14, -50)
        ..quadraticBezierTo(36, -46, 34, -34),
      tassel,
    );
    canvas.drawCircle(const Offset(34, -33), 3, fill..color = const Color(0xFFFFC94D));
    canvas.restore();
  }
  // 부스스한 깃털 (모자 밑으로 삐져나옴)
  if (look.bedhead) {
    for (final tuft in <List<Offset>>[
      const <Offset>[Offset(-11, -33), Offset(-24, -38), Offset(-12, -26)],
      const <Offset>[Offset(-12, -24), Offset(-23, -21), Offset(-12, -17)],
      const <Offset>[Offset(33, -38), Offset(44, -42), Offset(36, -32)],
    ]) {
      shape(
        Path()
          ..moveTo(tuft[0].dx, tuft[0].dy)
          ..quadraticBezierTo((tuft[0].dx + tuft[1].dx) / 2, tuft[1].dy - 3, tuft[1].dx, tuft[1].dy)
          ..quadraticBezierTo((tuft[1].dx + tuft[2].dx) / 2, tuft[2].dy, tuft[2].dx, tuft[2].dy),
        _yellow,
      );
    }
  }
  // 잠옷 모자: 뒤로 늘어진 긴 모자 + 하얀 방울 + 털 띠
  if (look.nightcap) {
    final sway = math.sin(time * 1.6) * 2;
    final capBody = Path()
      ..moveTo(-12, -42)
      ..quadraticBezierTo(10, -58, 34, -47)
      ..quadraticBezierTo(22, -76, -8, -68)
      ..quadraticBezierTo(-36, -62, -46 + sway, -34)
      ..quadraticBezierTo(-30, -52, -12, -42)
      ..close();
    shape(capBody, const Color(0xFF8FB7F2), stroke: _pjLine);
    for (final d in const <Offset>[Offset(0, -62), Offset(16, -60), Offset(-20, -57), Offset(-34, -46)]) {
      canvas.drawCircle(d, 2.2, fill..color = const Color(0xFFFFFFFF));
    }
    // 털 띠
    canvas.drawPath(
      Path()
        ..moveTo(-13, -42)
        ..quadraticBezierTo(10, -57, 35, -46),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(Offset(-47 + sway, -31), 6.5, fill..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(Offset(-47 + sway, -31), 6.5, line..color = const Color(0xFFC9D3E0));
  }
  canvas.restore();
}

/// 오리 소품 색.
class KeepyDuckColors {
  static const tie = Color(0xFF2F7BFF);
}

/// 오리 그림 위젯 (오늘 통계: 안경 + 학사모 + 엄지 척).
class DuckView extends StatelessWidget {
  const DuckView({super.key, required this.size, this.look = const DuckLook()});
  final double size;
  final DuckLook look;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.92,
      child: CustomPaint(painter: _DuckPainter(look)),
    );
  }
}

class _DuckPainter extends CustomPainter {
  _DuckPainter(this.look);
  final DuckLook look;

  @override
  void paint(Canvas canvas, Size size) {
    paintDuck(canvas, Offset(size.width * 0.46, size.height * 0.62), size.width * 0.7, look: look);
  }

  @override
  bool shouldRepaint(_DuckPainter old) => false;
}

/// 메인 머리 바로가기 아이콘 — 오리 얼굴.
class DuckFaceIcon extends StatelessWidget {
  const DuckFaceIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: const CustomPaint(painter: _DuckFacePainter()));
  }
}

class _DuckFacePainter extends CustomPainter {
  const _DuckFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 40;
    canvas.save();
    canvas.scale(k, k);
    final fill = Paint();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(18, 21), 14.5, fill..color = _yellow);
    canvas.drawCircle(const Offset(18, 21), 14.5, line..color = _outline);
    final tuft = Path()
      ..moveTo(15, 7.5)
      ..quadraticBezierTo(14, 1.5, 19, 2.5)
      ..quadraticBezierTo(17, 4.5, 18, 8);
    canvas.drawPath(tuft, fill..color = _yellow);
    canvas.drawPath(tuft, line..color = _outline);
    final beak = Rect.fromCenter(center: const Offset(29, 25), width: 16, height: 8.4);
    canvas.drawOval(beak, fill..color = _orange);
    canvas.drawOval(beak, line..color = _beakLine);
    for (final ex in <double>[13, 24]) {
      canvas.drawCircle(Offset(ex, 18.5), 2.6, fill..color = _ink);
      canvas.drawCircle(Offset(ex + 1, 17.5), 0.9, fill..color = const Color(0xFFFFFFFF));
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(9.5, 25), width: 6.4, height: 4.2),
      fill..color = const Color(0x73FF808C),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DuckFacePainter old) => false;
}
