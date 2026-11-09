import 'package:flutter_riverpod/flutter_riverpod.dart';

final authViewModelProvider = NotifierProvider<AuthViewModel, bool>(
  AuthViewModel.new,
);

/// UI-only demo authentication. Firebase mode separately uses anonymous auth.
class AuthViewModel extends Notifier<bool> {
  @override
  bool build() => true;

  void signIn() => state = true;
  void signOut() => state = false;
}
