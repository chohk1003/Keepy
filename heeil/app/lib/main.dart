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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  final local = await LocalStore.open();

  // MP3: .env 설정이 있으면 Firebase 동기화, 없으면 지금처럼 로컬 저장만 (게스트)
  final sync = await _startFirebase(local);
  final state = AppState(store: sync ?? local);
  if (sync != null) {
    // 첫 실행 샘플은 메모리에만 있으므로 먼저 저장해 둬야 로그인 시 서버로 올라간다
    await state.flush();
    sync.onRemoteTasks = state.applyRemote;
    sync.start();
  }
  runApp(KeepyApp(state: state));
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

class KeepyApp extends StatelessWidget {
  const KeepyApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
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
  ) =>
      child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
