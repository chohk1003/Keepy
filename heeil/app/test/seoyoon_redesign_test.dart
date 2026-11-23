import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/models/companion.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/util/dates.dart';
import 'package:keepy/widgets/room_scene.dart';

import 'companion_widget_test.dart' show launch, advance;

/// 서윤님 v0.7.0 디자인 이식분 — 헤더 일일 통계, 방의 주간 그래프·장면 단계,
/// 완료 섹션 접기·비우기.
void main() {
  testWidgets('헤더 오른쪽에 오늘의 태그별 막대가 뜨고 완료하면 숫자가 오른다', (tester) async {
    final state = await launch(tester);
    // launch 가 넣어 둔 '오늘의 공부'(과제 태그, 오늘 기한) 하나가 학습으로 잡힌다
    expect(find.byKey(const Key('stat-bars')), findsOneWidget);
    expect(find.byKey(const Key('stat-bar-assignment')), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    state.setDone(state.tasks.firstWhere((t) => t.title == '오늘의 공부'), true);
    await advance(tester);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.byKey(const Key('header-rate')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('방의 주간 그래프 막대를 누르면 그 날짜로 넘어간다', (tester) async {
    final state = await launch(tester);
    await tester.tap(find.byKey(const Key('room-open')));
    await advance(tester);
    final today = dayOf(state.now);
    final start = weekStart(today);
    // 같은 주에서 오늘이 아닌 날 하나 (일요일이면 월요일을 고른다)
    final other = sameDay(start, today) ? addDays(start, 1) : start;
    expect(find.text(mdw(today)), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('week-bar-${dayKey(other)}')));
    await advance(tester);
    expect(find.text(mdw(other)), findsOneWidget);
    expect(find.byKey(const Key('room-today')), findsOneWidget);
    // 목록 화면의 선택일은 건드리지 않는다
    expect(sameDay(state.selectedDay, today), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('완료율에 따라 아침 방 → 책상 → 수영장으로 장면이 바뀐다', (tester) async {
    final state = await launch(tester);
    final today = dayOf(state.now);
    for (final t in state.tasks.toList()) {
      state.remove(t);
    }
    final first = state.add('보고서', due: today, tags: {TaskTag.assignment});
    final second = state.add('장보기', due: today, tags: {TaskTag.personal});
    await advance(tester);
    await tester.tap(find.byKey(const Key('room-open')));
    await advance(tester);
    expect(find.byKey(const ValueKey('room-scene-morning')), findsOneWidget);

    state.setDone(first, true);
    await advance(tester);
    expect(find.byKey(const ValueKey('room-scene-work')), findsOneWidget);

    state.setDone(second, true);
    await advance(tester);
    expect(find.byKey(const ValueKey('room-scene-party')), findsOneWidget);
    expect(duckSceneOf(done: 2, total: 2), DuckScene.party);
    expect(tester.takeException(), isNull);
  });

  testWidgets('완료 섹션은 접히고, 비우기는 취소로 되돌아온다', (tester) async {
    final state = await launch(tester);
    final task = state.tasks.firstWhere((t) => t.title == '오늘의 공부');
    state.setDone(task, true);
    await advance(tester);
    expect(find.text('오늘의 공부'), findsOneWidget);

    await tester.tap(find.byKey(const Key('done-collapse')));
    await advance(tester);
    expect(find.text('오늘의 공부'), findsNothing);
    await tester.tap(find.byKey(const Key('done-collapse')));
    await advance(tester);
    expect(find.text('오늘의 공부'), findsOneWidget);

    await tester.tap(find.byKey(const Key('done-clear')));
    await advance(tester, 400);
    await tester.tap(find.byKey(const Key('clear-done-confirm')));
    await advance(tester, 100);
    expect(state.tasks.where((t) => t.done), isEmpty);
    // 토스트의 '취소' (다이얼로그가 닫히는 동안에는 같은 문구가 둘이라 마지막 것)
    await tester.tap(find.text('취소').last);
    await advance(tester);
    expect(state.tasks.where((t) => t.done).length, 1);
    expect(tester.takeException(), isNull);
  });
}
