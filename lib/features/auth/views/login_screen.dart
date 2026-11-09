import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(padding: const EdgeInsets.all(28), child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.sticky_note_2_rounded, size: 72,
            color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Keepy', style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('메모에서 시작하는 나의 일정 관리', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () {
              ref.read(authViewModelProvider.notifier).signIn();
              context.go('/tasks');
            }, child: const Padding(padding: EdgeInsets.all(12),
              child: Text('데모 계정으로 시작')))),
          const SizedBox(height: 12),
          Text('프로토타입용 로그인 화면으로 실제 회원가입은 구현 전입니다.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center),
        ]),
      ),
    )),
  );
}
