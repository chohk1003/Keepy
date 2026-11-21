import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) => null);

final firebaseUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth?.userChanges() ?? Stream<User?>.value(null);
});

final authViewModelProvider = NotifierProvider<AuthViewModel, bool>(
  AuthViewModel.new,
);

/// Demo session state for the MP2 local mode.
class AuthViewModel extends Notifier<bool> {
  @override
  bool build() => true;

  void signIn() => state = true;
  void signOut() => state = false;
}

String authErrorMessage(FirebaseAuthException error) => switch (error.code) {
  'invalid-email' => '이메일 주소를 확인해 주세요.',
  'invalid-credential' ||
  'user-not-found' ||
  'wrong-password' => '이메일 또는 비밀번호를 확인해 주세요.',
  'email-already-in-use' ||
  'credential-already-in-use' => '이미 사용 중인 이메일입니다. 다른 이메일을 사용해 주세요.',
  'weak-password' => '비밀번호는 6자 이상이어야 합니다.',
  'network-request-failed' => '인터넷 연결을 확인해 주세요.',
  'too-many-requests' => '잠시 후 다시 시도해 주세요.',
  'operation-not-allowed' => 'Firebase에서 이메일/비밀번호 로그인이 비활성화되어 있습니다.',
  _ => '인증 요청을 처리하지 못했습니다. 다시 시도해 주세요.',
};
