import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 이메일/비밀번호 로그인 (MP3)
///
/// 익명 로그인은 기기마다 다른 사용자가 되어 "두 기기에서 같은 목록"을
/// 볼 수 없으므로 이메일/비밀번호를 쓴다. 테스트에는 실제 이메일 대신
/// `test1@keepy.dev` 같은 가짜 주소를 쓴다 (Firebase는 메일 존재 여부를 확인하지 않음).
class AuthService extends ChangeNotifier {
  AuthService._(this._auth) {
    _user = _auth.currentUser;
    _sub = _auth.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  /// Firebase가 설정되지 않았으면 null (게스트 전용 모드)
  static AuthService? instance;

  /// `Firebase.initializeApp()` 뒤에 한 번 부른다.
  static void init() => instance ??= AuthService._(FirebaseAuth.instance);

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _sub;
  User? _user;

  bool get signedIn => _user != null;
  String? get email => _user?.email;

  /// 성공하면 null, 실패하면 사용자에게 보여 줄 문장
  Future<String?> signIn(String email, String password) => _run(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  Future<String?> signUp(String email, String password) => _run(
    () => _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  Future<void> signOut() => _auth.signOut();

  Future<String?> _run(Future<Object?> Function() action) async {
    try {
      await action();
      return null;
    } on FirebaseAuthException catch (e) {
      return messageOf(e.code);
    } catch (e) {
      return '알 수 없는 오류가 났어요. ($e)';
    }
  }

  static String messageOf(String code) => switch (code) {
    'invalid-email' => '이메일 형식이 올바르지 않아요.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => '이메일 또는 비밀번호가 맞지 않아요.',
    'email-already-in-use' => '이미 가입된 이메일이에요. 로그인해 주세요.',
    'weak-password' => '비밀번호는 6자 이상이어야 해요.',
    'network-request-failed' => '인터넷에 연결되어 있지 않아요.',
    'operation-not-allowed' => 'Firebase 콘솔에서 이메일/비밀번호 로그인을 켜 주세요.',
    'too-many-requests' => '시도가 너무 많아요. 잠시 뒤 다시 해 주세요.',
    _ => '로그인하지 못했어요. ($code)',
  };

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
