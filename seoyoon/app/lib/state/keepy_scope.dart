import 'package:flutter/widgets.dart';

import '../services/ocr_service.dart';
import 'settings_store.dart';
import 'sync_controller.dart';
import 'task_store.dart';

/// 앱 전역 의존성 전달 (별도 상태관리 패키지 없이 InheritedWidget 하나로).
///
/// 화면에서는 `KeepyScope.of(context).tasks` 로 꺼내고,
/// 변경 감지는 `ListenableBuilder(listenable: store, ...)` 로 한다.
class KeepyScope extends InheritedWidget {
  const KeepyScope({
    super.key,
    required this.tasks,
    required this.settings,
    required this.ocr,
    required this.sync,
    required super.child,
  });

  final TaskStore tasks;
  final SettingsStore settings;
  final OcrService ocr;

  /// 서버 동기화 (MP3). 설정이 없으면 '꺼짐' 상태의 컨트롤러가 들어온다.
  final SyncController sync;

  static KeepyScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KeepyScope>();
    assert(scope != null, 'KeepyScope 가 위젯 트리에 없습니다.');
    return scope!;
  }

  @override
  bool updateShouldNotify(KeepyScope oldWidget) =>
      tasks != oldWidget.tasks || settings != oldWidget.settings || ocr != oldWidget.ocr || sync != oldWidget.sync;
}
