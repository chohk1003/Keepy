import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/app.dart';
import 'package:keepy/data/repositories.dart';
import 'package:keepy/services/ocr_service.dart';
import 'package:keepy/state/settings_store.dart';
import 'package:keepy/models/app_settings.dart';
import 'package:keepy/state/task_store.dart';
import 'package:keepy/ui/shell/home_shell.dart';

late SettingsStore lastSettings;

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

  testWidgets('미니게임: 설정에서 켜야 아이콘이 보이고, X 로 나간다 (v0.3)', (tester) async {
    await pumpKeepy(tester);
    expect(find.byKey(const Key('game-shortcut')), findsNothing);

    lastSettings.update((s) => s.copyWith(miniGameEnabled: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-shortcut')), findsOneWidget);

    await tester.tap(find.byKey(const Key('game-shortcut')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('11월 계단 오르기'), findsOneWidget);
    expect(find.text('아직 계단이 없어요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('game-close')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('11월 계단 오르기'), findsNothing);
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

  testWidgets('미니게임 꾸미기: 여자 캐릭터 + 고양이 (v0.4)', (tester) async {
    await pumpKeepy(tester);
    lastSettings.update((s) => s.copyWith(miniGameEnabled: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('game-shortcut')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('꾸미기 · 캐릭터와 펫'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.byKey(const Key('char-girl')));
    await tester.tap(find.byKey(const Key('pet-cat')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(lastSettings.settings.characterStyle, CharacterStyle.girl);
    expect(lastSettings.settings.pet, PetKind.cat);
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
    await tester.pumpAndSettle();
    expect(store.doneCount, 0);

    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();
    expect(store.doneCount, 1);
  });
}
