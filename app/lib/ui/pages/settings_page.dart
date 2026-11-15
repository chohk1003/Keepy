import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../models/app_settings.dart';
import '../../state/keepy_scope.dart';
import '../../state/settings_store.dart';
import '../../state/task_store.dart';
import '../game/stair_game_page.dart';
import '../widgets/basics.dart';
import '../widgets/tag_manager_sheet.dart';
import '../widgets/undo_toast.dart';

/// 설정 화면 (UI 설계서 01 / 요구사항 3.2 '설정 및 완료 이벤트').
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.toast, required this.bottomInset});

  final ToastController toast;
  final double bottomInset;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scope = KeepyScope.of(context);
    final store = scope.settings;
    final tasks = scope.tasks;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[store, tasks]),
        builder: (context, _) {
          final s = store.settings;
          final characterLabel = switch (s.effectiveCharacterStyle) {
            CharacterStyle.boy => '남자',
            CharacterStyle.girl => '여자',
            CharacterStyle.photo => '내 사진',
          };
          void change(AppSettings Function(AppSettings) f) {
            HapticFeedback.selectionClick();
            store.update(f);
          }

          return ListView(
            key: const PageStorageKey<String>('settings-list'),
            padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomInset),
            children: <Widget>[
              const SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: KeepyLogo(size: 22))),
              const SizedBox(height: 10),
              Text('설정', style: KeepyText.largeTitle),

              // 1. 계정 및 알림 ------------------------------------------------
              const _GroupTitle('계정'),
              _Group(children: <Widget>[
                _Row(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: KeepyColors.skyTint, shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.person_fill, color: KeepyColors.blue, size: 21),
                  ),
                  title: s.userName,
                  subtitle: '로그인 전 · 이 기기에 저장 중',
                  onTap: () => _showAccountSheet(context),
                ),
              ]),

              // 화면 모드 (v0.4) ------------------------------------------------
              _GroupTitle('화면'),
              _Group(children: <Widget>[
                _Row(
                  leading: Icon(
                    KeepyPalette.dark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                    size: 19,
                    color: KeepyColors.blue,
                  ),
                  title: '화면 모드',
                  trailing: _Segmented<AppearanceMode>(
                    value: s.appearance,
                    options: AppearanceMode.values,
                    labelOf: (v) => v.label,
                    onChanged: (v) => change((c) => c.copyWith(appearance: v)),
                  ),
                ),
              ]),
              _Footnote('시스템을 고르면 휴대폰의 다크 모드 설정을 따라가요.'),
              const _GroupTitle('알림'),
              _Group(children: <Widget>[
                _Row(
                  title: '알림 설정',
                  trailing: CupertinoSwitch(
                    value: s.notificationsEnabled,
                    activeTrackColor: KeepyColors.blue,
                    onChanged: (v) => change((c) => c.copyWith(notificationsEnabled: v)),
                  ),
                ),
                _Row(
                  title: '미리 알림',
                  enabled: s.notificationsEnabled,
                  value: remindLabel(s.remindDaysBefore),
                  onTap: () => _pickRemind(context, store),
                ),
                _Row(
                  title: '알림 시간',
                  enabled: s.notificationsEnabled,
                  value: formatTimeOfDayMinutes(s.remindMinutes),
                  onTap: () => _pickTime(context, store),
                ),
              ]),

              // 2. 외부 서비스 연동 -------------------------------------------
              const _GroupTitle('서비스 연동'),
              _Group(children: <Widget>[
                _Row(
                  leading: const _ServiceIcon(letter: 'e', color: Color(0xFF2F6BFF)),
                  title: 'eclass',
                  value: s.eclassConnected ? '연결됨' : '연결하기',
                  valueHighlight: s.eclassConnected,
                  onTap: () => change((c) => c.copyWith(eclassConnected: !c.eclassConnected)),
                ),
                _Row(
                  leading: const _ServiceIcon(letter: 'E', color: Color(0xFFFF3B30)),
                  title: '에브리타임 시간표',
                  value: s.everytimeConnected ? '연결됨' : '연결하기',
                  valueHighlight: s.everytimeConnected,
                  onTap: () => change((c) => c.copyWith(everytimeConnected: !c.everytimeConnected)),
                ),
              ]),
              const _Footnote('실제 일정 가져오기는 다음 단계에서 연결됩니다. 지금은 연결 상태만 저장돼요.'),

              // 3. 날짜 화면 옵션 ---------------------------------------------
              const _GroupTitle('날짜 화면'),
              _Group(children: <Widget>[
                _Row(
                  title: '달력 행 수',
                  trailing: _Segmented<int>(
                    value: s.calendarRows,
                    options: const <int>[1, 2, 3, 4],
                    labelOf: (v) => '$v',
                    onChanged: (v) => change((c) => c.copyWith(calendarRows: v)),
                  ),
                ),
                _Row(
                  title: '이번 주 행 순서',
                  enabled: s.calendarRows > 1,
                  trailing: _Segmented<int>(
                    value: s.effectiveWeekRow,
                    options: <int>[for (var i = 1; i <= s.calendarRows; i++) i],
                    labelOf: (v) => '$v',
                    onChanged: (v) => change((c) => c.copyWith(currentWeekRow: v)),
                  ),
                ),
                _Row(
                  title: '금일 완료율 형태',
                  trailing: _Segmented<CompletionStyle>(
                    value: s.completionStyle,
                    options: CompletionStyle.values,
                    labelOf: (v) => v.label,
                    onChanged: (v) => change((c) => c.copyWith(completionStyle: v)),
                  ),
                ),
              ]),
              _Footnote(
                '이번 주를 ${s.effectiveWeekRow}번째 행에 표시합니다. '
                '금일 완료율은 ${s.completionStyle.label} 형태로 표시합니다.',
              ),

              // 4. 할 일 분류 (prompts_log #11) --------------------------------
              const _GroupTitle('할 일 분류'),
              _Group(children: <Widget>[
                _Row(
                  title: '기한 없는 할 일 지연 기준',
                  trailing: _Stepper(
                    value: s.delayDays,
                    min: AppSettings.minDelayDays,
                    max: AppSettings.maxDelayDays,
                    suffix: '일',
                    onChanged: (v) => change((c) => c.copyWith(delayDays: v)),
                  ),
                ),
              ]),
              const _Footnote('기한이 지나거나, 기한 없이 만든 뒤 위 기간이 지나면 \'지연\'으로 분류돼요. 지연된 일을 끝내면 \'늦은 완료\'로 남아요.'),

              // 5. 태그 (v0.3) ---------------------------------------------------
              _GroupTitle('태그', trailing: '${s.tags.length}개'),
              _Group(children: <Widget>[
                _Row(
                  leading: const Icon(CupertinoIcons.gear_alt, size: 19, color: KeepyColors.blue),
                  title: '태그 관리',
                  value: s.tags.take(3).map((t) => '#$t').join(' ') + (s.tags.length > 3 ? ' …' : ''),
                  onTap: () => showTagManager(context),
                ),
              ]),

              // 6. 미니게임 (v0.3) -----------------------------------------------
              const _GroupTitle('미니게임'),
              _Group(children: <Widget>[
                _Row(
                  leading: const StairsIcon(size: 19),
                  title: '계단 오르기',
                  subtitle: '이번 달 완료한 만큼 내 캐릭터가 계단을 올라요',
                  trailing: CupertinoSwitch(
                    key: const Key('minigame-switch'),
                    value: s.miniGameEnabled,
                    activeTrackColor: KeepyColors.blue,
                    onChanged: (v) => change((c) => c.copyWith(miniGameEnabled: v)),
                  ),
                ),
                if (s.miniGameEnabled)
                  _Row(
                    title: '지금 해 보기',
                    value: '$characterLabel · 펫 ${s.pet.label}',
                    onTap: () => StairGamePage.open(context),
                  ),
              ]),
              const _Footnote('켜면 메인 화면 오른쪽 위에 바로가기 아이콘이 생겨요. 끄면 아이콘도 사라져요.'),

              // 7. 완료 기록 (요구사항 3.2 완료 이벤트) -------------------------
              _GroupTitle('완료 기록', trailing: '총 ${tasks.doneCount}개'),
              _CompletionLog(tasks: tasks),

              // 8. 데이터 -------------------------------------------------------
              const _GroupTitle('데이터'),
              _Group(children: <Widget>[
                _Row(
                  title: '샘플 할 일 넣기',
                  value: '시연용',
                  onTap: () {
                    tasks.addSamples();
                    widget.toast.show('샘플 할 일을 넣었어요');
                  },
                ),
                _Row(
                  title: '모든 할 일 지우기',
                  destructive: true,
                  onTap: () => _confirmClear(context, tasks),
                ),
              ]),
              const _Footnote('할 일은 이 기기에 저장되어 앱을 다시 켜도 그대로 남아요.'),
              const SizedBox(height: 12),
              Center(child: Text('Keepy 0.5.0', style: KeepyText.footnote)),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ 시트·대화상자

  void _showAccountSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('계정'),
        message: const Text('로그인·여러 기기 동기화는 BaaS 연동 단계(MP3)에서 지원됩니다.\n지금은 이 기기에만 저장돼요.'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              widget.toast.show('로그인 기능은 아직 준비 중이에요');
            },
            child: const Text('로그아웃'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
      ),
    );
  }

  void _pickRemind(BuildContext context, SettingsStore store) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('미리 알림'),
        actions: <Widget>[
          for (final d in remindOptions)
            CupertinoActionSheetAction(
              isDefaultAction: d == store.settings.remindDaysBefore,
              onPressed: () {
                store.update((c) => c.copyWith(remindDaysBefore: d));
                Navigator.pop(ctx);
              },
              child: Text(remindLabel(d)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
      ),
    );
  }

  void _pickTime(BuildContext context, SettingsStore store) {
    final m = store.settings.remindMinutes;
    var picked = m;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        padding: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: KeepyColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                  const Spacer(),
                  Text('알림 시간', style: KeepyText.headline),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () {
                      store.update((c) => c.copyWith(remindMinutes: picked));
                      Navigator.pop(ctx);
                    },
                    child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(2026, 1, 1, m ~/ 60, m % 60),
                  minuteInterval: 5,
                  onDateTimeChanged: (d) => picked = d.hour * 60 + d.minute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, TaskStore tasks) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('모든 할 일을 지울까요?'),
        content: const Text('이 기기에 저장된 할 일이 모두 지워지며 되돌릴 수 없어요.'),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              tasks.clearAll();
              Navigator.pop(ctx);
            },
            child: const Text('지우기'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 구성 요소

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title, {this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Row(
        children: <Widget>[
          Text(title, style: KeepyText.caption.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (trailing != null) Text(trailing!, style: KeepyText.footnote),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Text(text, style: KeepyText.footnote.copyWith(height: 1.45)),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Padding(
          padding: EdgeInsets.only(left: 16),
          child: Divider(height: 0.6, thickness: 0.6, color: KeepyColors.separator),
        ));
      }
      items.add(children[i]);
    }
    return KeepyCard(child: Column(children: items));
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.valueHighlight = false,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? value;
  final bool valueHighlight;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: subtitle == null ? 13 : 12),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: KeepyText.body.copyWith(
                    fontSize: 14.5,
                    color: destructive ? KeepyColors.red : KeepyColors.label,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: KeepyText.footnote),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: valueHighlight
                  ? GradientText(value!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))
                  : Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KeepyText.caption.copyWith(fontSize: 13.5),
                    ),
            ),
          if (onTap != null && trailing == null) ...<Widget>[
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_right, size: 15, color: KeepyColors.tertiaryLabel),
          ],
        ],
      ),
    );
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: KeepyMotion.fast,
      child: IgnorePointer(
        ignoring: !enabled,
        child: onTap == null
            ? row
            : PressScale(onTap: onTap, scale: 0.985, child: row),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.letter, required this.color});
  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(letter, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}

