import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/data/local_store.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 로컬 저장·복원 (FR-10) — shared_preferences 를 메모리 mock 으로 돌린다.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 저장소를 비우고(또는 주어진 값으로 채우고) LocalStore 를 연다
  Future<LocalStore> openStore([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues({...initial});
    return LocalStore.open();
  }

  /// 타이머가 남지 않도록 테스트가 끝나면 정리
  AppState boot(LocalStore store) {
    final s = AppState(store: store);
    addTearDown(s.dispose);
    return s;
  }

  List<String> titles(Iterable<Task> list) => [for (final t in list) t.title];

  group('LocalStore 읽기', () {
    test('빈 저장소 — hasData 는 false, 읽기는 빈 값', () async {
      final store = await openStore();

      expect(store.hasData, isFalse);
      expect(store.readTasks(), isEmpty);
      expect(store.readLog(), isEmpty);
      expect(store.readSettings(), isEmpty);
    });

    test('깨진 JSON 이어도 죽지 않고 빈 값을 준다', () async {
      final store = await openStore({
        'keepy.tasks.v1': '{이건 JSON 이 아님',
        'keepy.doneLog.v1': 'nope',
        'keepy.settings.v1': 'nope',
      });

      expect(store.hasData, isTrue);
      expect(store.readTasks(), isEmpty);
      expect(store.readLog(), isEmpty);
      expect(store.readSettings(), isEmpty);
    });
  });

  group('AppState ↔ LocalStore 왕복', () {
    test('저장한 태스크·내역·설정이 다시 켰을 때 그대로 복원된다', () async {
      final store = await openStore();
      final a = boot(store);
      a.restoreAll([]); // 첫 실행 샘플 7개를 비우고 시작

      final t = a.add('운영체제 과제',
          due: DateTime(2026, 11, 3), tags: {TaskTag.assignment, TaskTag.team});
      a.setDone(t, true);
      a.add('장보기');
      a
        ..setOverdueDays(5)
        ..setCalendarRows(3)
        ..setThisWeekRow(2)
        ..setRateStyle(RateStyle.bar)
        ..setNotify(false)
        ..toggleRemind(1)
        ..setNotifyTime(const TimeOfDay(hour: 7, minute: 5))
        ..setEclass(true);
      await a.flush();

      expect(store.hasData, isTrue);

      // 앱을 다시 켠 상황 (같은 저장소를 새 LocalStore 로 읽음)
      final b = boot(await LocalStore.open());

      expect(titles(b.tasks), ['장보기', '운영체제 과제'], reason: '순서까지 보존');
      final back = b.tasks.firstWhere((e) => e.title == '운영체제 과제');
      expect(back.id, t.id);
      expect(back.done, isTrue);
      expect(back.due, DateTime(2026, 11, 3));
      expect(back.doneAt, t.doneAt);
      expect(back.createdAt, t.createdAt);
      expect(back.tags, {TaskTag.assignment, TaskTag.team});

      expect(b.doneLog.single.taskId, t.id);
      expect(b.doneLog.single.title, '운영체제 과제');

      expect(b.overdueDays, 5);
      expect(b.calendarRows, 3);
      expect(b.thisWeekRow, 2);
      expect(b.rateStyle, RateStyle.bar);
      expect(b.notify, isFalse);
      expect(b.remindDays, {0, 1});
      expect(b.notifyTime, const TimeOfDay(hour: 7, minute: 5));
      expect(b.eclass, isTrue);
      expect(b.everytime, isFalse);
      expect(b.statusOf(back), TaskStatus.late, reason: '복원 후에도 분류가 유지됨');
    });

    test('변경 뒤 0.25초가 지나면 자동 저장된다', () async {
      final store = await openStore();
      final a = boot(store);
      a.restoreAll([]);

      a.add('자동 저장');
      expect(store.readTasks(), isEmpty, reason: '아직 디바운스 중');

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(store.readTasks().map((j) => j['title']), ['자동 저장']);
    });

    test('손상된 항목 하나는 그 항목만 건너뛴다', () async {
      final good =
          Task(id: 'ok', title: '정상', createdAt: DateTime(2026, 11, 2)).toJson();
      final store = await openStore({
        'keepy.tasks.v1': jsonEncode([
          good,
          <String, Object?>{'title': 'id 없음'},
          <String, Object?>{'id': 'due 깨짐', 'title': 'x', 'due': '날짜 아님'},
        ]),
        'keepy.doneLog.v1': jsonEncode([
          {'taskId': 'ok', 'title': '정상', 'at': '2026-11-02T10:00:00.000'},
          <String, Object?>{'taskId': 'at 없음'},
        ]),
      });

      final a = boot(store);
      expect(titles(a.tasks), ['정상']);
      expect(a.doneLog.length, 1);
    });

    test('태스크 키가 없으면 설정도 읽지 않고 샘플 7개가 들어간다', () async {
      final store = await openStore({
        'keepy.settings.v1': jsonEncode({'overdueDays': 7}),
      });

      expect(store.hasData, isFalse);
      final a = boot(store);

      expect(a.tasks.length, 7, reason: '첫 실행 샘플');
      expect(a.overdueDays, 3, reason: 'hasData 가 아니면 _load 를 타지 않음');
    });

    test('저장된 태스크가 0개여도 샘플을 다시 넣지 않는다', () async {
      final store = await openStore();
      final a = boot(store);
      a.restoreAll([]);
      await a.flush();

      final b = boot(await LocalStore.open());
      expect(b.tasks, isEmpty, reason: '전부 지운 상태가 유지돼야 함');
    });
  });
}
