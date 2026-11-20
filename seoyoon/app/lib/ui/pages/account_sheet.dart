import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../state/keepy_scope.dart';
import '../../state/sync_controller.dart';
import '../widgets/basics.dart';

/// 계정 · 동기화 (MP3): 설정 > 계정, 또는 메인 화면의 구름 아이콘에서 연다.
///
/// - 설정(.env) 없음 → 켜는 방법 안내 (이 기기에만 저장)
/// - 로그인 전 → 이메일·비밀번호로 로그인 / 회원가입
/// - 로그인 후 → 동기화 상태·올릴 변경 수·마지막 동기화, 지금 동기화, 로그아웃
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet();

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _signUpMode = false;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(SyncController sync) async {
    final email = _email.text.trim();
    final password = _password.text;
    final problem = !email.contains('@') || !email.contains('.')
        ? '이메일을 확인해 주세요.'
        : password.length < 6
            ? '비밀번호는 6자 이상이에요.'
            : null;
    if (problem != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _notice = problem;
        _noticeIsError = true;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _notice = null);
    final result = _signUpMode ? await sync.signUp(email, password) : await sync.signIn(email, password);
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeIsError = result.error;
      // 메일 확인이 필요한 가입 → 확인 뒤 바로 로그인할 수 있게 로그인 탭으로
      if (!result.signedIn && !result.error) _signUpMode = false;
    });
    if (result.signedIn) {
      HapticFeedback.lightImpact();
      _password.clear();
    }
  }

  void _confirmSignOut(SyncController sync) {
    final pending = sync.pendingCount;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('로그아웃할까요?'),
        content: Text(
          pending > 0
              ? '아직 서버에 못 올린 변경이 $pending개 있어요. 로그아웃하면 이 변경은 이 기기에만 남아요.'
              : '이 기기의 할 일은 그대로 남아요. 다시 로그인하면 계정과 합쳐져요.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              sync.signOut();
              setState(() => _notice = null);
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = KeepyScope.of(context).sync;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final Widget body;
        if (sync.phase == SyncPhase.notConfigured) {
          body = const _NotConfigured();
        } else if (!sync.isSignedIn) {
          body = _signInForm(sync);
        } else {
          body = _signedIn(sync);
        }
        return Container(
          decoration: BoxDecoration(
            color: KeepyColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 14 + keyboard),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(color: KeepyColors.tertiaryLabel, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      const Icon(CupertinoIcons.cloud, size: 20, color: KeepyColors.blue),
                      const SizedBox(width: 8),
                      Text('계정 · 동기화', style: KeepyText.title),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('같은 계정으로 로그인한 기기끼리 할 일 목록이 맞춰져요.', style: KeepyText.caption),
                  const SizedBox(height: 14),
                  body,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ 로그인 전

  Widget _signInForm(SyncController sync) {
    final busy = sync.isBusy;
    final notice = _notice ?? (sync.message != null && sync.phase == SyncPhase.signedOut ? sync.message : null);
    final noticeIsError = _notice != null ? _noticeIsError : true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ModeTabs(
          signUp: _signUpMode,
          onChanged: (v) => setState(() {
            _signUpMode = v;
            _notice = null;
          }),
        ),
        const SizedBox(height: 12),
        KeepyCard(
          child: Column(
            children: <Widget>[
              _Field(
                key: const Key('account-email'),
                controller: _email,
                hint: '이메일',
                icon: CupertinoIcons.mail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                textInputAction: TextInputAction.next,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Divider(height: 0.6, thickness: 0.6, color: KeepyColors.separator),
              ),
              _Field(
                key: const Key('account-password'),
                controller: _password,
                hint: _signUpMode ? '비밀번호 (6자 이상)' : '비밀번호',
                icon: CupertinoIcons.lock,
                obscure: true,
                autofillHints: <String>[_signUpMode ? AutofillHints.newPassword : AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!busy) _submit(sync);
                },
              ),
            ],
          ),
        ),
        if (notice != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            notice,
            style: KeepyText.caption.copyWith(
              color: noticeIsError ? KeepyColors.red : KeepyColors.blue,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
        GradientButton(
          key: const Key('account-submit'),
          label: busy ? '잠시만요…' : (_signUpMode ? '가입하고 동기화 시작' : '로그인'),
          onPressed: busy ? null : () => _submit(sync),
        ),
        const SizedBox(height: 12),
        Text(
          '로그인하면 이 기기에 있던 할 일도 계정에 합쳐져요.\n'
          '다른 기기에서 같은 계정으로 로그인하면 같은 목록을 봐요.',
          style: KeepyText.footnote.copyWith(height: 1.5),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 로그인 후

  Widget _signedIn(SyncController sync) {
    final phase = sync.phase;
    final color = switch (phase) {
      SyncPhase.syncing => KeepyColors.blue,
      SyncPhase.offline => KeepyColors.orange,
      SyncPhase.error => KeepyColors.red,
      _ => sync.pendingCount > 0 ? KeepyColors.orange : KeepyColors.green,
    };
    final last = sync.lastSyncedAt;
    final lastText = last == null
        ? '아직 없음'
        : '${last.month}월 ${last.day}일 '
            '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    final showMessage = (phase == SyncPhase.offline || phase == SyncPhase.error) && sync.message != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KeepyCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: KeepyColors.skyTint, shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.person_fill, color: KeepyColors.blue, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          sync.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KeepyText.headline,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                sync.statusText,
                                key: const Key('account-status'),
                                maxLines: 2,
                                style: KeepyText.caption.copyWith(color: color, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(label: '마지막 동기화', value: lastText),
              const SizedBox(height: 6),
              _InfoRow(label: '서버에 올릴 변경', value: '${sync.pendingCount}개'),
              if (showMessage) ...<Widget>[
                const SizedBox(height: 10),
                Text(sync.message!, style: KeepyText.footnote.copyWith(color: color, height: 1.45)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GradientButton(
          key: const Key('account-sync-now'),
          label: phase == SyncPhase.syncing ? '동기화 중…' : '지금 동기화',
          onPressed: phase == SyncPhase.syncing
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  sync.syncNow();
                },
        ),
        const SizedBox(height: 6),
        CupertinoButton(
          key: const Key('account-sign-out'),
          onPressed: () => _confirmSignOut(sync),
          child: const Text('로그아웃', style: TextStyle(color: KeepyColors.red, fontSize: 14.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(
          '• 앱을 열 때, 다시 앞으로 올 때, 할 일을 바꾼 직후, 그리고 20초마다 자동으로 맞춰요.\n'
          '• 오프라인에서 바꾼 것은 이 기기에 모아 두었다가 연결되면 올려요.\n'
          '• 두 기기에서 같은 할 일을 고치면 나중에 고친 쪽이 남아요.',
          style: KeepyText.footnote.copyWith(height: 1.55),
        ),
      ],
    );
  }
}

/// 설정(.env)이 없을 때: 켜는 방법.
class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return KeepyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('서버 동기화가 꺼져 있어요', style: KeepyText.headline),
          const SizedBox(height: 6),
          Text(
            '지금은 1·2단계처럼 이 기기에만 저장돼요. 켜려면 PC 에서:',
            style: KeepyText.caption.copyWith(height: 1.45),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: KeepyColors.fill, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '1. app\\.env.example 을 복사해 app\\.env 만들기\n'
              '2. SUPABASE_URL, SUPABASE_ANON_KEY 채우기\n'
              '3. flutter run --dart-define-from-file=.env',
              style: KeepyText.footnote.copyWith(color: KeepyColors.label, height: 1.6),
            ),
          ),
          const SizedBox(height: 8),
          Text('자세한 순서는 docs/MP3_실행_매뉴얼.md 에 있어요.', style: KeepyText.footnote),
        ],
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.signUp, required this.onChanged});
  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value, Key key) {
      final selected = signUp == value;
      return Expanded(
        child: PressScale(
          key: key,
          onTap: () {
            if (selected) return;
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          child: AnimatedContainer(
            duration: KeepyMotion.fast,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? KeepyColors.card : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected ? const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1))] : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                color: selected ? KeepyColors.label : KeepyColors.secondaryLabel,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: KeepyColors.fill, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: <Widget>[
          tab('로그인', false, const Key('account-tab-signin')),
          tab('회원가입', true, const Key('account-tab-signup')),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: KeepyColors.secondaryLabel),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: !obscure,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: KeepyText.body,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: hint,
                hintStyle: KeepyText.body.copyWith(color: KeepyColors.tertiaryLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(label, style: KeepyText.caption),
        const Spacer(),
        Text(value, style: KeepyText.caption.copyWith(color: KeepyColors.label, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
