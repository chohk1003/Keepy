import 'package:flutter/cupertino.dart' show CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/app.dart';
import 'package:keepy/data/repositories.dart';
import 'package:keepy/services/ocr_service.dart';
import 'package:keepy/state/settings_store.dart';
import 'package:keepy/models/app_settings.dart';
import 'package:keepy/state/task_store.dart';
import 'package:keepy/ui/game/pool_page.dart';
import 'package:keepy/ui/shell/home_shell.dart';
import 'package:keepy/ui/widgets/undo_toast.dart';

late SettingsStore lastSettings;

/// 오리 수영장은 계속 움직이므로 pumpAndSettle 대신 몇 프레임만 넘긴다.
Future<void> pumpFrames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<TaskStore> pumpKeepy(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1179, 2556); // iPhone 15 Pro
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  HomeShell.lastIndex = HomeShell.mainIndex; // 테스트마다 메인 화면에서 시작

  final tasks = TaskStore(repository: InMemoryTaskRepository(), clock: () => DateTime(2026, 11, 15, 10));
  final settings = SettingsStore(repository: InMemorySettingsRepository());
  await tasks.load();
  await settings.load();
  lastSettings = settings;
  await tester.pumpWidget(KeepyApp(tasks: tasks, settings: settings, ocr: const UnsupportedOcrService()));
  await tester.pumpAndSettle();
  return tasks;
}

