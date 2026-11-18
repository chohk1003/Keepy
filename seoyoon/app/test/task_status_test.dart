import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/models/task_status.dart';

void main() {
  final now = DateTime(2026, 11, 15, 10, 30);

  Task make({DateTime? due, DateTime? created, bool done = false, bool lateDone = false}) => Task(
        id: 'x',
        title: '과제',
        createdAt: created ?? now,
        due: due,
        done: done,
        completedLate: lateDone,
      );

  group('지연 분류 (prompts_log #11)', () {
    test('기한이 오늘이면 아직 해야 할 일', () {
      expect(statusOf(make(due: DateTime(2026, 11, 15)), now: now, delayDays: 3), TaskStatus.todo);
    });

    test('기한이 어제면 지연', () {
      expect(statusOf(make(due: DateTime(2026, 11, 14)), now: now, delayDays: 3), TaskStatus.delayed);
    });

    test('기한 없이 만든 지 3일 미만이면 해야 할 일', () {
      final created = now.subtract(const Duration(days: 2, hours: 23));
      expect(statusOf(make(created: created), now: now, delayDays: 3), TaskStatus.todo);
    });

    test('기한 없이 만든 지 3일이 지나면 지연', () {
      final created = now.subtract(const Duration(days: 3));
      expect(statusOf(make(created: created), now: now, delayDays: 3), TaskStatus.delayed);
    });

    test('지연 기준 일수는 설정값을 따른다', () {
      final created = now.subtract(const Duration(days: 4));
      expect(statusOf(make(created: created), now: now, delayDays: 7), TaskStatus.todo);
    });

    test('완료한 일은 지연이 아니고, 늦게 끝냈으면 늦은 완료', () {
      expect(statusOf(make(done: true), now: now, delayDays: 3), TaskStatus.done);
      expect(statusOf(make(done: true, lateDone: true), now: now, delayDays: 3), TaskStatus.lateDone);
    });
  });

  group('제목 규칙 (CST-03)', () {
    test('공백만 있으면 거절', () {
      expect(TitleRule.isValid('   '), isFalse);
      expect(TitleRule.errorOf(' \n '), isNotNull);
    });

    test('1자 ~ 100자 허용, 101자 거절', () {
      expect(TitleRule.isValid('a'), isTrue);
      expect(TitleRule.isValid('a' * 100), isTrue);
      expect(TitleRule.isValid('a' * 101), isFalse);
    });

    test('앞뒤 공백·연속 공백은 정리된다', () {
      expect(TitleRule.normalize('  팀   회의  '), '팀 회의');
    });
  });

  test('JSON 직렬화 왕복 (FR-10)', () {
    final t = Task(
      id: 'a1',
      title: '자료구조 과제',
      createdAt: DateTime(2026, 11, 1, 9),
      due: DateTime(2026, 11, 20),
      tags: const <String>['과제', '수업'],
      done: true,
      completedAt: DateTime(2026, 11, 21, 8),
      completedLate: true,
    );
    final back = Task.fromJson(Map<String, dynamic>.from(t.toJson()));
    expect(back.id, t.id);
    expect(back.title, t.title);
    expect(back.due, DateTime(2026, 11, 20));
    expect(back.tags, <String>['과제', '수업']);
    expect(back.done, isTrue);
    expect(back.completedLate, isTrue);
    expect(back.completedAt, t.completedAt);
  });
}
