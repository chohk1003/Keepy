import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../theme.dart';
import 'fx.dart';

/// 하단 고정 빠른 입력 바 (UI설계서 02-3, 03-3, 07)
/// - 유리 캡슐, 포커스 시 태그 칩이 펼쳐짐
/// - 1~100자일 때만 전송 버튼이 그라데이션으로 튀어나옴
/// - 빈 입력 전송 시 좌우로 흔들림
class QuickInputBar extends StatefulWidget {
  const QuickInputBar({
    super.key,
    required this.onSubmit,
    this.onCamera,
    this.dueLabel,
  });

  final void Function(String title, Set<TaskTag> tags) onSubmit;
  final VoidCallback? onCamera;

  /// 날짜 화면에서 자동 지정되는 날짜
  final String? dueLabel;

  /// 칩이 접혀 있을 때 높이 (배치 계산용)
  static const height = 66.0;

  @override
  State<QuickInputBar> createState() => _QuickInputBarState();
}

class _QuickInputBarState extends State<QuickInputBar> with TickerProviderStateMixin {
  static const maxLen = 100;

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final Set<TaskTag> _tags = {};

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int get _len => _ctrl.text.trim().characters.length;

  bool get _valid => _len >= 1 && _len <= maxLen;

  void _submit() {
    if (!_valid) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      return;
    }
    widget.onSubmit(_ctrl.text.trim(), {..._tags});
    HapticFeedback.mediumImpact();
    _pulse.forward(from: 0);
    _ctrl.clear();
    setState(() => _tags.clear());
  }

  @override
  Widget build(BuildContext context) {
    final open = _focus.hasFocus;
    return TextFieldTapRegion(
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Glass(
            radius: 28,
            opacity: 0.82,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: Motion.med,
                    curve: Motion.spring,
                    alignment: Alignment.bottomCenter,
                    child: open ? _chips() : const SizedBox(width: double.infinity),
                  ),
                  Row(
                    children: [
                      if (widget.onCamera != null)
                        _RoundButton(
                          icon: CupertinoIcons.camera_fill,
                          onTap: widget.onCamera!,
                        )
                      else
                        const SizedBox(width: 8),
                      Expanded(
                        // 포커스 전에는 탭만 받음 → 좌우로 밀면 화면(탭) 전환
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: open ? null : _focus.requestFocus,
                          child: IgnorePointer(
                            ignoring: !open,
                            child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: T.body,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(),
                          onEditingComplete: () {}, // 전송 후 키보드 유지
                          onTapOutside: (_) => _focus.unfocus(),
                          inputFormatters: [LengthLimitingTextInputFormatter(maxLen)],
                          decoration: InputDecoration(
                            hintText: widget.dueLabel == null
                                ? '새로운 할 일'
                                : '${widget.dueLabel} 할 일',
                            hintStyle: T.body.copyWith(color: K.label3),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                        ),
                          ),
                        ),
                      ),
                      _SendButton(
                        key: const ValueKey('send'),
                        enabled: _valid,
                        pulse: _pulse,
                        onTap: _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (widget.dueLabel != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: K.brand2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.calendar, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(widget.dueLabel!, style: T.caption.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            for (final g in TaskTag.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TagToggle(
                  tag: g,
                  selected: _tags.contains(g),
                  onTap: () => setState(() {
                    if (!_tags.remove(g)) _tags.add(g);
                  }),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${_ctrl.text.characters.length}/$maxLen',
                style: T.caption.copyWith(color: K.label3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 선택형 태그 칩
class TagToggle extends StatelessWidget {
  const TagToggle({super.key, required this.tag, required this.selected, required this.onTap});

  final TaskTag tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: AnimatedContainer(
        duration: Motion.med,
        curve: Motion.out,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? tag.gradient : null,
          color: selected ? null : K.fill,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? K.glow(tag.color, a: 0.3, blur: 10) : const [],
        ),
        child: Text(
          '#${tag.label}',
          style: T.caption.copyWith(
            fontSize: 13,
            color: selected ? Colors.white : K.label2,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.85,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: K.fill, shape: BoxShape.circle),
        child: Icon(icon, size: 19, color: K.label2),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.enabled,
    required this.pulse,
    required this.onTap,
  });

  final bool enabled;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '추가',
      child: Pressable(
        onTap: onTap,
        haptic: false,
        scale: 0.85,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final p = pulse.value;
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (p > 0 && p < 1)
                  Container(
                    width: 40 + 26 * p,
                    height: 40 + 26 * p,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: K.indigo.withValues(alpha: 0.5 * (1 - p)),
                        width: 2,
                      ),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: AnimatedContainer(
            duration: Motion.med,
            curve: Motion.out,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled ? K.brand : null,
              color: enabled ? null : K.fill2,
              boxShadow: enabled ? K.glow(K.indigo, a: 0.4, blur: 12) : const [],
            ),
            child: AnimatedRotation(
              turns: enabled ? 0 : -0.25,
              duration: Motion.med,
              curve: Motion.spring,
              child: Icon(
                CupertinoIcons.arrow_up,
                size: 20,
                color: enabled ? Colors.white : K.label3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
