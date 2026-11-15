import '../models/task.dart';

/// 종이 메모 → 할 일 후보 (FR-13).
///
/// 실제 구현은 [createOcrService] 가 플랫폼에 맞게 고른다.
/// - Android / iOS: Google ML Kit 온디바이스 인식 (CST-02, NFR-05)
/// - 웹 / 데스크톱: 미지원 → 화면에서 '직접 붙여넣기'로 대체
abstract class OcrService {
  bool get isSupported;

  /// 이미지 파일에서 줄 단위 후보를 뽑는다.
  /// 원본 이미지는 호출한 쪽이 결과를 받은 즉시 지운다 (NFR-05).
  Future<List<String>> recognizeLines(String imagePath);
}

class UnsupportedOcrService implements OcrService {
  const UnsupportedOcrService();

  @override
  bool get isSupported => false;

  @override
  Future<List<String>> recognizeLines(String imagePath) async =>
      throw UnsupportedError('이 기기에서는 글자 인식을 지원하지 않습니다.');
}

final _bullet = RegExp(r'^\s*(?:[-–—•·*▪◦○●□■☐☑✓✔]|\d{1,2}[.)]|[①-⑳])\s*');

/// 인식 결과 텍스트를 줄 단위 할 일 후보로 나눈다.
///
/// 글머리표·번호를 떼고, 빈 줄과 중복을 지우고, 100자로 자른다.
List<String> splitCandidates(String text) {
  final seen = <String>{};
  final result = <String>[];
  for (final line in text.split(RegExp(r'\r?\n'))) {
    var t = line.replaceFirst(_bullet, '');
    t = TitleRule.normalize(t);
    if (t.isEmpty) continue;
    if (t.length > TitleRule.maxLength) t = t.substring(0, TitleRule.maxLength);
    if (seen.add(t)) result.add(t);
  }
  return result;
}
