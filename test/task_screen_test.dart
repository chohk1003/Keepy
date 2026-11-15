import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepy_prototype/core/repositories/shared_preferences_task_repository.dart';
import 'package:keepy_prototype/features/task/viewmodels/task_view_model.dart';
import 'package:keepy_prototype/features/task/views/task_screen.dart';

import 'shared_preferences_task_repository_test.dart' show FakePreferences;

void main() {
  testWidgets('empty, add, toggle, filters, edit, delete and restart', (
    tester,
  ) async {
    final prefs = FakePreferences();
    final repo = SharedPreferencesTaskRepository(preferences: prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: TaskScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('표시할 태스크가 없습니다.'), findsOneWidget);

    Future<void> add(String title) async {
      await tester.tap(find.text('태스크 추가'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, title);
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
    }

    Future<void> filter(String label) async {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
    }

    await add('과제 A');
    await add('과제 B');
    expect(find.text('과제 A'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await filter('완료');
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await filter('미완료');
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byTooltip('태스크 메뉴'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '수정된 과제');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('수정된 과제'), findsOneWidget);
    await filter('전체');
    expect(find.byType(Checkbox), findsNWidgets(2));
    await filter('미완료');
    await tester.tap(find.byTooltip('태스크 메뉴'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('표시할 태스크가 없습니다.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final restarted = SharedPreferencesTaskRepository(preferences: prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(restarted)],
        child: const MaterialApp(home: TaskScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('수정된 과제'), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final closing = Future.wait([repo.dispose(), restarted.dispose()]);
    await tester.pump();
    await closing;
  });
}
