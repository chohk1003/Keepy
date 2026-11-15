import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/models/task.dart';

// Task / TaskTag / DoneEvent 모델과 JSON 변환 (FR-10 저장 형식, TEAM_NOTES 5장)

void main() {
  group('Task JSON 왕복', () {
    test('모든 필드가 그대로 돌아온다', () {
      final t = Task(
        id: 'm3x9k2p0',
        title: '운영체제 과제',
        done: true,
        due: DateTime(2026, 11, 3),
        doneAt: DateTime(2026, 11, 5, 9, 30, 15),
        tags: {TaskTag.assignment, TaskTag.team},
        createdAt: DateTime(2026, 11, 2, 21, 40, 12),
      );

      final back = Task.fromJson(t.toJson());

      expect(back.id, t.id);
      expect(back.title, t.title);
      expect(back.done, isTrue);
      expect(back.due, t.due);
      expect(back.doneAt, t.doneAt);
      expect(back.tags, t.tags);
      expect(back.createdAt, t.createdAt);
    });

    test('jsonEncode / jsonDecode 를 거쳐도 같다 (실제 저장 경로)', () {
      final t = Task(
        id: 'x1',
        title: '장보기',
        due: DateTime(2026, 11, 3),
        tags: {TaskTag.personal},
        createdAt: DateTime(2026, 11, 2, 21, 40, 12, 345),
      );

      final decoded =
          (jsonDecode(jsonEncode(t.toJson())) as Map).cast<String, Object?>();
      final back = Task.fromJson(decoded);

      expect(decoded['due'], '2026-11-03T00:00:00.000');
      expect(decoded['tags'], ['personal']);
      expect(back.createdAt, t.createdAt, reason: '밀리초까지 보존');
      expect(back.due, t.due);
      expect(back.tags, {TaskTag.personal});
    });

    test('태그 없음·기한 없음도 왕복된다', () {
      final t = Task(id: 'x2', title: '알고리즘 문제');
      final back = Task.fromJson(t.toJson());

      expect(back.tags, isEmpty);
      expect(back.due, isNull);
      expect(back.doneAt, isNull);
      expect(back.done, isFalse);
    });

    test('태그 순서가 달라도 같은 집합', () {
      final back = Task.fromJson({
        'id': 'x3',
        'title': '팀 회의',
        'tags': ['personal', 'assignment'],
      });
      expect(back.tags, {TaskTag.assignment, TaskTag.personal});
    });

    test('알 수 없는 태그 이름은 무시한다', () {
      final back = Task.fromJson({
        'id': 'x4',
        'title': '과제',
        'tags': ['team', '없는태그', 'ASSIGNMENT'],
      });
      expect(back.tags, {TaskTag.team}, reason: '대소문자도 정확히 맞아야 함');
    });

    test('선택 항목이 빠지면 기본값이 들어간다', () {
      final back = Task.fromJson({'id': 'x5', 'title': '제목만'});

      expect(back.done, isFalse);
      expect(back.due, isNull);
      expect(back.doneAt, isNull);
      expect(back.tags, isEmpty);
      expect(back.createdAt, isNotNull, reason: 'createdAt 없으면 지금 시각');
    });

    test('필수 항목이 깨지면 예외를 던진다 (AppState 가 그 항목만 건너뜀)', () {
      expect(() => Task.fromJson({'title': 'id 없음'}), throwsA(isA<TypeError>()));
      expect(() => Task.fromJson({'id': 'title 없음'}), throwsA(isA<TypeError>()));
      expect(
        () => Task.fromJson({'id': 'x', 'title': 'y', 'due': '날짜 아님'}),
        throwsFormatException,
      );
    });

    test('생성자가 태그 집합을 복사한다', () {
      final tags = {TaskTag.team};
      final t = Task(id: 'x6', title: '과제', tags: tags);
      tags.add(TaskTag.personal);

      expect(t.tags, {TaskTag.team, TaskTag.personal},
          reason: '지금은 같은 집합을 참조한다 — add/update 쪽에서 복사해 막는다');
    });
  });

  group('TaskTag', () {
    test('라벨과 저장 이름 (TEAM_NOTES 5장)', () {
      expect(TaskTag.values.map((t) => t.name),
          ['assignment', 'lecture', 'team', 'personal']);
      expect(TaskTag.values.map((t) => t.label), ['과제', '수업', '팀 프로젝트', '개인']);
    });

    test('태그마다 그라데이션 색 두 개', () {
      for (final tag in TaskTag.values) {
        expect(tag.colors.length, 2, reason: '${tag.name} 색 개수');
        expect(tag.color, tag.colors.first);
        expect(tag.gradient.colors, tag.colors);
      }
    });
  });

  group('DoneEvent JSON 왕복', () {
    test('필드가 그대로 돌아온다', () {
      final e = DoneEvent('abc', '운영체제 과제', DateTime(2026, 11, 3, 14, 2));
      final back = DoneEvent.fromJson(e.toJson());

      expect(back.taskId, 'abc');
      expect(back.title, '운영체제 과제');
      expect(back.at, e.at);
    });

    test('깨진 데이터는 예외 (AppState 가 그 항목만 건너뜀)', () {
      expect(
        () => DoneEvent.fromJson({'taskId': 'a', 'title': 'b'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
