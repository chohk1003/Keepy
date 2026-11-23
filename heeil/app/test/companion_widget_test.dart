import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/main.dart';
import 'package:keepy/models/companion.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/widgets/companion_art.dart';
import 'package:keepy/widgets/quick_input_bar.dart';
import 'package:keepy/widgets/task_tile.dart';
import 'package:keepy/state/app_state.dart';
import 'package:keepy/util/dates.dart';

const previewDirectory = String.fromEnvironment('KEEPY_PREVIEWS');
const captureKey = Key('preview-boundary');

Future<void> advance(WidgetTester tester, [int ms = 1800]) async {
  for (var i = 0; i < ms; i += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  if (previewDirectory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$previewDirectory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<AppState> launch(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState();
  addTearDown(state.dispose);
  state.add('오늘의 공부', due: DateTime.now(), tags: {TaskTag.assignment});
  state.add('장보기', tags: {TaskTag.personal});
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: KeepyApp(state: state),
    ),
  );
  await advance(tester, 400);
  return state;
}

Finder get input => find
    .descendant(
      of: find.byType(QuickInputBar),
      matching: find.byType(TextField),
    )
    .first;

void main() {
  setUpAll(() async {
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
    await font.load();
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await icons.load();
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();
  });

  testWidgets('방은 전체 화면, 전달은 한 번, 입력 초안과 태그는 복귀 시 보존', (tester) async {
    final state = await launch(tester);
    state.setDone(state.tasks.first, true);
    await advance(tester);
    await capture(tester, '01-tasks');
    await tester.enterText(input, '입력하던 내용');
    await advance(tester, 400);
    await tester.tap(
      find
          .byWidgetPredicate((w) => w is TagToggle && w.tag == TaskTag.team)
          .first,
    );
    await advance(tester, 300);
    await tester.drag(
      find.byKey(const Key('companion-header')),
      const Offset(0, 110),
    );
    await advance(tester, 550);
    await capture(tester, '02-delivery');
    await advance(tester);
    final room = find.byKey(const Key('companion-room'));
    expect(tester.getSize(room), const Size(390, 844));
    expect(find.byType(QuickInputBar), findsNothing);
    expect(
      find.descendant(of: room, matching: find.byType(Text)),
      findsNothing,
    );
    expect(state.pendingCredits, isEmpty);
    final delivered = state.creditedTasks.single.credit!.deliveredAt;
    await capture(tester, '03-room');
    await tester.tap(find.byKey(const Key('room-close')));
    await advance(tester);
    expect(tester.widget<TextField>(input).controller!.text, '입력하던 내용');
    // The unfocused input's parent deliberately owns taps (and tab swipes).
    await tester.tapAt(tester.getCenter(input));
    await advance(tester, 300);
    expect(
      tester
          .widget<TagToggle>(
            find
                .byWidgetPredicate(
                  (w) => w is TagToggle && w.tag == TaskTag.team,
                )
                .first,
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('companion-header')));
    await advance(tester);
    expect(state.creditedTasks.single.credit!.deliveredAt, delivered);
    await tester.drag(room, const Offset(0, -140));
    await advance(tester);
    expect(room, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('별도 기록 화면에서 주간·월간 전환과 캐릭터 교체', (tester) async {
    final state = await launch(tester);
    state.setDone(state.tasks.first, true);
    await advance(tester);
    await tester.tap(find.byKey(const Key('companion-header')));
    await advance(tester);
    await tester.tap(find.byKey(const Key('room-reports')));
    await advance(tester);
    expect(find.text('주간'), findsOneWidget);
    await capture(tester, '04-weekly');
    await tester.tap(find.text('월간'));
    await advance(tester);
    expect(find.byType(GridView), findsOneWidget);
    await capture(tester, '05-monthly');
    await tester.scrollUntilVisible(
      find.text('고양이'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('고양이'));
    await advance(tester);
    expect(state.companion, CompanionKind.cat);
    await tester.tap(find.byKey(const Key('progress-back')));
    await advance(tester);
    expect(
      tester.widget<CompanionArt>(find.byType(CompanionArt)).kind,
      CompanionKind.cat,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면 편집: 취소는 유지, 달력·태그·제목은 저장 시 적용', (tester) async {
    final state = await launch(tester, size: const Size(320, 568));
    final task = state.tasks.firstWhere((t) => t.title == '오늘의 공부');
    await tester.tap(find.text(task.title));
    await advance(tester);
    await tester.enterText(
      find.byKey(const Key('task-title-editor')),
      '취소할 제목',
    );
    await tester.tap(find.byTooltip('취소'));
    await advance(tester);
    expect(task.title, '오늘의 공부');
    await tester.tap(find.text(task.title));
    await advance(tester);
    await tester.enterText(
      find.byKey(const Key('task-title-editor')),
      '수정한 공부',
    );
    await tester.tap(
      find.byWidgetPredicate((w) => w is TagToggle && w.tag == TaskTag.team),
    );
    await tester.ensureVisible(find.byKey(const Key('editor-calendar-toggle')));
    await tester.tap(find.byKey(const Key('editor-calendar-toggle')));
    await advance(tester);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('quick-date-내일')));
    await tester.tap(find.byKey(const ValueKey('quick-date-내일')));
    await tester.ensureVisible(find.byKey(const Key('task-editor-save')));
    await advance(tester);
    await tester.tap(find.byKey(const Key('task-editor-save')));
    await advance(tester);
    expect(task.title, '수정한 공부');
    expect(task.tags, containsAll([TaskTag.assignment, TaskTag.team]));
    expect(dayDiff(DateTime.now(), task.due!), 1);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('companion-header')));
    await advance(tester);
    expect(
      tester.getSize(find.byKey(const Key('companion-room'))),
      const Size(320, 568),
    );
    await capture(tester, '06-small-room');
    expect(tester.takeException(), isNull);
  });

  testWidgets('짧은 당김은 방을 열지 않고 왼쪽 스와이프는 2일·7일 선택', (tester) async {
    final state = await launch(tester);
    await tester.timedDrag(
      find.byKey(const Key('companion-header')),
      const Offset(0, 20),
      const Duration(seconds: 1),
    );
    await advance(tester);
    expect(find.byKey(const Key('companion-room')), findsNothing);
    final task = state.tasks.firstWhere((t) => t.title == '장보기');
    final tile = find.byWidgetPredicate(
      (w) => w is TaskTile && w.task.id == task.id,
    );
    expect(tester.widget(tile), isA<TaskTile>());
    await tester.drag(tile, const Offset(-155, 0));
    await advance(tester);
    expect(dayDiff(DateTime.now(), task.due!), 2);
    await tester.drag(tile, const Offset(-240, 0));
    await advance(tester);
    expect(dayDiff(DateTime.now(), task.due!), 7);
  });
}
