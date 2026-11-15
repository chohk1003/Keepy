import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../game/pixel_art.dart';
import '../models/app_settings.dart';
import 'person_mask_stub.dart' if (dart.library.io) 'person_mask_mlkit.dart' as mask_impl;

/// 사진 → 픽셀 캐릭터 (미니게임).
///
/// 1. 사진을 줄이고 방향을 바로잡는다 (image 패키지, 별도 isolate).
/// 2. Android/iOS: 온디바이스 AI(ML Kit Selfie Segmentation)로 사람만 오려 낸다.
///    그 밖의 환경: 사진 테두리 색을 배경으로 보고 지운다.
/// 3. [pixelate] 로 24×24 픽셀아트로 바꾼다.
/// 원본 사진은 어디에도 저장하지 않고, 결과 픽셀(ARGB 576개)만 설정에 저장한다.
class CharacterMaker {
  const CharacterMaker();

  static const _maxSide = 320;

  Future<List<int>?> fromPicked(XFile file) async {
    final bytes = await file.readAsBytes();
    final shrunk = await compute(_decodeAndShrink, bytes);
    if (shrunk == null) return null;
    final mask = await mask_impl.personMask(shrunk.jpg, shrunk.width, shrunk.height);
    return pixelate(
      width: shrunk.width,
      height: shrunk.height,
      rgba: shrunk.rgba,
      mask: mask,
      size: AppSettings.characterSize,
    );
  }
}

class _Shrunk {
  const _Shrunk(this.width, this.height, this.rgba, this.jpg);
  final int width;
  final int height;
  final Uint8List rgba;
  final Uint8List jpg;
}

_Shrunk? _decodeAndShrink(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (image.width > CharacterMaker._maxSide || image.height > CharacterMaker._maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: CharacterMaker._maxSide)
        : img.copyResize(image, height: CharacterMaker._maxSide);
  }
  final w = image.width, h = image.height;
  final rgba = Uint8List(w * h * 4);
  var o = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      rgba[o++] = p.r.toInt();
      rgba[o++] = p.g.toInt();
      rgba[o++] = p.b.toInt();
      rgba[o++] = 255;
    }
  }
  // AI 마스크를 이 크기·방향 그대로 받기 위해 줄인 사진을 다시 JPEG 로
  final jpg = Uint8List.fromList(img.encodeJpg(image, quality: 90));
  return _Shrunk(w, h, rgba, jpg);
}
