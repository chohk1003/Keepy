import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/auth_service.dart';
import 'data/firebase_env.dart';
import 'data/firestore_backend.dart';
import 'data/local_store.dart';
import 'data/sync_store.dart';
import 'pages/home_shell.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/companion_art.dart';

/// 저장소 열기를 기다리는 한계. 넘으면 시작 화면에 다시 시도 버튼을 띄운다.
const _storeTimeout = Duration(seconds: 5);

/// Firebase 초기화를 기다리는 한계. 넘으면 로컬 전용(게스트)으로 그냥 연다 —
/// 네트워크가 느리다고 앱이 안 열리면 안 된다.
const _syncTimeout = Duration(seconds: 6);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  // 초기화를 기다리는 동안 빈 화면이 되지 않도록 시작 화면부터 띄운다.
  runApp(const KeepyBoot());
}

/// 저장소·동기화를 준비하는 동안 보여 줄 시작 화면. 준비가 끝나면 [KeepyApp] 으로 바뀐다.
class KeepyBoot extends StatefulWidget {
  const KeepyBoot({super.key});

  @override
  State<KeepyBoot> createState() => _KeepyBootState();
}

class _KeepyBootState extends State<KeepyBoot> {
  AppState? _state;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    final LocalStore local;
    try {
      local = await LocalStore.open().timeout(_storeTimeout);
    } catch (e) {
      debugPrint('[boot] 저장소를 열지 못했습니다: $e');
      if (mounted) setState(() => _error = '저장한 할 일을 불러오지 못했어요.');
      return;
    }
    // MP3: .env 설정이 있으면 Firebase 동기화, 없으면 로컬 저장만 (게스트)
    final sync = await _startFirebase(local)
        .timeout(_syncTimeout, onTimeout: () => null);
    final state = AppState(store: sync ?? local);
    if (sync != null) {
      // 첫 실행 샘플은 메모리에만 있으므로 먼저 저장해 둬야 로그인 시 서버로 올라간다
      try {
        await state.flush();
      } catch (e) {
        debugPrint('[boot] 첫 저장 실패: $e');
      }
      sync.onRemoteTasks = state.applyRemote;
      sync.start();
    }
    if (!mounted) {
      state.dispose();
      return;
    }
    setState(() => _state = state);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state != null) return KeepyApp(state: state);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        key: const Key('boot-screen'),
        backgroundColor: K.room,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 132, height: 132, child: CompanionArt()),
              const SizedBox(height: 10),
              Text('Keepy', style: T.title2.copyWith(color: K.onRoom)),
              const SizedBox(height: 10),
              if (_error == null)
                Text(
                  '할 일을 불러오는 중',
                  style: T.caption.copyWith(color: K.onRoomDim),
                )
              else ...[
                Text(
                  _error!,
                  style: T.caption.copyWith(color: K.onRoom),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('boot-retry'),
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: K.onRoomAccent,
                    foregroundColor: K.room,
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Firebase 초기화. 설정이 없거나 실패하면 null → 로컬 전용으로 계속 실행한다.
Future<SyncStore?> _startFirebase(LocalStore local) async {
  if (!FirebaseEnv.configured) {
    debugPrint('[sync] .env 설정이 없어 로컬 전용(게스트)으로 실행합니다.');
    return null;
  }
  try {
    await Firebase.initializeApp(options: FirebaseEnv.options);
    AuthService.init();
    return SyncStore(local: local, backend: FirestoreBackend());
  } catch (e) {
    debugPrint('[sync] Firebase 초기화 실패 → 로컬 전용으로 실행: $e');
    return null;
  }
}

class KeepyApp extends StatefulWidget {
  const KeepyApp({super.key, required this.state});

  final AppState state;

  @override
  State<KeepyApp> createState() => _KeepyAppState();
}

class _KeepyAppState extends State<KeepyApp> with WidgetsBindingObserver {
  late bool _dark = _resolve();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(_sync);
  }

  @override
  void dispose() {
    widget.state.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// MaterialApp 위에는 MediaQuery 가 없으므로 기기 설정을 직접 읽는다.
  bool _resolve() => switch (widget.state.theme) {
    AppTheme.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
    AppTheme.light => false,
    AppTheme.dark => true,
  };

  /// 설정이 바뀔 때마다 여기로 오지만, 팔레트가 실제로 뒤집힐 때만 다시 그린다
  /// (할 일 하나 바뀔 때 앱 전체를 다시 세우지 않는다).
  void _sync() {
    if (_resolve() == _dark) return;
    setState(() => _dark = _resolve());
    // const 로 둔 위젯은 부모가 다시 그려도 건너뛰므로 옛 색이 남는다.
    // 팔레트가 뒤집히는 순간에만 트리 전체를 한 번 더럽혀 색을 다시 읽게 한다
    // (Element 를 버리지 않으므로 화면·입력 상태는 그대로다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final root = WidgetsBinding.instance.rootElement;
      if (root != null) _repaintAll(root);
    });
  }

  static void _repaintAll(Element e) {
    e.markNeedsBuild();
    e.visitChildren(_repaintAll);
  }

  /// 기기의 라이트·다크가 바뀌면 (시스템을 따를 때) 다시 칠한다
  @override
  void didChangePlatformBrightness() => _sync();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    // 팔레트는 뿌리에서 한 번 정한다 — 아래 화면들은 K·T 이름만 쓴다.
    applyTone(_dark = _resolve());
    SystemChrome.setSystemUIOverlayStyle(
      (_dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
      ),
    );
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Keepy',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        scrollBehavior: const _AppleScroll(),
        home: const HomeShell(),
      ),
    );
  }
}

/// 모든 플랫폼에서 iOS식 바운스 + 마우스 드래그 허용
class _AppleScroll extends MaterialScrollBehavior {
  const _AppleScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
