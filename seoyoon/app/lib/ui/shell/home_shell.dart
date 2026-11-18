import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../state/keepy_scope.dart';
import '../ocr/ocr_capture_page.dart';
import '../ocr/ocr_review_sheet.dart';
import '../pages/date_page.dart';
import '../pages/main_page.dart';
import '../pages/settings_page.dart';
import '../widgets/keepy_tab_bar.dart';
import '../widgets/quick_input_bar.dart';
import '../widgets/task_actions.dart';
import '../widgets/task_editor_sheet.dart';
import '../widgets/task_tile.dart';
import '../widgets/undo_toast.dart';

/// 3단 화면 틀 (요구사항 3.2 / UI 설계서 04 / FR-07).
///
/// [설정] ← [메인] → [날짜] 를 좌우로 넘긴다. 하단 탭 바로도 이동한다.
/// 입력 바는 메인·날짜 화면에서 공유하며, 날짜 화면에서 입력하면
/// 고른 날짜가 기한으로 자동 지정된다 (UI 설계서 03-3).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// 입력 바 위 '사라짐 + 탭 전환' 영역 높이 (할 일 블럭 1개 정도, prompts_log #12).
  static const fadeZone = 72.0;

  /// 마지막으로 보던 탭. 다크 모드 전환으로 화면을 새로 그려도 같은 탭에서 시작한다.
  static int lastIndex = mainIndex;

  static const settingsIndex = 0;
  static const mainIndex = 1;
  static const dateIndex = 2;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final PageController _pages = PageController(initialPage: HomeShell.lastIndex);
  final ToastController _toast = ToastController();
  final SwipeGroupController _swipes = SwipeGroupController();
  final FocusNode _inputFocus = FocusNode();

  int _index = HomeShell.lastIndex;
  DateTime? _selected; // null 이면 오늘
  TaskActions? _actions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = KeepyScope.of(context);
    if (_actions?.store != scope.tasks) {
      _actions = TaskActions(store: scope.tasks, toast: _toast, openEditor: _openEditor);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _toast.dispose();
    _swipes.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  DateTime get _selectedDate => _selected ?? KeepyScope.of(context).tasks.today;

  // ------------------------------------------------------------ 이동

  void _goTo(int index) {
    if (index < 0 || index > 2 || index == _index) return;
    HapticFeedback.selectionClick();
    _pages.animateToPage(index, duration: KeepyMotion.page, curve: KeepyMotion.settle);
  }

  void _onPageChanged(int index) {
    HomeShell.lastIndex = index;
    setState(() => _index = index);
    _swipes.closeAll();
    _inputFocus.unfocus();
    _toast.dismiss();
  }

  void _selectDate(DateTime day) => setState(() => _selected = dateOnly(day));

  // ------------------------------------------------------------ 입력

  bool _submit(String title, List<String> tags) {
    final store = KeepyScope.of(context).tasks;
    final due = _index == HomeShell.dateIndex ? _selectedDate : null;
    final task = store.add(title, due: due, tags: tags);
    if (task == null) {
      _toast.show(TitleRule.errorOf(title) ?? '추가하지 못했어요');
      return false;
    }
    return true;
  }

  Future<void> _openCamera() async {
    _inputFocus.unfocus();
    _swipes.closeAll();
    final scope = KeepyScope.of(context);
    final candidates = await OcrCapturePage.open(context, scope.ocr);
    if (!mounted || candidates == null || candidates.isEmpty) return;
    final titles = await showOcrReview(context, candidates);
    if (!mounted || titles == null || titles.isEmpty) return;
    final added = scope.tasks.addAll(
      titles,
      due: _index == HomeShell.dateIndex ? _selectedDate : null,
    );
    if (added.isEmpty) return;
    _toast.show(
      '${added.length}개를 추가했어요',
      actionLabel: '취소',
      onAction: () {
        for (final t in added) {
          scope.tasks.remove(t.id);
        }
      },
    );
  }

  void _openEditor(Task task) {
    _swipes.closeAll();
    _inputFocus.unfocus();
    showTaskEditor(
      context,
      store: KeepyScope.of(context).tasks,
      task: task,
      onDelete: () => _actions!.delete(task),
    );
  }

  // ------------------------------------------------------------ 화면

  @override
  Widget build(BuildContext context) {
    final actions = _actions!;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showInput = _index != HomeShell.settingsIndex;
    const listBottom = HomeShell.fadeZone + 8;

    return PopScope(
      canPop: _index == HomeShell.mainIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(HomeShell.mainIndex);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Listener(
          // 알림 밖 아무 곳이나 누르면 알림을 즉시 닫는다 (prompts_log #9)
          onPointerDown: (_) => _toast.handleGlobalPointerDown(),
          child: SwipeGroup(
            controller: _swipes,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      PageView(
                        controller: _pages,
                        onPageChanged: _onPageChanged,
                        children: <Widget>[
                          SettingsPage(toast: _toast, bottomInset: 32),
                          MainPage(
                            actions: actions,
                            bottomInset: listBottom,
                            onEditingChanged: (_) => _swipes.closeAll(),
                            onOpenToday: () {
                              _selectDate(KeepyScope.of(context).tasks.today);
                              _goTo(HomeShell.dateIndex);
                            },
                          ),
                          DatePage(
                            selected: _selectedDate,
                            onSelect: _selectDate,
                            actions: actions,
                            bottomInset: listBottom,
                          ),
                        ],
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 10,
                        child: Center(child: UndoToastView(controller: _toast)),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: KeepyMotion.normal,
                  curve: KeepyMotion.settle,
                  alignment: Alignment.topCenter,
                  child: showInput
                      ? QuickInputBar(
                          key: const Key('quick-input-bar'),
                          focusNode: _inputFocus,
                          hint: _index == HomeShell.dateIndex
                              ? '${formatMonthDay(_selectedDate)}에 할 일 추가'
                              : '새로운 태스크를 입력하세요',
                          onSubmit: _submit,
                          onCamera: _openCamera,
                          onSwipe: (dir) => _goTo(_index + dir),
                          onInvalid: (message) => _toast.show(message),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                if (!keyboardOpen) KeepyTabBar(index: _index, onTap: _goTo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
