import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/data/repositories.dart';
import 'package:keepy/models/task_status.dart';
import 'package:keepy/state/task_store.dart';

void main() {
  late DateTime clock;
  late InMemoryTaskRepository repo;
  late TaskStore store;

  setUp(() async {
    clock = DateTime(2026, 11, 15, 9);
    repo = InMemoryTaskRepository();
    store = TaskStore(repository: repo, clock: () => clock);
    await store.load();
  });

  test('추가 → 저장소에 저장 (FR-02, FR-10)', () async {
    final t = store.add('  모바일 앱 UI 시안 정리 ', tags: const <String>['과제']);
    expect(t, isNotNull);
    expect(t!.title, '모바일 앱 UI 시안 정리');
    await store.flush();
    expect(repo.saved.single.title, '모바일 앱 UI 시안 정리');
  });

  test('빈 제목·101자 제목은 추가되지 않는다 (CST-03, NFR-07)', () {
    expect(store.add('   '), isNull);
    expect(store.add('가' * 101), isNull);
    expect(store.totalCount, 0);
  });

  test('완료 토글과 개수 (FR-03, FR-05)', () {
    final a = store.add('A')!;
    store.add('B');
    store.toggle(a.id);
    expect(store.doneCount, 1);
    expect(store.openCount, 1);
    store.toggle(a.id);
    expect(store.doneCount, 0);
    expect(store.byId(a.id)!.completedAt, isNull);
  });

  test('지연 상태에서 완료하면 늦은 완료로 남는다 (prompts_log #11)', () {
    final t = store.add('지난 과제', due: DateTime(2026, 11, 13))!;
    expect(store.statusOf(t), TaskStatus.delayed);
    store.toggle(t.id);
    expect(store.statusOf(store.byId(t.id)!), TaskStatus.lateDone);
  });

  test('삭제 후 되돌리기 (FR-04, prompts_log #9)', () {
    store.add('A');
    final b = store.add('B')!;
    store.add('C');
    final removed = store.remove(b.id)!;
    expect(store.tasks.map((t) => t.title), <String>['A', 'C']);
    store.restore(removed);
    expect(store.tasks.map((t) => t.title), <String>['A', 'B', 'C']);
  });

  test('다이얼로 기한 지정 (FR-09)', () {
    final t = store.add('팀 회의 준비')!;
    store.setDue(t.id, DateTime(2026, 11, 17, 23, 59));
    expect(store.byId(t.id)!.due, DateTime(2026, 11, 17));
    expect(store.tasksOn(DateTime(2026, 11, 17)).single.id, t.id);
  });

  test('할 일이 있는 날로만 이동 (prompts_log #7)', () {
    store.add('a', due: DateTime(2026, 11, 10));
    store.add('b', due: DateTime(2026, 11, 15));
    store.add('c', due: DateTime(2026, 11, 22));
    final from = DateTime(2026, 11, 15);
    expect(store.adjacentTaskDate(from, -1), DateTime(2026, 11, 10));
    expect(store.adjacentTaskDate(from, 1), DateTime(2026, 11, 22));
    expect(store.adjacentTaskDate(DateTime(2026, 11, 22), 1), isNull);
  });

  test('정렬: 지연 → 사용자가 정한 순서, 완료는 뒤', () {
    store.add('미지정');
    store.add('모레', due: DateTime(2026, 11, 17));
    store.add('지연', due: DateTime(2026, 11, 12));
    final done = store.add('완료')!;
    store.toggle(done.id);
    expect(store.sorted(store.tasks).map((t) => t.title), <String>['지연', '미지정', '모레', '완료']);
  });

  test('편집 모드: 끌어서 순서 바꾸기 (v0.3)', () {
    final a = store.add('A')!;
    final b = store.add('B')!;
    final c = store.add('C')!;
    final ids = <String>[a.id, b.id, c.id];
    // C 를 맨 위로 (ReorderableList: old 2 → new 0)
    store.reorder(ids, 2, 0);
    expect(store.todoTasks.map((t) => t.title), <String>['C', 'A', 'B']);
    // A(현재 1번째)를 맨 아래로 (old 1 → new 3)
    store.reorder(store.todoTasks.map((t) => t.id).toList(), 1, 3);
    expect(store.todoTasks.map((t) => t.title), <String>['C', 'B', 'A']);
  });

  test('태그 이름 바꾸기·삭제가 할 일에도 반영 (v0.3)', () {
    final t = store.add('발표', tags: const <String>['과제', '팀 프로젝트'])!;
    store.renameTag('과제', '리포트');
    expect(store.byId(t.id)!.tags, <String>['리포트', '팀 프로젝트']);
    expect(store.removeTag('팀 프로젝트'), 1);
    expect(store.byId(t.id)!.tags, <String>['리포트']);
    expect(store.countWithTag('리포트'), 1);
  });

  test('미니게임 계단: 이번 달 할 일 수와 완료 수 (v0.3)', () {
    final a = store.add('이번 달 기한', due: DateTime(2026, 11, 28))!;
    store.add('기한 없이 이번 달에 만듦');
    store.add('다음 달 기한', due: DateTime(2026, 12, 2));
    store.toggle(a.id);
    final s = store.monthStat(DateTime(2026, 11, 15));
    expect(s.total, 2);
    expect(s.done, 1);
  });

  test('다시 불러와도 그대로 (FR-10)', () async {
    store.add('유지되는 할 일', due: DateTime(2026, 11, 20), tags: const <String>['개인']);
    await store.flush();
    final reopened = TaskStore(repository: repo, clock: () => clock);
    await reopened.load();
    expect(reopened.tasks.single.title, '유지되는 할 일');
    expect(reopened.tasks.single.tags, <String>['개인']);
  });

  test('오늘 요약 숫자와 완료한 일 비우기·되돌리기 (v0.5)', () {
    final a = store.add('오늘 할 일', due: DateTime(2026, 11, 15))!;
    store.add('지난 일', due: DateTime(2026, 11, 10));
    final c = store.add('끝낸 일')!;
    store.toggle(c.id);
    expect(store.dueTodayOpenCount, 1);
    expect(store.delayedCount, 1);
    expect(store.doneTodayCount, 1);

    store.toggle(a.id);
    final removed = store.removeDone();
    expect(removed.length, 2);
    expect(store.doneCount, 0);
    expect(store.totalCount, 1);
    store.restoreAll(removed);
    expect(store.totalCount, 3);
    expect(store.tasks.map((t) => t.title), <String>['오늘 할 일', '지난 일', '끝낸 일']);
  });
}
