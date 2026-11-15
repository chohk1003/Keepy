import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'models/app_settings.dart';
import 'services/ocr_service.dart';
import 'state/keepy_scope.dart';
import 'state/settings_store.dart';
import 'state/task_store.dart';
import 'ui/shell/home_shell.dart';

/// 앱 루트. 화면 모드(시스템/라이트/다크, v0.4)를 정하고 전체에 적용한다.
class KeepyApp extends StatefulWidget {
  const KeepyApp({
    super.key,
    required this.tasks,
    required this.settings,
    required this.ocr,
  });

  final TaskStore tasks;
  final SettingsStore settings;
  final OcrService ocr;

  @override
  State<KeepyApp> createState() => _KeepyAppState();
}

class _KeepyAppState extends State<KeepyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 휴대폰의 다크 모드 설정이 바뀌면 '시스템' 모드일 때 따라간다.
  @override
  void didChangePlatformBrightness() => setState(() {});

  bool _isDark(AppearanceMode mode) => switch (mode) {
        AppearanceMode.dark => true,
        AppearanceMode.light => false,
        AppearanceMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final dark = _isDark(widget.settings.settings.appearance);
        // 색은 KeepyColors 가 이 값을 보고 고른다 (core/theme.dart).
        KeepyPalette.dark = dark;
        return KeepyScope(
          tasks: widget.tasks,
          settings: widget.settings,
          ocr: widget.ocr,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
            child: MaterialApp(
              title: 'Keepy',
              debugShowCheckedModeBanner: false,
              theme: buildKeepyTheme(dark: dark),
              scrollBehavior: const KeepyScrollBehavior(),
              locale: const Locale('ko', 'KR'),
              supportedLocales: const <Locale>[Locale('ko', 'KR'), Locale('en', 'US')],
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              // 모드가 바뀌면 화면 전체를 새 색으로 다시 그린다 (보던 탭은 HomeShell 이 기억).
              home: KeyedSubtree(key: ValueKey<bool>(dark), child: const HomeShell()),
            ),
          ),
        );
      },
    );
  }
}

/// iOS 식 스크롤: 끝에서 튕기고(바운스), 안드로이드 물결 효과는 없앤다.
/// 웹·데스크톱에서도 마우스로 끌어서 스와이프를 시험할 수 있게 한다.
class KeepyScrollBehavior extends MaterialScrollBehavior {
  const KeepyScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
