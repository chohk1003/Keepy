import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../theme.dart';

/// 계정 화면 (MP3) — 로그인 / 회원가입 / 로그아웃
///
/// 설정 화면 맨 위 계정 행을 누르면 열린다.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = _signUp
        ? await widget.auth.signUp(email, password)
        : await widget.auth.signIn(email, password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) Navigator.of(context).pop();
  }

  Future<void> _signOut() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('이 기기의 할 일은 그대로 남고, 동기화만 멈춰요.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.auth.signOut();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('계정', style: T.headline),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) =>
            widget.auth.signedIn ? _signedInView() : _formView(),
      ),
    );
  }

  Widget _signedInView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _card(
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: K.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.person_fill,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.auth.email ?? '', style: T.headline),
                    const SizedBox(height: 4),
                    Text(
                      '동기화 켜짐 · 같은 계정으로 로그인한 기기끼리 할 일이 맞춰져요',
                      style: T.footnote.copyWith(color: K.label2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _signOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: K.red,
              side: const BorderSide(color: K.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('로그아웃'),
          ),
        ),
      ],
    );
  }

  Widget _formView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(_signUp ? '새 계정 만들기' : '로그인', style: T.title2),
        const SizedBox(height: 6),
        Text(
          '로그인하면 여러 기기에서 같은 할 일 목록을 볼 수 있어요.\n'
          '테스트에는 실제 이메일 대신 test1@keepy.dev 같은 가짜 주소를 써 주세요.',
          style: T.footnote.copyWith(color: K.label2),
        ),
        const SizedBox(height: 20),
        _card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _field(
                controller: _email,
                hint: '이메일',
                keyboard: TextInputType.emailAddress,
                action: TextInputAction.next,
              ),
              const Divider(height: 1, indent: 16),
              _field(
                controller: _password,
                hint: '비밀번호 (6자 이상)',
                obscure: true,
                action: TextInputAction.done,
                onSubmit: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: T.footnote.copyWith(color: K.red)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: K.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_signUp ? '가입하고 로그인' : '로그인'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _signUp = !_signUp;
                  _error = null;
                }),
          child: Text(_signUp ? '이미 계정이 있어요 → 로그인' : '계정이 없어요 → 회원가입'),
        ),
      ],
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    TextInputAction? action,
    bool obscure = false,
    ValueChanged<String>? onSubmit,
  }) => TextField(
    controller: controller,
    keyboardType: keyboard,
    textInputAction: action,
    obscureText: obscure,
    autocorrect: false,
    enableSuggestions: !obscure,
    onSubmitted: onSubmit,
    style: T.body,
    decoration: InputDecoration(
      hintText: hint,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
