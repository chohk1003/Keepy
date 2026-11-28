import 'package:flutter/material.dart';
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
  final cloud = ref.watch(firebaseAuthProvider) != null;
  final router = GoRouter(
    initialLocation: '/tasks',
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (cloud && ref.read(firebaseUserProvider).isLoading) {
        return path == '/session' ? null : '/session';
      }
      final signedIn =
          cloud
              ? ref.read(firebaseUserProvider).value != null
              : ref.read(authViewModelProvider);
      if (!signedIn) return path == '/login' ? null : '/login';
      if (path == '/login' || path == '/session') return '/tasks';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/session',
        builder:
            (context, state) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
      ),
      ShellRoute(
        builder:
            (context, state, child) =>
                AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TaskScreen(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(path: '/ocr', builder: (context, state) => const OcrScreen()),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
  if (cloud) {
    ref.listen(firebaseUserProvider, (_, _) => router.refresh());
  } else {
    ref.listen(authViewModelProvider, (_, _) => router.refresh());
  }
  ref.onDispose(router.dispose);
  return router;
});
