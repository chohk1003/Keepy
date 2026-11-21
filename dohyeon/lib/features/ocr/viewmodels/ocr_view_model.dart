/// Simulates the output of an on-device OCR engine; camera/ML Kit comes later.
class OcrViewModel {
  static const sampleText = '''고급모바일프로그래밍 프로젝트
화요일까지 화면 설계 정리
서버 연동 테스트
팀 회의 자료 업로드''';

  List<String> extractTaskCandidates(String recognizedText) => recognizedText
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim().replaceAll(RegExp(r'^[•\-*\d.)\s]+'), ''))
      .where((line) => line.isNotEmpty)
      .take(10)
      .toList();
}
