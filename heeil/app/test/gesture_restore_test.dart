import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/widgets/task_tile.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/state/app_state.dart';

import 'widget_test.dart' show boot, settle;

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('card height stays stable at width $width scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final task = Task(
          id: 'height',
          title: '줄바꿈이 생기기 쉬운 아주 긴 할 일 제목을 넣어서 확인합니다',
          due: DateTime(2020, 1, 1),
          tags: TaskTag.values.toSet(),
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  TaskTile(
                    task: task,
                    status: TaskStatus.overdue,
                    tagOrder: TaskTag.values,
                    onToggle: () {},
                    onTap: () {},
                    onDial: (_) {},
                    onTag: (_) {},
                    onDelete: () {},
                  ),
                  const SizedBox(key: Key('next-card'), height: 68),
                ],
              ),
            ),
          ),
        );
        await settle(tester);
        final tile = find.byType(TaskTile);
        final height = tester.getSize(tile).height;
        final nextY = tester.getTopLeft(find.byKey(const Key('next-card'))).dy;
        for (final direction in [-1.0, 1.0]) {
          final gesture = await tester.startGesture(tester.getCenter(tile));
          await gesture.moveBy(Offset(direction * 22, 0));
          for (final distance in [35.0, 50.0, 80.0]) {
            await gesture.moveBy(Offset(direction * distance, 0));
            await settle(tester, 150);
            expect(tester.getSize(tile).height, height);
            expect(
              tester.getTopLeft(find.byKey(const Key('next-card'))).dy,
              nextY,
            );
            expect(tester.takeException(), isNull);
          }
          await gesture.moveBy(const Offset(0, 28));
          await gesture.up();
          await settle(tester);
          expect(tester.getSize(tile).height, height);
        }
        final metadata = tester.widget<Text>(
          find.byKey(const ValueKey('meta-height')),
        );
        expect(metadata.maxLines, 1);
        expect(metadata.textSpan!.toPlainText(), contains('#팀 프로젝트'));
      });
    }
  }
  for (final horizontal in [-100.0, 110.0]) {
    for (final vertical in [-1.0, 1.0]) {
      testWidgets(
        'cancel $horizontal then scroll $vertical with same pointer',
        (tester) async {
          final state = await boot(
            tester,
            titles: List.generate(30, (i) => '작업 $i'),
          );
          final scroll = tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(CustomScrollView).first,
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position;
          scroll.jumpTo(300);
          await tester.pump();
          final tile = find.byType(TaskTile).hitTestable().at(1);
          final task = tester.widget<TaskTile>(tile).task;
          final due = task.due;
          final gesture = await tester.startGesture(tester.getCenter(tile));
          await gesture.moveBy(Offset(horizontal.sign * 22, 0));
          await gesture.moveBy(Offset(horizontal, 0));
          await settle(tester, 150);
          final before = scroll.pixels;
          await gesture.moveBy(Offset(0, vertical * 30));
          await tester.pump();
          expect(scroll.pixels, closeTo(before, 1));
          await gesture.moveBy(Offset(0, vertical * 60));
          await tester.pump();
          expect((scroll.pixels - before) * vertical, lessThan(-20));
          final moved = scroll.pixels;
          await gesture.moveBy(Offset(0, -vertical * 40));
          await tester.pump();
          expect((scroll.pixels - moved) * vertical, greaterThan(15));
          await gesture.cancel();
          await settle(tester);
          expect(state.tasks.length, 30);
          expect(task.due, due);
          expect(find.byKey(ValueKey('act-${task.id}')), findsNothing);
          expect(find.byKey(ValueKey('del-${task.id}')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final delay in [0, 40, 80]) {
    testWidgets('regrab date return after $delay ms preserves position', (
      tester,
    ) async {
      final state = await boot(tester, titles: ['다시 잡기']);
      final tile = find.byType(TaskTile).first;
      final first = await tester.startGesture(tester.getCenter(tile));
      await first.moveBy(const Offset(-22, 0));
      await first.moveBy(const Offset(-170, 0));
      await settle(tester, 250);
      await first.moveBy(const Offset(0, 30));
      await first.up();
      await tester.pump();
      await tester.pump(Duration(milliseconds: delay));
      final action = find.byKey(ValueKey('act-${state.tasks.single.id}'));
      final before = tester.getSize(action).width;
      final second = await tester.startGesture(tester.getCenter(tile));
      await second.moveBy(const Offset(-22, 0));
      await tester.pump();
      expect(tester.getSize(action).width, closeTo(before, 1));
      await second.moveBy(const Offset(-1, 0));
      await settle(tester, 200);
      expect(tester.getSize(action).width, closeTo(before, 8));
      await second.moveBy(const Offset(0, -30));
      await second.up();
      await settle(tester);
      expect(state.tasks.single.due, isNull);
      expect(
        find.byKey(ValueKey('act-${state.tasks.single.id}')),
        findsNothing,
      );
    });
  }
  for (final horizontal in [-100.0, 110.0]) {
    for (final vertical in [-28.0, 28.0]) {
      testWidgets(
        'horizontal $horizontal then vertical $vertical cancels without mutation',
        (tester) async {
          final state = await boot(tester, titles: ['취소 검증']);
          final task = state.tasks.single;
          final due = task.due;
          final tile = find.byType(TaskTile).first;
          final gesture = await tester.startGesture(tester.getCenter(tile));
          await gesture.moveBy(Offset(horizontal.sign * 22, 0));
          await gesture.moveBy(Offset(horizontal, 0));
          await settle(tester, 180);
          await gesture.moveBy(Offset(0, vertical));
          await gesture.moveBy(Offset(horizontal.sign * 200, 0));
          await gesture.up();
          await settle(tester, 500);
          expect(state.tasks.single.id, task.id);
          expect(state.tasks.single.due, due);
          expect(find.byKey(ValueKey('act-${task.id}')), findsNothing);
          expect(find.byKey(ValueKey('del-${task.id}')), findsNothing);
        },
      );
    }
  }
  testWidgets('short drag reveals readable date then expands slowly', (
    tester,
  ) async {
    final state = await boot(tester, titles: ['스냅 검증']);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TaskTile).first),
    );
    await gesture.moveBy(const Offset(-22, 0));
    await gesture.moveBy(const Offset(-30, 0));
    await settle(tester, 200);
    final action = find.byKey(ValueKey('act-${state.tasks.single.id}'));
    final width = tester.getSize(action).width;
    expect(width, greaterThan(70));
    expect(find.text('그대로'), findsNothing);
    expect(find.text('+1일'), findsOneWidget);
    await gesture.moveBy(const Offset(-40, 0));
    await settle(tester, 200);
    expect(tester.getSize(action).width - width, lessThan(20));
    await gesture.moveBy(const Offset(0, 30));
    await gesture.up();
    await settle(tester);
  });
}
