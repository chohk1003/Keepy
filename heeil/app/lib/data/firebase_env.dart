import 'package:firebase_core/firebase_core.dart';

/// Firebase 설정값 (MP3, NFR-06 · CST-04)
///
/// 값은 코드에 적지 않는다. 실행할 때 `.env` 파일에서 넘겨받는다.
///
/// ```bash
/// flutter run --dart-define-from-file=.env
/// ```
///
/// `.env`가 없거나 값이 비어 있으면 [configured]가 false가 되고,
/// 앱은 지금처럼 **로컬 저장만** 하는 게스트 모드로 돈다 (크래시 없음).
/// 필요한 키 목록은 저장소 루트의 `.env.example` 참고.
abstract final class FirebaseEnv {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get configured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      senderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
  );
}
