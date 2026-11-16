import 'ocr_result.dart';

/// 웹 폴백 — `dart:io`가 없는 플랫폼.
///
/// ML Kit은 모바일 전용이므로 실제 인식을 할 수 없다. 교체 전과 같이 샘플 5줄을
/// 돌려주고, 검토 화면이 '샘플' 배지를 붙인다.
Future<OcrResult> recognizeLinesImpl() => sampleFallback();
