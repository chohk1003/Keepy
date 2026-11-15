import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_service.dart';

/// Google ML Kit 온디바이스 글자 인식 (FR-13, CST-02).
///
/// 네트워크 없이 기기 안에서만 동작하므로 비행기 모드에서도 쓸 수 있다 (NFR-05).
/// 한글 인식은 Android 에 `text-recognition-korean` 의존성이 필요하다
/// (README > 플랫폼 설정, tool/setup_platforms.ps1 이 자동으로 추가).
class MlKitOcrService implements OcrService {
  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<List<String>> recognizeLines(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final lines = <String>[
        for (final block in result.blocks)
          for (final line in block.lines) line.text,
      ];
      return splitCandidates(lines.join('\n'));
    } finally {
      await recognizer.close();
    }
  }
}

OcrService createPlatformOcrService() => MlKitOcrService();
