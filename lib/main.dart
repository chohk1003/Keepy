import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/keepy_app.dart';
import 'core/repositories/in_memory_task_repository.dart';
import 'core/services/firebase/firestore_task_repository.dart';
import 'features/task/viewmodels/task_view_model.dart';

// Run without credentials by default. Firebase mode is explicitly opt-in.
const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (useFirebase) {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if ([apiKey, appId, senderId, projectId].any((value) => value.isEmpty)) {
      throw StateError('Firebase mode requires FIREBASE_API_KEY, '
          'FIREBASE_APP_ID, FIREBASE_SENDER_ID, FIREBASE_PROJECT_ID.');
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      ),
    );
    // Simple prototype account: enable Anonymous in Firebase Authentication.
    // A production app should replace this with a real AuthRepository.
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(
          useFirebase
              ? FirestoreTaskRepository()
              : InMemoryTaskRepository.withSampleTasks(),
        ),
      ],
      child: const KeepyApp(),
    ),
  );
}
