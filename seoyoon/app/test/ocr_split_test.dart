import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/services/ocr_service.dart';

void main() {
  test('줄 단위로 나누고 글머리표·빈 줄·중복을 정리한다 (FR-13)', () {
    const text = '''
- 자료구조 3주차 과제
• 팀 프로젝트 회의 준비

1. 알고리즘 복습
2) 알고리즘 복습
☐ 도서관 책 반납
''';
    expect(splitCandidates(text), <String>[
      '자료구조 3주차 과제',
      '팀 프로젝트 회의 준비',
      '알고리즘 복습',
      '도서관 책 반납',
    ]);
  });

  test('100자를 넘는 줄은 100자로 자른다 (CST-03)', () {
    final result = splitCandidates('가' * 130);
    expect(result.single.length, 100);
  });
}
