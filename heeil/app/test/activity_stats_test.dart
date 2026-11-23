import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/pages/activity_stats_sheet.dart';
import 'package:keepy/widgets/glass_tab_bar.dart';

import 'companion_widget_test.dart' show launch, advance;

void main() {
  testWidgets('하단 인디케이터에서 선택한 통계를 열고 옆으로 넘긴다', (tester) async {
    await launch(tester);
    expect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('room-open')));
    await advance(tester);
    final indicator = find.byKey(const ValueKey('activity-indicator-life'));
    expect(tester.getCenter(indicator).dy, greaterThan(650));
    await tester.tap(indicator);
    await advance(tester);
    expect(find.byType(ActivityStatsSheet), findsOneWidget);
    expect(find.text('생활 기록'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('activity-stats-pages')),
      const Offset(-300, 0),
    );
    await advance(tester);
    expect(find.text('기타 기록'), findsOneWidget);
    await tester.tap(find.text('최근 30일'));
    await advance(tester);
    await tester.tap(find.byTooltip('닫기'));
    await advance(tester);
    expect(find.byKey(const Key('companion-room')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
