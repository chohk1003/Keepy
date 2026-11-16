import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/state/app_state.dart';
import 'package:keepy/util/dates.dart';

// AppState 단위 테스트 (FR-02 ~ FR-06).
// 저장소·타이머가 없는 메모리 전용 인스턴스를 쓰므로 위젯 펌프가 필요 없다.

/// 메모리 전용 상태 (저장 안 함, 1분 리빌드 타이머 없음)
AppState mem() => AppState(store: null, seed: false);

/// 만든 시점·완료 시점을 직접 정한 태스크 (정렬·분류 경계값 확인용)
Task task(
  String title, {
  DateTime? due,
  DateTime? createdAt,
  bool done = false,
  DateTime? doneAt,
  Set<TaskTag>? tags,
}) =>
    Task(
      id: title,
      title: title,
      due: due,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      done: done,
      doneAt: doneAt,
      tags: tags,
    );

List<String> titles(Iterable<Task> list) => [for (final t in list) t.title];

void main() {
  group('분류 statusOf — 지연 / 할 일 / 늦은 완료 / 완료', () {
    test('기한이 있으면 기한 다음 날 0시가 지연 경계', () {
      final s = mem();
      final t = task('과제', due: DateTime(2026, 11, 3));
      final deadline = DateTime(2026, 11, 4);

      expect(s.deadlineOf(t), deadline);
      expect(
        s.statusOf(t, now: DateTime(2026, 11, 3, 23, 59, 59)),
        TaskStatus.pending,
      );
      expect(
        s.statusOf(t, now: deadline),
        TaskStatus.pending,
        reason: '경계 시점 자체는 아직 지연이 아님',
      );
      expect(
        s.statusOf(t, now: deadline.add(const Duration(milliseconds: 1))),
        TaskStatus.overdue,
      );
    });

    test('기한이 없으면 만든 뒤 overdueDays일이 지연 경계', () {
      final s = mem();
      final t = task('정리', createdAt: DateTime(2026, 11, 1, 10));
      final deadline = DateTime(2026, 11, 4, 10); // 기본 3일

      expect(s.overdueDays, 3);
      expect(s.deadlineOf(t), deadline);
      expect(s.statusOf(t, now: deadline), TaskStatus.pending);
      expect(
        s.statusOf(t, now: deadline.add(const Duration(minutes: 1))),
        TaskStatus.overdue,
      );
    });

    test('overdueDays 0 이면 기한 없는 항목은 지연되지 않음', () {
      final s = mem()..setOverdueDays(0);
      final t = task('언젠가', createdAt: DateTime(2020, 1, 1));

      expect(s.deadlineOf(t), isNull);
      expect(s.statusOf(t, now: DateTime(2030, 1, 1)), TaskStatus.pending);
    });

    test('완료 시점이 경계를 넘었으면 늦은 완료', () {
      final s = mem();
      final due = DateTime(2026, 11, 3);
      final deadline = DateTime(2026, 11, 4);

      expect(
        s.statusOf(task('제때', due: due, done: true, doneAt: deadline)),
        TaskStatus.done,
        reason: '경계 시점 자체는 늦은 완료가 아님',
      );
      expect(
        s.statusOf(task('하루 늦게',
            due: due, done: true, doneAt: deadline.add(const Duration(days: 1)))),
        TaskStatus.late,
      );
    });

    test('기한 없는 항목도 만든 뒤 overdueDays일을 넘겨 완료하면 늦은 완료', () {
      final s = mem();
      final created = DateTime(2026, 11, 1, 10);

      expect(
        s.statusOf(task('느긋',
            createdAt: created,
            done: true,
            doneAt: created.add(const Duration(days: 2)))),
        TaskStatus.done,
      );
      expect(
        s.statusOf(task('더 느긋',
            createdAt: created,
            done: true,
            doneAt: created.add(const Duration(days: 4)))),
        TaskStatus.late,
      );
    });

    test('완료 시점이 없는 옛 데이터는 완료로 본다', () {
      final s = mem();
      expect(
        s.statusOf(task('옛것', due: DateTime(2020, 1, 1), done: true)),
        TaskStatus.done,
      );
    });

    test('지연 → 늦은 완료 → 완료 해제로 상태가 되돌아온다', () {
      final s = mem();
      final t = s.add('과제', due: DateTime.now().subtract(const Duration(days: 2)));

      expect(s.statusOf(t), TaskStatus.overdue);
      s.setDone(t, true);
      expect(s.statusOf(t), TaskStatus.late);
      s.setDone(t, false);
      expect(t.doneAt, isNull, reason: '해제하면 완료 시점도 지워져야 함');
      expect(s.statusOf(t), TaskStatus.overdue);
    });

    test('ofStatus — 분류별로 걸러 날짜순으로 돌려준다', () {
      final s = mem();
      final now = DateTime.now();
      s.add('지연 늦게', due: now.subtract(const Duration(days: 3)));
      s.add('지연 먼저', due: now.subtract(const Duration(days: 5)));
      s.add('할 일', due: now.add(const Duration(days: 1)));

      expect(titles(s.ofStatus(TaskStatus.overdue)), ['지연 먼저', '지연 늦게']);
      expect(titles(s.ofStatus(TaskStatus.pending)), ['할 일']);
      expect(s.ofStatus(TaskStatus.done), isEmpty);
      expect(s.ofStatus(TaskStatus.late), isEmpty);
    });
  });

  group('정렬 sortByDate', () {
    test('기한 빠른 순 → 기한 없음은 뒤 → 같은 기한은 만든 순', () {
      final a = task('3일 늦게 만듦',
          due: DateTime(2026, 11, 3), createdAt: DateTime(2026, 10, 2));
      final b = task('3일 먼저 만듦',
          due: DateTime(2026, 11, 3), createdAt: DateTime(2026, 10, 1));
      final c = task('1일', due: DateTime(2026, 11, 1), createdAt: DateTime(2026, 10, 9));
      final d = task('기한 없음 먼저 만듦', createdAt: DateTime(2026, 10, 5));
      final e = task('기한 없음 나중 만듦', createdAt: DateTime(2026, 10, 6));

      expect(titles(AppState.sortByDate([e, d, a, b, c])), [
        '1일',
        '3일 먼저 만듦',
        '3일 늦게 만듦',
        '기한 없음 먼저 만듦',
        '기한 없음 나중 만듦',
      ]);
    });

    test('같은 날의 시각이 달라도 이른 시각이 앞', () {
      final a = task('오후', due: DateTime(2026, 11, 3, 18));
      final b = task('오전', due: DateTime(2026, 11, 3, 9));
      expect(titles(AppState.sortByDate([a, b])), ['오전', '오후']);
    });

    test('원본 리스트는 바뀌지 않는다', () {
      final list = [
        task('나중', due: DateTime(2026, 11, 2)),
        task('먼저', due: DateTime(2026, 11, 1)),
      ];
      AppState.sortByDate(list);
      expect(titles(list), ['나중', '먼저']);
    });

    test('todo·done 게터는 완료 여부로 나눠 날짜순으로 준다', () {
      final s = mem();
      final now = DateTime.now();
      final x = s.add('완료할 것', due: now.add(const Duration(days: 1)));
      s.add('기한 없음');
      s.add('모레', due: now.add(const Duration(days: 2)));
      s.setDone(x, true);

      expect(titles(s.todo), ['모레', '기한 없음']);
      expect(titles(s.done), ['완료할 것']);
      expect(s.tasks.length, 3);
    });

    test('tasks 게터는 수정할 수 없다', () {
      final s = mem();
      s.add('과제');
      expect(() => s.tasks.clear(), throwsUnsupportedError);
    });
  });

  group('추가 add / addAll', () {
    test('add — 제목 공백 제거, 기한은 0시로 정규화, 맨 앞에 추가', () {
      final s = mem();
      s.add('첫째');
      final t = s.add('  둘째  ', due: DateTime(2026, 11, 3, 15, 30));

      expect(t.title, '둘째');
      expect(t.due, DateTime(2026, 11, 3));
      expect(titles(s.tasks), ['둘째', '첫째']);
    });

    test('add — 넘긴 태그 집합을 복사한다 (바깥에서 바꿔도 안 변함)', () {
      final s = mem();
      final tags = {TaskTag.team};
      final t = s.add('과제', tags: tags);
      tags.add(TaskTag.personal);

      expect(t.tags, {TaskTag.team});
    });

    test('addAll — 빈 줄·공백만 있는 줄은 제외하고 순서를 지킨다', () {
      final s = mem();
      s.add('기존');
      final n = s.addAll(['첫 줄', '', '   ', ' 셋째 ', '\n']);

      expect(n, 2);
      expect(titles(s.tasks), ['첫 줄', '셋째', '기존']);
    });

    test('addAll — 전부 비어 있으면 0을 반환하고 알리지도 않는다', () {
      final s = mem();
      var notified = 0;
      s.addListener(() => notified++);

      expect(s.addAll(['', '   ', '\t']), 0);
      expect(s.tasks, isEmpty);
      expect(notified, 0);
    });

    test('addAll — 기한은 모두 같은 날 0시', () {
      final s = mem();
      s.addAll(['a', 'b'], due: DateTime(2026, 11, 3, 23, 59));

      expect(s.tasks.map((t) => t.due), [
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 3),
      ]);
    });
  });

  group('되돌리기 — 삭제 / 완료 일괄 삭제', () {
    test('remove 가 준 인덱스로 restore 하면 제자리로 돌아온다', () {
      final s = mem();
      s.addAll(['첫째', '둘째', '셋째']);
      expect(titles(s.tasks), ['첫째', '둘째', '셋째']);

      final mid = s.tasks[1];
      final i = s.remove(mid);
      expect(i, 1);
      expect(titles(s.tasks), ['첫째', '셋째']);

      s.restore(i, mid);
      expect(titles(s.tasks), ['첫째', '둘째', '셋째']);
    });

    test('목록에 없는 항목 remove 는 -1 을 주고 아무 일도 하지 않는다', () {
      final s = mem();
      s.add('과제');
      var notified = 0;
      s.addListener(() => notified++);

      expect(s.remove(task('바깥')), -1);
      expect(s.tasks.length, 1);
      expect(notified, 0);
    });

    test('이미 있는 항목을 restore 해도 중복되지 않는다', () {
      final s = mem();
      final t = s.add('과제');
      s.restore(0, t);
      expect(s.tasks.length, 1);
    });

    test('restore 인덱스가 범위를 벗어나면 끝으로 붙는다', () {
      final s = mem();
      s.add('하나');
      final t = task('바깥');

      s.restore(99, t);
      expect(s.tasks.last, same(t));

      s.remove(t);
      s.restore(-5, t);
      expect(s.tasks.first, same(t));
    });

    test('clearDone 스냅샷으로 restoreAll 하면 완료 항목까지 되돌아온다', () {
      final s = mem();
      s.addAll(['할 일 1', '완료 1', '할 일 2', '완료 2']);
      for (final t in s.tasks.where((t) => t.title.startsWith('완료')).toList()) {
        s.setDone(t, true);
      }

      final snapshot = s.clearDone();
      expect(titles(s.tasks), ['할 일 1', '할 일 2']);
      expect(snapshot.length, 4, reason: '스냅샷은 삭제 전 목록 전체');

      s.restoreAll(snapshot);
      expect(titles(s.tasks), ['할 일 1', '완료 1', '할 일 2', '완료 2']);
      expect(s.done.length, 2);
    });

    test('완료 항목이 없으면 clearDone 은 목록을 그대로 둔다', () {
      final s = mem();
      s.addAll(['하나', '둘']);
      final snapshot = s.clearDone();

      expect(titles(s.tasks), ['하나', '둘']);
      expect(snapshot.length, 2);
    });
  });

  group('완료 토글과 완료 내역', () {
    test('완료하면 내역에 쌓이고, 바로 해제하면 그 기록이 사라진다', () {
      final s = mem();
      final t = s.add('과제');

      s.setDone(t, true);
      expect(s.doneLog.single.taskId, t.id);
      expect(s.doneLog.single.title, '과제');
      expect(t.doneAt, isNotNull);

      s.setDone(t, false);
      expect(s.doneLog, isEmpty);
      expect(t.done, isFalse);
    });

    test('같은 값으로 다시 호출하면 아무 일도 없다', () {
      final s = mem();
      final t = s.add('과제');
      var notified = 0;
      s.addListener(() => notified++);

      s.setDone(t, false);
      expect(notified, 0);
      expect(s.doneLog, isEmpty);
    });

    test('내역은 최대 100개, 최신이 앞', () {
      final s = mem();
      for (var i = 0; i <= 100; i++) {
        s.setDone(s.add('항목 $i'), true);
      }

      expect(s.doneLog.length, 100);
      expect(s.doneLog.first.title, '항목 100');
      expect(s.doneLog.any((e) => e.title == '항목 0'), isFalse);
    });
  });

  group('수정 update', () {
    test('제목 공백 제거, 태그 교체, 기한 0시 정규화', () {
      final s = mem();
      final t = s.add('원래', tags: {TaskTag.personal});

      s.update(t,
          title: '  바뀜 ',
          tags: {TaskTag.team, TaskTag.lecture},
          due: DateTime(2026, 11, 3, 8, 1));

      expect(t.title, '바뀜');
      expect(t.tags, {TaskTag.team, TaskTag.lecture});
      expect(t.due, DateTime(2026, 11, 3));
    });

    test('clearDue 는 기한을 비운다 (due 를 같이 넘겨도 비움이 우선)', () {
      final s = mem();
      final t = s.add('과제', due: DateTime(2026, 11, 3));

      s.update(t, clearDue: true, due: DateTime(2026, 12, 1));
      expect(t.due, isNull);
    });

    test('넘긴 태그 집합을 복사한다', () {
      final s = mem();
      final t = s.add('과제');
      final tags = {TaskTag.team};

      s.update(t, tags: tags);
      tags.add(TaskTag.personal);
      expect(t.tags, {TaskTag.team});
    });

    test('아무 것도 넘기지 않으면 값이 유지된다', () {
      final s = mem();
      final t = s.add('과제', due: DateTime(2026, 11, 3), tags: {TaskTag.team});

      s.update(t);
      expect(t.title, '과제');
      expect(t.due, DateTime(2026, 11, 3));
      expect(t.tags, {TaskTag.team});
    });
  });

  group('태그 사용 빈도 tagsByUsage', () {
    test('아무것도 없으면 기본 순서', () {
      expect(mem().tagsByUsage(), TaskTag.values);
    });

    test('많이 쓴 태그가 앞, 같으면 기본 순서', () {
      final s = mem();
      s.add('a', tags: {TaskTag.personal});
      s.add('b', tags: {TaskTag.personal, TaskTag.team});
      s.add('c', tags: {TaskTag.team});
      s.add('d', tags: {TaskTag.lecture});

      // personal 2 · team 2 (같으면 열거 순서) · lecture 1 · assignment 0
      expect(s.tagsByUsage(), [
        TaskTag.team,
        TaskTag.personal,
        TaskTag.lecture,
        TaskTag.assignment,
      ]);
    });

    test('완료 항목의 태그도 센다', () {
      final s = mem();
      final t = s.add('a', tags: {TaskTag.lecture});
      s.setDone(t, true);
      expect(s.tagsByUsage().first, TaskTag.lecture);
    });
  });

  group('날짜별 조회', () {
    test('onDay · dayCounts · dayRate', () {
      final s = mem();
      final day = DateTime(2026, 11, 3);
      s.addAll(['A', 'B', 'C'], due: day);
      s.add('딴 날', due: DateTime(2026, 11, 4));
      s.add('기한 없음');
      s.setDone(s.tasks.firstWhere((t) => t.title == 'A'), true);

      expect(s.onDay(day).map((t) => t.title).toSet(), {'A', 'B', 'C'});
      expect(s.dayCounts(day), (done: 1, total: 3));
      expect(s.dayRate(day), closeTo(1 / 3, 1e-9));
      expect(s.dayCounts(DateTime(2026, 11, 9)), (done: 0, total: 0));
      expect(s.dayRate(DateTime(2026, 11, 9)), 0, reason: '할 일 없는 날은 0');
    });

    test('기한 없는 항목은 어떤 날에도 안 걸린다', () {
      final s = mem();
      s.add('기한 없음');
      expect(s.onDay(DateTime.now()), isEmpty);
    });

    test('neighborTaskDay — 할 일이 있는 날로만 이동', () {
      final s = mem();
      final base = DateTime(2026, 11, 10);
      s.add('과거 먼', due: DateTime(2026, 11, 1));
      s.add('과거 가까움', due: DateTime(2026, 11, 8));
      s.add('기준 날짜', due: base);
      s.add('미래 가까움', due: DateTime(2026, 11, 12));
      s.add('미래 먼', due: DateTime(2026, 11, 20));
      s.add('기한 없음');

      expect(s.neighborTaskDay(base, 1), DateTime(2026, 11, 12),
          reason: '기준 날짜는 건너뛴다');
      expect(s.neighborTaskDay(base, -1), DateTime(2026, 11, 8));
      expect(s.neighborTaskDay(DateTime(2026, 11, 20), 1), isNull);
      expect(s.neighborTaskDay(DateTime(2026, 11, 1), -1), isNull);
    });

    test('neighborTaskDay — 같은 날 여러 개여도 날짜는 0시로 준다', () {
      final s = mem();
      s.addAll(['a', 'b'], due: DateTime(2026, 11, 12, 13, 40));
      expect(s.neighborTaskDay(DateTime(2026, 11, 10, 22), 1), DateTime(2026, 11, 12));
    });

    test('할 일이 없으면 양쪽 모두 null', () {
      final s = mem();
      expect(s.neighborTaskDay(DateTime.now(), 1), isNull);
      expect(s.neighborTaskDay(DateTime.now(), -1), isNull);
    });
  });

  group('화면 상태와 설정', () {
    test('setFilter — 같은 값이면 알리지 않는다', () {
      final s = mem();
      var notified = 0;
      s.addListener(() => notified++);

      s.setFilter(TaskFilter.done);
      expect(s.filter, TaskFilter.done);
      expect(notified, 1);

      s.setFilter(TaskFilter.done);
      expect(notified, 1);
    });

    test('selectDay — 0시로 맞추고 주 오프셋을 동기화한다', () {
      final s = mem();
      final next = addDays(DateTime.now(), 7);

      s.selectDay(DateTime(next.year, next.month, next.day, 13, 20));
      expect(s.selectedDay, dayOf(next));
      expect(s.weekOffset, 1);

      s.selectDay(DateTime.now(), syncWeek: false);
      expect(s.selectedDay, dayOf(DateTime.now()));
      expect(s.weekOffset, 1, reason: 'syncWeek: false 면 주를 바꾸지 않음');
    });

    test('setWeekOffset — 같은 값이면 알리지 않는다', () {
      final s = mem();
      var notified = 0;
      s.addListener(() => notified++);

      s.setWeekOffset(0);
      expect(notified, 0);
      s.setWeekOffset(2);
      expect(notified, 1);
    });

    test('setCalendarRows — 이번 주 위치를 행 수 안으로 당긴다', () {
      final s = mem()
        ..setCalendarRows(4)
        ..setThisWeekRow(4);

      s.setCalendarRows(2);
      expect(s.calendarRows, 2);
      expect(s.thisWeekRow, 2);
    });

    test('toggleRemind — 있으면 빼고 없으면 넣는다', () {
      final s = mem();
      expect(s.remindDays, {0});

      s.toggleRemind(1);
      expect(s.remindDays, {0, 1});
      s.toggleRemind(0);
      expect(s.remindDays, {1});
    });

    test('나머지 설정 값도 바뀐다', () {
      final s = mem()
        ..setRateStyle(RateStyle.graph)
        ..setNotify(false)
        ..setNotifyTime(const TimeOfDay(hour: 7, minute: 5))
        ..setEclass(true)
        ..setEverytime(true)
        ..setOverdueDays(7);

      expect(s.rateStyle, RateStyle.graph);
      expect(s.notify, isFalse);
      expect(s.notifyTime, const TimeOfDay(hour: 7, minute: 5));
      expect(s.eclass, isTrue);
      expect(s.everytime, isTrue);
      expect(s.overdueDays, 7);
    });

    test('저장소가 없으면 flush 는 아무 일도 하지 않는다', () async {
      final s = mem();
      s.add('과제');
      await expectLater(s.flush(), completes);
    });
  });
}
