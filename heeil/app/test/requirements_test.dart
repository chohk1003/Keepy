import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/models/companion.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/theme.dart';
import 'package:keepy/util/dates.dart';
import 'package:keepy/widgets/week_activity_graph.dart';

import 'companion_widget_test.dart' show launch, advance;

/// 요구사항 문서(Keepy요구사항)에서 새로 들어온 것들 —
/// 주식창식 그래프 정렬, 상위 3개 태그색, 화이트·다크 테마.
void main() {
  testWidgets('주간 그래프는 오늘을 맨 오른쪽에 둔다', (tester) async {
    final state = await launch(tester);
    await tester.tap(find.byKey(const Key('companion-header')));
    await advance(tester);
    final today = dayOf(state.now);
    final xs = <double>[];
    for (var i = 0; i < WeekActivityGraph.span; i++) {
      final d = addDays(today, -i);
      final bar = find.byKey(ValueKey('week-bar-${dayKey(d)}'));
      expect(bar, findsOneWidget, reason: '최근 7일이 모두 보여야 한다');
      xs.add(tester.getCenter(bar).dx);
    }
    // 오늘(i = 0)이 가장 오른쪽, 하루씩 과거로 갈수록 왼쪽
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], lessThan(xs[i - 1]));
    }
    // 창을 벗어난 날(8일 전)은 그려지지 않는다
    expect(
      find.byKey(ValueKey('week-bar-${dayKey(addDays(today, -8))}')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('막대는 상위 3개 태그만 색을 쓰고 나머지는 기타로 묶는다', (tester) async {
    final state = await launch(tester);
    final today = dayOf(state.now);
    for (final t in state.tasks.toList()) {
      state.remove(t);
    }
    // 네 태그를 모두 쓰면 색은 많은 순 3개까지만
    for (final entry in {
      TaskTag.assignment: 4,
      TaskTag.lecture: 3,
      TaskTag.team: 2,
      TaskTag.personal: 1,
    }.entries) {
      for (var i = 0; i < entry.value; i++) {
        state.setDone(
          state.add('${entry.key.name}$i', due: today, tags: {entry.key}),
          true,
        );
      }
    }
    await advance(tester);
    await tester.tap(find.byKey(const Key('companion-header')));
    await advance(tester);
    expect(find.byKey(const Key('week-activity-graph')), findsOneWidget);
    expect(WeekActivityGraph.colored, 3);
    // 통계 자체는 태그 네 개를 그대로 센다 (색만 묶는다)
    expect(state.tagCreditsOn(today).keys.whereType<TaskTag>().length, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('테마를 다크로 바꾸면 캐릭터 배경색까지 바뀐다', (tester) async {
    addTearDown(() => applyTone(false));
    final state = await launch(tester);
    expect(isDarkTone, isFalse);
    final light = K.room;

    state.setTheme(AppTheme.dark);
    await advance(tester, 400);
    expect(isDarkTone, isTrue);
    expect(K.room, isNot(light), reason: '노란 띠가 호박색으로 내려가야 한다');
    expect(K.bgSoft.computeLuminance(), lessThan(0.1));

    state.setTheme(AppTheme.light);
    await advance(tester, 400);
    expect(isDarkTone, isFalse);
    expect(K.room, light);
    expect(tester.takeException(), isNull);
  });
}
