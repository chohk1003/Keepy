import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/models/companion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keepy/data/local_store.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/state/app_state.dart';

void main() {
  late DateTime now;
  late AppState state;
  setUp(() {
    now = DateTime(2026, 11, 20, 10);
    state = AppState(clock: () => now);
  });
  tearDown(() => state.dispose());

  test('완료 하나당 성취 하나, 재전달과 체크 왕복은 중복 지급하지 않음', () {
    final task = state.add('과제', tags: {TaskTag.assignment});
    state.setDone(task, true);
    expect(state.pendingCredits.length, 1);
    expect(state.deliverCredits(), 1);
    expect(state.deliverCredits(), 0);
    state.setDone(task, false);
    expect(state.creditedTasks, isEmpty);
    state.setDone(task, true);
    expect(state.creditedTasks.length, 1);
    expect(state.pendingCredits, isEmpty);
  });

  test('전달 전 완료 취소는 수집물과 통계를 제거', () {
    final task = state.add('할 일');
    state.setDone(task, true);
    state.setDone(task, false);
    expect(state.pendingCredits, isEmpty);
    expect(state.deliverCredits(), 0);
    expect(state.creditedTasks, isEmpty);
  });

  test('완료 항목 비우기는 기록과 전달 대기를 보존', () {
    final task = state.add('할 일', due: now);
    state.setDone(task, true);
    state.clearDone();
    expect(state.tasks, isEmpty);
    expect(state.creditedTasks.length, 1);
    expect(state.todayGoal.achieved, isTrue);
    expect(state.deliverCredits(), 1);
  });

  test('예정된 일을 모두 완료해야 연속 기록, 없는 날은 증가하지 않음', () {
    expect(state.currentStreak, 0);
    final a = state.add('하나', due: now), b = state.add('둘', due: now);
    state.setDone(a, true);
    expect(state.todayGoal.achieved, isFalse);
    state.setDone(b, true);
    expect(state.currentStreak, 1);
    now = DateTime(2026, 11, 21, 10);
    state.notifyListeners();
    expect(state.currentStreak, 1);
    now = DateTime(2026, 11, 22, 10);
    final c = state.add('셋', due: now);
    state.setDone(c, true);
    expect(state.currentStreak, 2);
    expect(state.longestStreak, 2);
  });

  test('늦은 완료는 지난날의 미달성을 달성으로 바꾸지 않음', () {
    final task = state.add('어제 계획', due: now);
    now = DateTime(2026, 11, 21, 10);
    state.setDone(task, true);
    expect(state.dayGoals['2026-11-20']!.achieved, isFalse);
    expect(state.currentStreak, 0);
    expect(
      state
          .creditsBetween(DateTime(2026, 11, 21), DateTime(2026, 11, 22))
          .length,
      1,
    );
  });

  test('두 태그도 한 분류로 집계하고 완료 당시 분류를 보존', () {
    final task = state.add('팀 과제', tags: {TaskTag.team, TaskTag.assignment});
    state.setDone(task, true);
    state.update(task, tags: {TaskTag.personal});
    expect(state.activityCounts()[ActivityKind.teamwork], 1);
    expect(state.activityCounts().values.reduce((a, b) => a + b), 1);
  });

  test('100개 이상의 완료 기록과 획득 보상 보존', () {
    for (var i = 0; i < 110; i++) {
      state.setDone(state.add('할 일 $i'), true);
    }
    state.clearDone();
    expect(state.creditedTasks.length, 110);
    expect(state.unlockedRewards, contains('lamp'));
    expect(state.doneLog.length, 100, reason: '기존 최근 내역 UI와 장기 기록은 분리');
  });

  test('재시작 후 대기·전달 상태 복원', () async {
    SharedPreferences.setMockInitialValues({});
    final local = await LocalStore.open();
    final app = AppState(store: local, clock: () => now);
    addTearDown(app.dispose);
    final a = app.add('완료');
    app.setDone(a, true);
    app.deliverCredits();
    final b = app.add('대기');
    app.setDone(b, true);
    await app.flush();
    final loaded = AppState(store: await LocalStore.open(), clock: () => now);
    addTearDown(loaded.dispose);
    expect(loaded.pendingCredits.map((t) => t.title), ['대기']);
    expect(loaded.creditedTasks.length, 2);
  });

  test('동기화된 성취는 집계하고 전달 완료는 다시 지급하지 않음', () {
    final remote = Task(
      id: 'remote',
      title: '다른 기기',
      done: true,
      doneAt: now,
      credit: CompletionCredit(
        at: now,
        activity: ActivityKind.study,
        deliveredAt: now,
      ),
    );
    state.applyRemote([remote.toJson()]);
    expect(state.creditedTasks.length, 1);
    expect(state.pendingCredits, isEmpty);
    expect(Task.fromJson(remote.toJson()).credit!.deliveredAt, now);
  });
}
