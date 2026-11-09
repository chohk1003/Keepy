import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/fx.dart';
import '../widgets/task_actions.dart';

/// 설정 화면 (UI설계서 01) + 완료 이벤트 내역 — iOS 설정 앱 스타일
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    String time(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text('설정', style: T.largeTitle),
          middle: Text('설정', style: T.headline),
          alwaysShowMiddle: false,
          backgroundColor: K.bg.withValues(alpha: 0.82),
          border: null,
          transitionBetweenRoutes: false,
        ),
        SliverList.list(
          children: [
            _Section(
              children: [
                _Row(
                  leading: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: K.brand,
                      shape: BoxShape.circle,
                      boxShadow: K.glow(K.indigo, a: 0.3, blur: 12),
                    ),
                    child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 26),
                  ),
                  title: '게스트',
                  subtitle: '로그인 · 동기화',
                  chevron: true,
                  onTap: () => showToast(
                    context,
                    'MP3에서 연결',
                    icon: CupertinoIcons.cloud_fill,
                  ),
                ),
              ],
            ),
            _Section(
              header: '알림',
              children: [
                _Row(
                  icon: CupertinoIcons.bell_fill,
                  colors: const [Color(0xFFFF453A), Color(0xFFFF2D55)],
                  title: '알림',
                  trailing: CupertinoSwitch(
                    value: s.notify,
                    activeTrackColor: K.green,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      s.setNotify(v);
                    },
                  ),
                ),
                _Row(
                  icon: CupertinoIcons.timer,
                  colors: const [Color(0xFFFF9F0A), Color(0xFFFF375F)],
                  title: '미리 알림',
                  enabled: s.notify,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final d in const [0, 1, 2])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _Toggle(
                            text: d == 0 ? '당일' : '$d일 전',
                            on: s.remindDays.contains(d),
                            onTap: s.notify ? () => s.toggleRemind(d) : null,
                          ),
                        ),
                    ],
                  ),
                ),
                _Row(
                  icon: CupertinoIcons.clock_fill,
                  colors: const [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                  title: '시간',
                  enabled: s.notify,
                  value: time(s.notifyTime),
                  chevron: true,
                  onTap: s.notify ? () => _pickTime(context, s) : null,
                ),
              ],
            ),
            _Section(
              header: '연동',
              children: [
                _Row(
                  icon: CupertinoIcons.book_fill,
                  colors: const [Color(0xFF30D158), Color(0xFF00C7BE)],
                  title: 'eclass',
                  trailing: CupertinoSwitch(
                    value: s.eclass,
                    activeTrackColor: K.green,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      s.setEclass(v);
                    },
                  ),
                ),
                _Row(
                  icon: CupertinoIcons.table_fill,
                  colors: const [Color(0xFFFF375F), Color(0xFFBF5AF2)],
                  title: '에브리타임',
                  trailing: CupertinoSwitch(
                    value: s.everytime,
                    activeTrackColor: K.green,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      s.setEverytime(v);
                    },
                  ),
                ),
              ],
            ),
            _Section(
              header: '분류',
              children: [
                _Block(
                  icon: CupertinoIcons.hourglass,
                  colors: const [Color(0xFFFF453A), Color(0xFFFF2D55)],
                  title: '기한 없는 할 일 → 지연',
                  child: _Segmented<int>(
                    value: s.overdueDays,
                    items: const {0: '끔', 1: '1일', 3: '3일', 7: '7일'},
                    onChanged: s.setOverdueDays,
                  ),
                ),
                const _Row(
                  icon: CupertinoIcons.info_circle_fill,
                  colors: [Color(0xFF8E8E93), Color(0xFF636366)],
                  title: '기한 지남 → 지연 → 완료 시 늦은 완료',
                  muted: true,
                ),
              ],
            ),
            _Section(
              header: '날짜 화면',
              children: [
                _Block(
                  icon: CupertinoIcons.rectangle_grid_1x2_fill,
                  colors: const [Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
                  title: '달력 행',
                  child: _Segmented<int>(
                    value: s.calendarRows,
                    items: {for (var i = 1; i <= 4; i++) i: '$i'},
                    onChanged: s.setCalendarRows,
                  ),
                ),
                _Block(
                  icon: CupertinoIcons.arrow_up_arrow_down,
                  colors: const [Color(0xFF0A84FF), Color(0xFF00C7BE)],
                  title: '이번 주 위치',
                  enabled: s.calendarRows > 1,
                  child: _Segmented<int>(
                    value: s.thisWeekRow,
                    items: {for (var i = 1; i <= s.calendarRows; i++) i: '$i행'},
                    onChanged: s.setThisWeekRow,
                  ),
                ),
                _Block(
                  icon: CupertinoIcons.chart_pie_fill,
                  colors: const [Color(0xFFFF9F0A), Color(0xFFFF375F)],
                  title: '완료율',
                  child: _Segmented<RateStyle>(
                    value: s.rateStyle,
                    items: const {
                      RateStyle.bar: '바',
                      RateStyle.ring: '원형',
                      RateStyle.graph: '그래프',
                    },
                    onChanged: s.setRateStyle,
                  ),
                ),
              ],
            ),
            _Section(
              header: '완료 기록',
              children: [
                if (s.doneLog.isEmpty)
                  const _Row(title: '없음', muted: true)
                else
                  for (final e in s.doneLog.take(20))
                    _Row(
                      icon: CupertinoIcons.checkmark_alt,
                      colors: const [Color(0xFF30D158), Color(0xFF00C7BE)],
                      title: e.title,
                      value: '${md(e.at)} ${hm(e.at)}',
                    ),
              ],
            ),
            if (s.done.isNotEmpty)
              _Section(
                children: [
                  _Row(
                    title: '완료 항목 지우기',
                    destructive: true,
                    onTap: () => _confirmClear(context, s),
                  ),
                ],
              ),
            SizedBox(height: bottom + 24),
          ],
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context, AppState s) async {
    var picked = s.notifyTime;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        padding: const EdgeInsets.only(top: 6),
        decoration: const BoxDecoration(
          color: K.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: GradientText(
                      '완료',
                      style: T.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: 5,
                  initialDateTime: DateTime(2000, 1, 1, s.notifyTime.hour,
                      s.notifyTime.minute - s.notifyTime.minute % 5),
                  onDateTimeChanged: (d) {
                    HapticFeedback.selectionClick();
                    picked = TimeOfDay(hour: d.hour, minute: d.minute);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    s.setNotifyTime(picked);
  }

  Future<void> _confirmClear(BuildContext context, AppState s) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('완료 항목 지우기'),
        content: Text('${s.done.length}개'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.heavyImpact();
    final snapshot = s.clearDone();
    if (!context.mounted) return;
    showToast(
      context,
      '지움',
      icon: CupertinoIcons.trash_fill,
      colors: const [Color(0xFFFF453A), Color(0xFFFF2D55)],
      undo: () => s.restoreAll(snapshot),
    );
  }
}

// ---------------------------------------------------------------- 구성 요소

class _Section extends StatelessWidget {
  const _Section({this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(header!, style: T.footnote),
            ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: K.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 58),
                      child: Divider(height: 0.5, thickness: 0.5, color: K.separator),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 둥근 사각 그라데이션 아이콘 (iOS 설정 앱)
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.colors});

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(icon, size: 17, color: Colors.white),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.icon,
    this.colors = const [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.enabled = true,
    this.muted = false,
    this.destructive = false,
  });

  final String title;
  final IconData? icon;
  final List<Color> colors;
  final Widget? leading;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final bool enabled;
  final bool muted;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final lead = leading ?? (icon == null ? null : _IconBox(icon: icon!, colors: colors));
    final content = AnimatedOpacity(
      duration: Motion.fast,
      opacity: enabled ? 1 : 0.4,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: leading != null ? 12 : 10),
        child: Row(
          children: [
            if (lead != null) ...[lead, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: destructive
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  destructive
                      ? GradientText(
                          title,
                          gradient: K.danger,
                          style: T.body.copyWith(fontWeight: FontWeight.w600),
                        )
                      : Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: leading != null
                              ? T.title3
                              : T.body.copyWith(color: muted ? K.label3 : K.label),
                        ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: T.footnote),
                  ],
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(value!, style: T.body.copyWith(color: K.label2)),
              ),
            ?trailing,
            if (chevron)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(CupertinoIcons.chevron_right, size: 16, color: K.gray3),
              ),
          ],
        ),
      ),
    );
    if (onTap == null || !enabled) return content;
    return Pressable(onTap: onTap, scale: 0.98, child: content);
  }
}

/// 제목 + 아래 전체 폭 컨트롤
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.colors,
    required this.title,
    required this.child,
    this.enabled = true,
  });

  final IconData icon;
  final List<Color> colors;
  final String title;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBox(icon: icon, colors: colors),
                  const SizedBox(width: 14),
                  Text(title, style: T.body),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented<V extends Object> extends StatelessWidget {
  const _Segmented({required this.value, required this.items, required this.onChanged});

  final V value;
  final Map<V, String> items;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<V>(
      groupValue: value,
      onValueChanged: (v) {
        if (v == null) return;
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      children: {
        for (final e in items.entries)
          e.key: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(e.value, style: T.subhead),
          ),
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.text, required this.on, required this.onTap});

  final String text;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      child: AnimatedContainer(
        duration: Motion.med,
        curve: Motion.spring,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          gradient: on ? K.brand2 : null,
          color: on ? null : K.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: T.caption.copyWith(color: on ? Colors.white : K.label2),
        ),
      ),
    );
  }
}
