import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_result.dart';

/// 모바일 실제 구현 — 촬영 → ML Kit 한국어 텍스트 인식 (FR-13)
///
/// 흐름: `image_picker`로 촬영 → `InputImage.fromFilePath` →
/// `TextRecognizer(script: korean)` → blocks·lines 평탄화 → **원본 삭제**.
///
/// 지키는 제약:
/// - CST-02 온디바이스만 — 네트워크 호출 없음
/// - NFR-02 3초 타임아웃 ([ocrTimeout])
/// - NFR-05 인식이 끝나면 원본 이미지 즉시 삭제
/// - NFR-07 권한 거부 시 안내 문구 반환
Future<OcrResult> recognizeLinesImpl() async {
  // 데스크톱(windows·macos·linux)은 `dart:io`는 있지만 ML Kit 플러그인이 없다.
  // 호출하면 MissingPluginException이 나므로 여기서 샘플 폴백으로 빠진다.
  if (!Platform.isAndroid && !Platform.isIOS) return sampleFallback();

  final XFile? shot;
  try {
    shot = await ImagePicker().pickImage(source: ImageSource.camera);
  } on PlatformException catch (e) {
    return OcrResult(message: _deniedMessage(e));
  }
  // 사용자가 촬영을 취소함 — 안내 없이 촬영 화면에 머문다
  if (shot == null) return const OcrResult(cancelled: true);

  // 촬영 시간은 사용자 쪽이므로 재지 않는다. 인식 구간만 측정한다 (NFR-02)
  final sw = Stopwatch()..start();
  final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
  try {
    final text = await recognizer
        .processImage(InputImage.fromFilePath(shot.path))
        .timeout(ocrTimeout);
    sw.stop();
    return OcrResult(lines: _toLines(text), elapsed: sw.elapsed);
  } on TimeoutException {
    return const OcrResult(elapsed: ocrTimeout, message: timeoutMessage);
  } on PlatformException catch (e) {
    return OcrResult(message: _deniedMessage(e));
  } finally {
    await _close(recognizer);
    await _wipe(shot); // NFR-05
  }
}

/// blocks → lines 평탄화. 빈 줄은 버리고 앞뒤 공백을 떼어 검토 화면에 넘긴다.
List<String> _toLines(RecognizedText text) {
  final out = <String>[];
  for (final block in text.blocks) {
    for (final line in block.lines) {
      final s = line.text.trim();
      if (s.isNotEmpty) out.add(s);
    }
  }
  return out;
}

/// 원본 이미지를 기기에 남기지 않는다 (NFR-05).
///
/// `image_picker`는 촬영 결과를 앱 캐시에 복사해 두므로 그 파일을 지워야 한다.
Future<void> _wipe(XFile shot) async {
  try {
    final f = File(shot.path);
    if (f.existsSync()) await f.delete();
  } on FileSystemException {
    // 지우지 못해도 인식 흐름은 계속한다
  }
}

/// 인식기 자원 해제. 실패해도 결과에 영향을 주지 않는다.
Future<void> _close(TextRecognizer recognizer) async {
  try {
    await recognizer.close();
  } on PlatformException {
    // 이미 닫혔거나 플러그인이 없는 경우
  }
}

/// 권한 거부·실패를 사용자 문구로 바꾼다 (NFR-07).
String _deniedMessage(PlatformException e) => switch (e.code) {
  'camera_access_denied' => cameraDeniedMessage,
  'photo_access_denied' => photoDeniedMessage,
  'invalid_image' => '사진을 읽을 수 없음\n다시 촬영',
  _ => '인식 실패\n다시 촬영',
};
