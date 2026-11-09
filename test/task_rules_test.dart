import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/domain/task_rules.dart';

void main() {
  group('제목 검증 (CST-03, T04)', () {
    test('경계값 1자 및 100자는 허용', () {
      expect(isValidTitle('가'), isTrue);
      expect(isValidTitle('a' * 100), isTrue);
      expect(isValidTitle('\u{1F600}' * 100), isTrue); // 이모지 100개
    });

    test('빈 문자열, 공백만 있는 경우, 101자는 거부', () {
      expect(isValidTitle(''), isFalse);
      expect(isValidTitle('   '), isFalse);
      expect(isValidTitle('a' * 101), isFalse);
    });
  });

  group('다이얼 날짜 계산 (FR-09, T17)', () {
    test('월·연 넘김과 윤년 보정', () {
      expect(dueAfter(DateTime(2026, 10, 30), 1), DateTime(2026, 10, 31));
      expect(dueAfter(DateTime(2026, 10, 30), 2), DateTime(2026, 11, 1));
      expect(dueAfter(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(dueAfter(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
    });
  });
}