import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(firebaseAuthProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.sticky_note_2_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Text(
                  'Keepy',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 24),
                if (auth == null)
                  FilledButton(
                    onPressed: ref.read(authViewModelProvider.notifier).signIn,
                    child: const Text('데모 계정으로 시작'),
                  )
                else ...[
                  if (ref.watch(firebaseUserProvider).hasError)
                    const Text('이전 로그인 상태를 복원하지 못했습니다. 다시 로그인해 주세요.'),
                  EmailAuthForm(auth: auth),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmailAuthForm extends StatefulWidget {
  const EmailAuthForm({super.key, required this.auth, this.anonymousUser});

  final FirebaseAuth auth;
  final User? anonymousUser;

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    final anonymous = widget.anonymousUser;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (anonymous != null) {
        await anonymous.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
        if (mounted) Navigator.of(context).pop();
      } else if (_register) {
        await widget.auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await widget.auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } catch (_) {
      if (mounted) setState(() => _error = '인증 요청을 처리하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linking = widget.anonymousUser != null;
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: '이메일'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? '이메일을 입력해 주세요.'
                          : null,
            ),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autofillHints: [
                if (_register || linking)
                  AutofillHints.newPassword
                else
                  AutofillHints.password,
              ],
              decoration: const InputDecoration(labelText: '비밀번호'),
              validator:
                  (value) =>
                      value == null || value.isEmpty ? '비밀번호를 입력해 주세요.' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? '처리 중…'
                    : linking
                    ? '계정 연결'
                    : _register
                    ? '회원가입'
                    : '로그인',
              ),
            ),
            if (!linking)
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () => setState(() {
                          _register = !_register;
                          _error = null;
                        }),
                child: Text(_register ? '이미 계정이 있어요' : '이메일로 회원가입'),
              ),
          ],
        ),
      ),
    );
  }
}
