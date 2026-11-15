import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

/// Android/iOS: ML Kit Selfie Segmentation 으로 '사람일 확률' 마스크를 만든다.
/// 기기 안에서만 처리하며, 잠깐 쓴 임시 파일은 바로 지운다.
Future<List<double>?> personMask(Uint8List jpg, int width, int height) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;
  final file = File('${Directory.systemTemp.path}/keepy_char_${DateTime.now().microsecondsSinceEpoch}.jpg');
  final segmenter = SelfieSegmenter(mode: SegmenterMode.single);
  try {
    await file.writeAsBytes(jpg, flush: true);
    final mask = await segmenter.processImage(InputImage.fromFilePath(file.path));
    if (mask == null) return null;
    if (mask.width == width && mask.height == height) return mask.confidences;
    // 크기가 다르면 가까운 값으로 맞춘다
    final out = List<double>.filled(width * height, 0);
    for (var y = 0; y < height; y++) {
      final my = (y * mask.height / height).floor().clamp(0, mask.height - 1);
      for (var x = 0; x < width; x++) {
        final mx = (x * mask.width / width).floor().clamp(0, mask.width - 1);
        out[y * width + x] = mask.confidences[my * mask.width + mx];
      }
    }
    return out;
  } catch (e) {
    debugPrint('Keepy: 사람 분할 실패, 테두리 색 방식으로 대신합니다 ($e)');
    return null;
  } finally {
    await segmenter.close();
    if (await file.exists()) await file.delete();
  }
}
