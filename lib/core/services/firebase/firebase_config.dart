import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const useFirebase = bool.fromEnvironment('USE_FIREBASE');
const firebaseEmulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
const firestoreEmulatorPort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

/// Read platform-specific client settings from --dart-define-from-file.
FirebaseOptions keepyFirebaseOptions() {
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  final (apiKey, appId, authDomain, iosBundleId) =
      kIsWeb
          ? (
            const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
            const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
            const String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN'),
            '',
          )
          : switch (defaultTargetPlatform) {
            TargetPlatform.android => (
              const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
              const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
              '',
              '',
            ),
            TargetPlatform.iOS => (
              const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
              const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
              '',
              const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
            ),
            _ => throw UnsupportedError('Firebase는 Web, Android, iOS에서 지원됩니다.'),
          };
  if ([projectId, senderId, apiKey, appId].any((value) => value.isEmpty) ||
      (kIsWeb && authDomain.isEmpty) ||
      (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          iosBundleId.isEmpty)) {
    throw const FormatException('실행 플랫폼의 Firebase 환경 변수를 확인해 주세요.');
  }
  if (firebaseEmulatorHost.isNotEmpty && !projectId.startsWith('demo-')) {
    throw const FormatException('에뮬레이터에는 demo-로 시작하는 프로젝트 ID를 사용해 주세요.');
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
  );
}