void main() {
  // 테스트 환경에는 센서 플러그인이 없으므로 기울기 입력을 비운다.
  setUpAll(() => PoolPage.tiltSource = () => const Stream<Offset>.empty());

  testWidgets('처음 켜면 빈 상태 안내가 보인다 (FR-06)', (tester) async {
    await pumpKeepy(tester);
    expect(find.text('등록된 태스크가 없습니다'), findsOneWidget);
    expect(find.text('모든 할 일'), findsOneWidget);
  });

  testWidgets('입력 바로 할 일을 추가하면 목록에 나타난다 (FR-02)', (tester) async {
    final store = await pumpKeepy(tester);

    await tester.tap(find.byKey(const Key('quick-input')), warnIfMissed: false);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('quick-input')), '자료구조 과제 제출');
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(store.totalCount, 1);
    expect(find.text('자료구조 과제 제출'), findsOneWidget);
    expect(find.text('등록된 태스크가 없습니다'), findsNothing);
  });

  testWidgets('완료·미완료 탭으로 걸러 본다 (FR-05)', (tester) async {
    final store = await pumpKeepy(tester);
    final a = store.add('끝낸 일')!;
    store.add('남은 일');
    store.toggle(a.id);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-done')));
    await tester.pumpAndSettle();
    expect(find.text('끝낸 일'), findsOneWidget);
    expect(find.text('남은 일'), findsNothing);

    await tester.tap(find.byKey(const Key('filter-open')));
    await tester.pumpAndSettle();
    expect(find.text('남은 일'), findsOneWidget);
    expect(find.text('끝낸 일'), findsNothing);
  });

  testWidgets('하단 탭으로 설정·날짜 화면에 간다 (FR-07)', (tester) async {
    await pumpKeepy(tester);

    await tester.tap(find.byKey(const Key('tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('선택한 날짜'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-0')));
    await tester.pumpAndSettle();
    expect(find.text('달력 행 수'), findsOneWidget);
  });

  testWidgets('편집을 누르면 순서 바꾸기 모드 (v0.3)', (tester) async {
    final store = await pumpKeepy(tester);
    store.add('하나');
    store.add('둘');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('완료'), findsWidgets);
    expect(find.text('오른쪽 손잡이(≡)를 끌어 순서를 바꿔요'), findsOneWidget);
  });

  testWidgets('POOL PARTY: 설정에서 켜야 오리 아이콘이 보이고, X 로 나간다 (v0.7)', (tester) async {
    await pumpKeepy(tester);
    expect(find.byKey(const Key('pool-shortcut')), findsNothing);

    lastSettings.update((s) => s.copyWith(miniGameEnabled: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pool-shortcut')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pool-shortcut')));
    await pumpFrames(tester, 6);
    expect(find.byKey(const Key('pool-canvas')), findsOneWidget);
    expect(find.text('11월 15일'), findsWidgets); // 날짜만
    expect(find.byKey(const ValueKey<String>('pool-scene-morning')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pool-close')));
    await pumpFrames(tester, 4);
    expect(find.byKey(const Key('pool-canvas')), findsNothing);
  });

  testWidgets('POOL PARTY: 완료율에 따라 아침 방 → 책상 → 수영장, 100% 에서 누르면 오리가 움직인다 (v0.7)', (tester) async {
    final store = await pumpKeepy(tester);
    final today = DateTime(2026, 11, 15);
    final a = store.add('하나', due: today)!;
    final b = store.add('둘', due: today)!;
    lastSettings.update((s) => s.copyWith(miniGameEnabled: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pool-shortcut')));
    await pumpFrames(tester, 6);
    expect(find.byKey(const ValueKey<String>('pool-scene-morning')), findsOneWidget); // 0% 아침 방

    store.toggle(a.id);
    await pumpFrames(tester, 3);
    expect(find.byKey(const ValueKey<String>('pool-scene-work')), findsOneWidget); // 50% 책상

    store.toggle(b.id);
    await pumpFrames(tester, 3);
    expect(find.byKey(const ValueKey<String>('pool-scene-party')), findsOneWidget); // 100% 수영장
    await tester.tapAt(tester.getTopLeft(find.byKey(const Key('pool-canvas'))) + const Offset(60, 500));
    await pumpFrames(tester, 10);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('pool-close')));
    await pumpFrames(tester, 4);
  });

  testWidgets('오늘 통계: POOL PARTY 화면 위쪽에 태그별로, 미지정 포함 (v0.7)', (tester) async {
    final store = await pumpKeepy(tester);
    final today = DateTime(2026, 11, 15);
    final t = store.add('과제 하기', due: today, tags: const <String>['과제'])!;
    store.add('운동', due: today, tags: const <String>['운동']);
    store.add('태그 없는 일');
    store.toggle(t.id);
    lastSettings.update((s) => s.copyWith(miniGameEnabled: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-stats')), findsNothing); // 메인에는 통계가 없다

    await tester.tap(find.byKey(const Key('pool-shortcut')));
    await pumpFrames(tester, 6);
    expect(find.byKey(const Key('today-stats')), findsOneWidget);
    expect(find.text('오늘 가장 많이 한 일'), findsOneWidget); // 안내 문구와
    expect(
      find.descendant(of: find.byKey(const Key('today-stats-top')), matching: find.text('#과제')),
      findsOneWidget,
    ); // 태그 칩은 따로
    expect(find.text('#운동'), findsWidgets);
    expect(find.text('미지정'), findsOneWidget);
    expect(find.text('상위 5개만 출력'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pool-close')));
    await pumpFrames(tester, 4);
  });

  testWidgets('할 일 수정: 태그는 하나만, 다른 태그를 누르면 기존 태그가 해제된다 (v0.7)', (tester) async {
    final store = await pumpKeepy(tester);
    final t = store.add('태그 바꾸기', tags: const <String>['과제'])!;
    await tester.pumpAndSettle();

    await tester.tap(find.text('태그 바꾸기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#개인').last);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.byId(t.id)!.tags, <String>['개인']);
  });

  testWidgets('다크 모드로 바꿔도 화면이 그대로 그려지고 보던 탭이 유지된다 (v0.4)', (tester) async {
    final store = await pumpKeepy(tester);
    store.add('다크 모드 확인');
    await tester.tap(find.byKey(const Key('tab-0')));
    await tester.pumpAndSettle();

    lastSettings.update((s) => s.copyWith(appearance: AppearanceMode.dark));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('달력 행 수'), findsOneWidget); // 설정 화면 그대로

    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('다크 모드 확인'), findsOneWidget);
  });

  testWidgets('할 일 수정: 빠른 날짜 선택 칩으로 기한 지정 (v0.4)', (tester) async {
    final store = await pumpKeepy(tester);
    final t = store.add('기한 정하기')!;
    await tester.pumpAndSettle();

    await tester.tap(find.text('기한 정하기'));
    await tester.pumpAndSettle();
    expect(find.text('할 일 수정'), findsOneWidget);
    expect(find.text('기한 정하기'), findsWidgets); // 제목이 입력 칸에 보인다

    await tester.tap(find.text('기한'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.byId(t.id)!.due, DateTime(2026, 11, 16));
  });

  testWidgets('오늘 요약과 완료한 일 비우기·취소 (v0.5)', (tester) async {
    final store = await pumpKeepy(tester);
    store.add('오늘 할 일', due: DateTime(2026, 11, 15));
    final done = store.add('끝낸 일')!;
    store.toggle(done.id);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sum-today')), findsOneWidget);
    expect(find.text('완료한 일'), findsOneWidget);

    await tester.tap(find.byKey(const Key('done-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비우기').last);
    // 되돌리기 알림은 0.6초만 보이므로 pumpAndSettle 로 끝까지 기다리지 않는다.
    // 대화상자가 다 닫힐 때까지만 조금씩 넘기고, 알림이 아직 떠 있을 때 알림 안의 '취소'를 누른다.
    await tester.pump();
    for (var i = 0; i < 12 && find.byType(CupertinoDialogAction).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(CupertinoDialogAction), findsNothing);
    expect(store.doneCount, 0);
    final undo = find.descendant(of: find.byType(UndoToastView), matching: find.text('취소'));
    expect(undo, findsOneWidget);

    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(store.doneCount, 1);
  });
}
