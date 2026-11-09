import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/viewmodels/auth_view_model.dart';
import '../features/auth/views/login_screen.dart';
import '../features/calendar/views/calendar_screen.dart';
import '../features/ocr/views/ocr_screen.dart';
import '../features/settings/views/settings_screen.dart';
import '../features/task/views/task_screen.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/tasks',
    redirect: (context, state) {
      final signedIn = ref.read(authViewModelProvider);
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn) return onLogin ? null : '/login';
      if (onLogin) return '/tasks';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child), routes: [
        GoRoute(path: '/tasks', builder: (context, state) => const TaskScreen()),
        GoRoute(path: '/calendar', builder: (context, state) => const CalendarScreen()),
        GoRoute(path: '/ocr', builder: (context, state) => const OcrScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      ]),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
