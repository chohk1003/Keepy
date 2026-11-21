import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/keepy_app.dart';
import 'core/services/firebase/firebase_config.dart';
import 'features/auth/viewmodels/auth_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseAuth? auth;
  if (useFirebase) {
    try {
      await Firebase.initializeApp(options: keepyFirebaseOptions());
      final firestore = FirebaseFirestore.instance;
      // Set before the first listener or write. Web persistence is opt-in.
      firestore.settings = const Settings(
        persistenceEnabled: true,
        webPersistentTabManager:
            kIsWeb ? WebPersistentMultipleTabManager() : null,
      );
      auth = FirebaseAuth.instance;
      if (firebaseEmulatorHost.isNotEmpty) {
        await auth.useAuthEmulator(firebaseEmulatorHost, 9099);
        firestore.useFirestoreEmulator(
          firebaseEmulatorHost,
          firestoreEmulatorPort,
        );
      }
    } catch (_) {
      runApp(const _FirebaseStartupError());
      return;
    }
  }
  _runKeepy(auth);
}

void _runKeepy(FirebaseAuth? auth) => runApp(
  ProviderScope(
    overrides: [if (auth != null) firebaseAuthProvider.overrideWithValue(auth)],
    child: const KeepyApp(),
  ),
);

class _FirebaseStartupError extends StatelessWidget {
  const _FirebaseStartupError();

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Firebase를 시작할 수 없습니다. 환경 변수를 확인하고 다시 실행해 주세요.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _runKeepy(null),
                  child: const Text('이 기기의 로컬 모드 열기'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
