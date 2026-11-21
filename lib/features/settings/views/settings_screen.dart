import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/viewmodels/auth_view_model.dart';
import '../../auth/views/login_screen.dart';
import '../viewmodels/settings_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final auth = ref.watch(firebaseAuthProvider);
    final user = auth == null ? null : ref.watch(firebaseUserProvider).value;
    final time = TimeOfDay(hour: settings.reminderHour,
      minute: settings.reminderMinute);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(padding: const EdgeInsets.all(18), children: [
          const _SectionTitle('계정'),
          Card(child: ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(user?.email ?? (auth == null ? '로컬 사용자' : '익명 사용자')),
            subtitle: Text(auth == null
                ? '할 일은 이 기기에 저장됩니다.'
                : user?.isAnonymous == true
                    ? '기존 할 일을 유지하려면 이메일 계정을 연결하세요.'
                    : '같은 계정으로 로그인한 기기와 할 일을 동기화합니다.'),
          )),
          if (auth != null && user != null && user.isAnonymous)
            OutlinedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('익명 계정에 이메일 연결'),
                  content: SingleChildScrollView(
                    child: EmailAuthForm(auth: auth, anonymousUser: user),
                  ),
                ),
              ),
              child: const Text('이메일 계정 연결'),
            ),
          const SizedBox(height: 14),
          const _SectionTitle('알림'),
          Card(child: Column(children: [
            SwitchListTile(title: const Text('미리 알림 사용'),
              subtitle: const Text('설정값만 변경됨 · 실제 알림 예약 기능은 후속 개발'),
              value: settings.notificationsEnabled,
              onChanged: viewModel.setNotifications),
            const Divider(height: 1),
            ListTile(title: const Text('미리 알림 시점'),
              trailing: DropdownButton<int>(value: settings.reminderDays,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('당일')),
                  DropdownMenuItem(value: 1, child: Text('1일 전')),
                  DropdownMenuItem(value: 2, child: Text('2일 전')),
                ],
                onChanged: (value) {
                  if (value != null) viewModel.setReminderDays(value);
                }),
            ),
            const Divider(height: 1),
            ListTile(title: const Text('알림 시간'),
              subtitle: Text(time.format(context)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: () async {
                final chosen = await showTimePicker(context: context, initialTime: time);
                if (chosen != null) viewModel.setTime(chosen.hour, chosen.minute);
              },
            ),
          ])),
          const SizedBox(height: 14),
          const _SectionTitle('날짜 화면'),
          Card(child: ListTile(title: const Text('달력 표시 행 수 (설정값)'),
            subtitle: const Text('실제 가변 행 달력 UI는 후속 구현'),
            trailing: DropdownButton<int>(value: settings.calendarRows,
              underline: const SizedBox.shrink(),
              items: [for (var n = 1; n <= 4; n++)
                DropdownMenuItem(value: n, child: Text('$n행'))],
              onChanged: (value) {
                if (value != null) viewModel.setCalendarRows(value);
              }),
          )),
          const SizedBox(height: 14),
          const _SectionTitle('외부 서비스 연동'),
          const Card(child: Column(children: [
            ListTile(leading: Icon(Icons.school_outlined), title: Text('eclass 과제 연동'),
              subtitle: Text('후속 개발 예정')),
            Divider(height: 1),
            ListTile(leading: Icon(Icons.calendar_month_outlined),
              title: Text('에브리타임 시간표 연동'), subtitle: Text('후속 개발 예정')),
          ])),
          const SizedBox(height: 20),
          if (user?.isAnonymous != true)
            OutlinedButton.icon(
              onPressed: () async {
                if (auth == null) {
                  ref.read(authViewModelProvider.notifier).signOut();
                  return;
                }
                try {
                  await auth.signOut();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그아웃에 실패했습니다. 다시 시도해 주세요.')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(auth == null ? '데모 로그아웃' : '로그아웃'),
            ),
          const SizedBox(height: 18),
          const Center(child: Text('Keepy Prototype 0.1 · MVVM + Repository')),
        ]),
      )),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700)),
  );
}
