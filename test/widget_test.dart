import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/main.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/state/app_state.dart';
import 'package:keepy/util/dates.dart';
import 'package:keepy/widgets/quick_input_bar.dart';
import 'package:keepy/widgets/square_check.dart';
import 'package:keepy/widgets/task_tile.dart';

// 반복 애니메이션(흐르는 그라데이션 등)이 있어 pumpAndSettle 대신 시간 지정 pump 사용
Future<void> settle(WidgetTester tester, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<AppState> boot(WidgetTester tester, {List<String> titles = const []}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final s = AppState(seed: false);
  for (final t in titles.reversed) {
    s.add(t);
  }
  await tester.pumpWidget(KeepyApp(state: s));
  await settle(tester, 300);
  return s;
}

Finder get mainInput => find
    .descendant(of: find.byType(QuickInputBar), matching: find.byType(TextField))
    .first;

void main() {
  testWidgets('빈 상태 → 입력 바로 추가', (tester) async {
    final s = await boot(tester);
    expect(find.text('할 일 없음'), findsOneWidget);

    await tester.enterText(mainInput, '테스트');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await settle(tester);

    expect(s.tasks.single.title, '테스트');
    expect(find.text('테스트'), findsOneWidget);
  });

  testWidgets('공백 입력은 등록되지 않음', (tester) async {
    final s = await boot(tester);
    await tester.enterText(mainInput, '   ');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await settle(tester);
    expect(s.tasks, isEmpty);
  });

  testWidgets('네모 체크 → 잠시 뒤 완료, 토스트 취소 → 되돌림', (tester) async {
    final s = await boot(tester, titles: ['과제']);

    await tester.tap(find.byType(SquareCheck).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(s.tasks.first.done, isFalse, reason: '체크 애니메이션 동안은 아직 이동 전');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(s.tasks.first.done, isTrue);
    expect(s.doneLog.length, 1);

    // 토스트는 0.6초만 떠 있으므로 그 안에 취소
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(s.tasks.first.done, isFalse);
    expect(s.doneLog, isEmpty);
  });

  testWidgets('토스트는 0.6초 뒤 사라짐', (tester) async {
    final s = await boot(tester, titles: ['과제']);
    await tester.tap(find.byType(SquareCheck).first);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('취소'), findsOneWidget);
    await settle(tester, 1000);
    expect(find.text('취소'), findsNothing);
    expect(s.tasks.first.done, isTrue);
  });

  Future<Rect> openActions(WidgetTester tester, AppState s, [String title = '과제']) async {
    final tile = find.ancestor(of: find.text(title), matching: find.byType(TaskTile));
    await tester.drag(tile, const Offset(-240, 0));
    await settle(tester, 600);
    final id = s.tasks.firstWhere((t) => t.title == title).id;
    return tester.getRect(find.byKey(ValueKey('act-$id')));
  }

  testWidgets('왼쪽 스와이프 → 열린 채 유지 → 날짜 끌기로 +N일', (tester) async {
    final s = await boot(tester, titles: ['과제']);
    final area = await openActions(tester, s);
    expect(area.width, greaterThan(100), reason: '손을 떼도 액션 영역이 열려 있어야 함');

    await tester.dragFrom(area.centerLeft + const Offset(20, 0), const Offset(-80, 0));
    await settle(tester, 1400);

    expect(dayDiff(DateTime.now(), s.tasks.single.due!), inInclusiveRange(1, 3));
  });

  testWidgets('날짜 다이얼은 되돌리면 "그대로"(변화 없음)', (tester) async {
    final s = await boot(tester, titles: ['과제']);
    final area = await openActions(tester, s);
    final g = await tester.startGesture(area.centerLeft + const Offset(20, 0));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-60, 0));
    await tester.pump();
    await g.moveBy(const Offset(120, 0)); // 다시 오른쪽으로 → 0단계
    await tester.pump();
    expect(find.text('그대로'), findsWidgets);
    await g.up();
    await settle(tester, 1400);
    expect(s.tasks.single.due, isNull);
  });

  testWidgets('왼쪽 스와이프 → 태그 끌기로 가장 많이 쓴 태그 지정', (tester) async {
    final s = await boot(tester, titles: ['과제', '수업']);
    s.update(s.tasks[1], tags: {TaskTag.team}); // 팀 프로젝트가 가장 많이 쓰임
    await tester.pump();
    final area = await openActions(tester, s);

    await tester.dragFrom(area.centerRight - const Offset(20, 0), const Offset(-70, 0));
    await settle(tester, 1400);

    expect(s.tasks.firstWhere((t) => t.title == '과제').tags, {TaskTag.team});
  });

  testWidgets('끄는 도중 위·아래로 벗어나면 취소', (tester) async {
    final s = await boot(tester, titles: ['과제']);
    final tile = find.ancestor(of: find.text('과제'), matching: find.byType(TaskTile));
    final g = await tester.startGesture(tester.getCenter(tile));
    await g.moveBy(const Offset(-30, 0));
    await g.moveBy(const Offset(-80, 0));
    await tester.pump();
    await g.moveBy(const Offset(0, 60)); // 아래로 벗어남
    await tester.pump();
    await g.up();
    await settle(tester, 800);
    expect(find.byKey(ValueKey('act-${s.tasks.single.id}')), findsNothing);
  });

  testWidgets('열린 상태에서 카드를 누르면 원래대로', (tester) async {
    final s = await boot(tester, titles: ['과제']);
    await openActions(tester, s);
    await tester.tap(find.text('과제'));
    await settle(tester, 600);
    expect(find.byKey(ValueKey('act-${s.tasks.single.id}')), findsNothing);
  });

  test('분류: 기한 지남 → 지연, 지연 후 완료 → 늦은 완료', () {
    final s = AppState(seed: false);
    final t = s.add('과제', due: DateTime.now().subtract(const Duration(days: 2)));
    expect(s.statusOf(t), TaskStatus.overdue);
    s.setDone(t, true);
    expect(s.statusOf(t), TaskStatus.late);

    final u = s.add('오늘 할 일', due: DateTime.now());
    expect(s.statusOf(u), TaskStatus.pending);
    s.setDone(u, true);
    expect(s.statusOf(u), TaskStatus.done);
  });

  test('날짜순 정렬: 기한 빠른 순, 기한 없음은 뒤', () {
    final s = AppState(seed: false);
    s.add('없음');
    s.add('모레', due: DateTime.now().add(const Duration(days: 2)));
    s.add('내일', due: DateTime.now().add(const Duration(days: 1)));
    expect(s.todo.map((t) => t.title).toList(), ['내일', '모레', '없음']);
  });

  testWidgets('오른쪽 스와이프 → 삭제 버튼에 스냅, 누르면 삭제', (tester) async {
    final s = await boot(tester, titles: ['과제']);
    final tile = find.ancestor(of: find.text('과제'), matching: find.byType(TaskTile));
    await tester.drag(tile, const Offset(150, 0));
    await settle(tester, 600);
    expect(s.tasks, isNotEmpty, reason: '스냅만 되고 아직 삭제 전');

    final del = find.byKey(ValueKey('del-${s.tasks.single.id}'));
    expect(del, findsOneWidget);
    await tester.tap(del);
    await settle(tester, 1400);
    expect(s.tasks, isEmpty);
  });

  testWidgets('오른쪽으로 더 세게 끌면 바로 삭제', (tester) async {
    final s = await boot(tester, titles: ['과제']);
    final tile = find.ancestor(of: find.text('과제'), matching: find.byType(TaskTile));
    await tester.drag(tile, const Offset(320, 0));
    await settle(tester, 1400);
    expect(s.tasks, isEmpty);
  });

  testWidgets('JSON 직렬화 왕복', (tester) async {
    final t = Task(
      id: 'x',
      title: '과제',
      due: DateTime(2026, 11, 3),
      tags: {TaskTag.team, TaskTag.lecture},
    );
    final back = Task.fromJson(t.toJson());
    expect(back.title, '과제');
    expect(back.due, DateTime(2026, 11, 3));
    expect(back.tags, {TaskTag.team, TaskTag.lecture});
  });
}
