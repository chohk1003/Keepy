class OcrViewModel {
  static const sampleText = '''고급모바일프로그래밍 프로젝트
화요일까지 화면 설계 정리
서버 연동 테스트
팀 회의 자료 업로드''';

  List<String> extractTaskCandidates(String recognizedText) =>
      recognizedText
          .split(RegExp(r'\r\n?|\n'))
          .map(
            (line) =>
                line
                    .trim()
                    .replaceFirst(
                      RegExp(r'^(?:[•●▪◦]\s*|[\-–—*](?:\s+|$)|\(?\d+[.)]\s+)'),
                      '',
                    )
                    .trim(),
          )
          .where((line) => line.isNotEmpty)
          .toList();
}