/// 작은 선택 버튼 묶음 (1 2 3 4 / 바 원형 그래프).
class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.value, required this.options, required this.labelOf, required this.onChanged});
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: KeepyColors.fill, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final o in options)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: KeepyMotion.fast,
                curve: KeepyMotion.settle,
                constraints: const BoxConstraints(minWidth: 30),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: o == value ? KeepyGradients.primary : null,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  labelOf(o),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: o == value ? FontWeight.w700 : FontWeight.w500,
                    color: o == value ? Colors.white : KeepyColors.secondaryLabel,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.min, required this.max, required this.suffix, required this.onChanged});
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, int delta) => PressScale(
          onTap: enabled ? () => onChanged(value + delta) : null,
          scale: 0.85,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 16, color: enabled ? KeepyColors.blue : KeepyColors.tertiaryLabel),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: KeepyColors.fill, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          btn(CupertinoIcons.minus, value > min, -1),
          SizedBox(
            width: 34,
            child: Text('$value$suffix', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          btn(CupertinoIcons.plus, value < max, 1),
        ],
      ),
    );
  }
}

class _CompletionLog extends StatelessWidget {
  const _CompletionLog({required this.tasks});
  final TaskStore tasks;

  @override
  Widget build(BuildContext context) {
    final recent = tasks.recentCompletions();
    if (recent.isEmpty) {
      return KeepyCard(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: Text('아직 완료한 할 일이 없어요', style: KeepyText.caption)),
      );
    }
    final now = tasks.now();
    return _Group(children: <Widget>[
      for (final t in recent)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: t.completedLate ? KeepyGradients.delayed : KeepyGradients.success,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(CupertinoIcons.checkmark_alt, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KeepyText.body.copyWith(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              if (t.completedLate) ...<Widget>[
                const Pill('늦은 완료', color: KeepyColors.orange),
                const SizedBox(width: 6),
              ],
              Text(formatCompletedAt(t.completedAt!, now), style: KeepyText.footnote),
            ],
          ),
        ),
    ]);
  }
}
