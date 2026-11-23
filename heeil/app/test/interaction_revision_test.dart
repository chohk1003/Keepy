import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'companion_widget_test.dart' show launch, advance;

void main() {
  testWidgets('양 끝 페이지는 바깥쪽으로 끌어도 움직이지 않는다', (tester) async {
    await launch(tester);
    final pager = find.byType(PageView).first;
    final controller = tester.widget<PageView>(pager).controller!;
    for (final end in [0, 2]) {
      controller.jumpToPage(end);
      await advance(tester);
      final position = controller.position;
      final before = position.pixels;
      final gesture = await tester.startGesture(const Offset(190, 740));
      await gesture.moveBy(Offset(end == 0 ? 240 : -240, 0));
      await tester.pump();
      expect(position.pixels, before);
      await gesture.up();
      await advance(tester);
      expect(position.pixels, before);
    }
  });
  testWidgets('빠른 짧은 당김은 방을 열지 않는다', (tester) async {
    await launch(tester);
    final header = find.byKey(const Key('companion-header'));
    expect(tester.getSize(header).height, 148);
    await tester.fling(header, const Offset(0, 32), 1800);
    await advance(tester);
    expect(find.byKey(const Key('companion-room')), findsNothing);
  });
  testWidgets('월 옆 행 선택은 달력 설정을 바꾼다', (tester) async {
    final state = await launch(tester);
    await tester.tap(find.byTooltip('날짜'));
    await advance(tester);
    final before = tester
        .getSize(find.byKey(const Key('calendar-area')))
        .height;
    await tester.tap(find.byKey(const Key('calendar-rows')));
    await advance(tester, 300);
    await tester.tap(find.text('4행'));
    await advance(tester);
    expect(state.calendarRows, 4);
    expect(
      tester.getSize(find.byKey(const Key('calendar-area'))).height,
      before + 48,
    );
    await tester.tap(find.byKey(const Key('calendar-rows')));
    await advance(tester, 300);
    await tester.tap(find.text('1행'));
    await advance(tester);
    expect(
      tester.getSize(find.byKey(const Key('calendar-area'))).height,
      before - 24,
    );
    expect(find.text('1행'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
