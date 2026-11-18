import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/game/pixel_art.dart';
import 'package:keepy/models/task.dart';

void main() {
  test('남자·여자 캐릭터 16×16, 펫 12×12 (v0.4)', () {
    expect(boySprite().size, 16);
    expect(girlSprite().pixels.length, 256);
    for (final pet in <PixelSprite>[dogSprite(), catSprite(), rabbitSprite()]) {
      expect(pet.size, 12);
      expect(pet.pixels.length, 144);
      expect(pet.pixels.where((p) => p != 0), isNotEmpty);
    }
  });

  test('기본 캐릭터는 16×16', () {
    final s = defaultSprite();
    expect(s.size, 16);
    expect(s.pixels.length, 256);
    expect(s.pixels.where((p) => p != 0), isNotEmpty);
  });

  test('사진 → 24×24 픽셀 캐릭터: 마스크 밖은 투명, 외곽선 생성', () {
    const w = 60, h = 60;
    final rgba = Uint8List(w * h * 4);
    final mask = List<double>.filled(w * h, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        final inside = (x - 30) * (x - 30) + (y - 30) * (y - 30) < 15 * 15; // 가운데 원 = 사람
        rgba[o] = inside ? 240 : 30;
        rgba[o + 1] = inside ? 200 : 120;
        rgba[o + 2] = inside ? 170 : 60;
        rgba[o + 3] = 255;
        mask[y * w + x] = inside ? 1 : 0;
      }
    }
    final px = pixelate(width: w, height: h, rgba: rgba, mask: mask, size: 24, colors: 6);
    expect(px.length, 24 * 24);
    expect(px.first, anyOf(0, 0xFF1A2433)); // 모서리는 투명(또는 외곽선)
    expect(px.where((p) => p == 0xFF1A2433), isNotEmpty); // 외곽선
    expect(px[12 * 24 + 12], isNot(0)); // 가운데는 채워짐
    expect(px.where((p) => p != 0).every((p) => (p >> 24) == 0xFF), isTrue);
  });

  test('마스크 없으면 테두리 색을 배경으로 지운다', () {
    const w = 40, h = 40;
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      final x = i % w, y = i ~/ w;
      final inside = x > 12 && x < 28 && y > 10 && y < 34;
      rgba[i * 4] = inside ? 20 : 250;
      rgba[i * 4 + 1] = inside ? 90 : 250;
      rgba[i * 4 + 2] = inside ? 200 : 250;
      rgba[i * 4 + 3] = 255;
    }
    final px = pixelate(width: w, height: h, rgba: rgba, size: 20);
    expect(px.first, 0);
    expect(px[10 * 20 + 10], isNot(0));
  });

  test('태그 이름 규칙', () {
    expect(TagRule.errorOf('  ', const <String>[]), isNotNull);
    expect(TagRule.errorOf('#동아리', const <String>[]), isNull);
    expect(TagRule.normalize('#동아리 '), '동아리');
    expect(TagRule.errorOf('과제', const <String>['과제']), isNotNull);
    expect(TagRule.errorOf('과제', const <String>['과제'], except: '과제'), isNull);
    expect(TagRule.errorOf('가' * 13, const <String>[]), isNotNull);
  });

  test('보이는 폭은 그림 폭 안에 있고, 펫과 캐릭터가 최소 칸 폭 안에 겹치지 않고 들어간다 (v0.5)', () {
    for (final sp in <PixelSprite>[boySprite(), girlSprite(), dogSprite(), catSprite(), rabbitSprite()]) {
      final c = sp.visibleColumns;
      expect(c.min, greaterThanOrEqualTo(0));
      expect(c.max, lessThan(sp.size));
      expect(c.max, greaterThan(c.min));
    }
    const stepW = 72.0; // StairPainter.minStepWithPet
    final cs = (stepW * 0.64).clamp(30.0, 50.0);
    for (final ch in <PixelSprite>[boySprite(), girlSprite()]) {
      for (final pet in <PixelSprite>[dogSprite(), catSprite(), rabbitSprite()]) {
        final w = ch.visibleSpan(cs).width + pet.visibleSpan(cs * 0.72).width + cs * 0.14;
        expect(w, lessThanOrEqualTo(stepW), reason: '한 칸 안에 나란히');
      }
    }
  });
}
