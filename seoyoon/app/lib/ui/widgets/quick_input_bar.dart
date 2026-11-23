import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/shadows.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../state/keepy_scope.dart';
import 'basics.dart';

/// 하단 고정 빠른 입력 바 (UI 설계서 02-3, 03-3, 07 / FR-02).
///
/// - 바를 '눌렀을 때만' 입력 상태가 된다 (prompts_log #12).
///   입력 중이 아닐 때 바 위에서 좌우로 밀면 탭이 바뀐다.
/// - 입력 중에는 키보드 위에 태그 칩(#과제 #수업 #팀 프로젝트 #개인)이 뜬다.
/// - 공백 제외 1~100자일 때만 전송(화살표) 버튼이 켜진다 (CST-03).
class QuickInputBar extends StatefulWidget {
  const QuickInputBar({
    super.key,
    required this.hint,
    required this.onSubmit,
    required this.onCamera,
    required this.onSwipe,
    required this.onInvalid,
    this.focusNode,
  });

  final String hint;

  /// 등록 성공 여부를 돌려준다.
  final bool Function(String title, List<String> tags) onSubmit;
  final VoidCallback onCamera;

  /// -1: 왼쪽 탭으로, +1: 오른쪽 탭으로.
  final ValueChanged<int> onSwipe;

  /// 빈 입력으로 등록하려 할 때 (NFR-07 피드백).
  final ValueChanged<String> onInvalid;
  final FocusNode? focusNode;

  @override
  State<QuickInputBar> createState() => _QuickInputBarState();
}

class _QuickInputBarState extends State<QuickInputBar> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  final List<String> _tags = <String>[];
  double _dragDx = 0;

  bool get _focused => _focus.hasFocus;
  bool get _valid => TitleRule.isValid(_controller.text);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    _controller.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _controller.text.trim().isEmpty) _tags.clear();
    setState(() {});
  }

  void _submit() {
    final error = TitleRule.errorOf(_controller.text);
    if (error != null) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      widget.onInvalid(error);
      return;
    }
    final ok = widget.onSubmit(_controller.text, List<String>.of(_tags));
    if (ok) {
      HapticFeedback.lightImpact();
      _controller.clear();
      setState(_tags.clear);
      // 연속 입력을 위해 포커스는 유지 (애플 미리 알림처럼)
    }
  }

  void _toggleTag(String tag) {
    HapticFeedback.selectionClick();
    // 태그는 하나만 (v0.7): 다른 태그를 누르면 기존 태그는 자동으로 해제, 같은 태그를 다시 누르면 해제
    setState(() {
      final wasSelected = _tags.contains(tag);
      _tags.clear();
      if (!wasSelected) _tags.add(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final length = TitleRule.normalize(_controller.text).length;
    return TextFieldTapRegion(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedSize(
            duration: KeepyMotion.normal,
            curve: KeepyMotion.settle,
            alignment: Alignment.bottomCenter,
            child: _focused ? _buildTagRow(length) : const SizedBox(width: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(child: _buildField()),
                const SizedBox(width: 10),
                PressScale(
                  onTap: widget.onCamera,
                  child: Container(
                    key: const Key('camera-button'),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: KeepyColors.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: cardShadow(0),
                    ),
                    child: Icon(CupertinoIcons.camera, color: KeepyColors.label, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField() {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // 좌우로 3번 흔들림 (되튐 없이 sin 으로)
        final t = _shake.value;
        final dx = t == 0 || t == 1 ? 0.0 : 8 * (1 - t) * math.sin(t * 6 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focus.requestFocus(),
        onHorizontalDragStart: _focused ? null : (_) => _dragDx = 0,
        onHorizontalDragUpdate: _focused ? null : (d) => _dragDx += d.delta.dx,
        onHorizontalDragEnd: _focused
            ? null
            : (d) {
                final v = d.primaryVelocity ?? 0;
                if (_dragDx < -40 || v < -400) {
                  widget.onSwipe(1);
                } else if (_dragDx > 40 || v > 400) {
                  widget.onSwipe(-1);
                }
                _dragDx = 0;
              },
        child: AnimatedContainer(
          duration: KeepyMotion.fast,
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 5),
          decoration: BoxDecoration(
            color: KeepyColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused ? KeepyColors.blue.withValues(alpha: 0.35) : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: cardShadow(_focused ? 0.4 : 0),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: IgnorePointer(
                  // 누르기 전에는 글자 칸이 터치를 가로채지 않게 → 바 위 좌우 밀기 = 탭 전환
                  ignoring: !_focused,
                  child: TextField(
                    key: const Key('quick-input'),
                    controller: _controller,
                    focusNode: _focus,
                    textInputAction: TextInputAction.done,
                    maxLength: TitleRule.maxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    onSubmitted: (_) {
                      _submit();
                      _focus.requestFocus();
                    },
                    onTapOutside: (_) => _focus.unfocus(),
                    style: KeepyText.body,
                    cursorColor: KeepyColors.blue,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      counterText: '',
                      hintText: widget.hint,
                      hintStyle: KeepyText.body.copyWith(color: KeepyColors.tertiaryLabel),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _SendButton(enabled: _valid, onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagRow(int length) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final tag in KeepyScope.of(context).settings.settings.tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TagChip(
                        label: '#$tag',
                        selected: _tags.contains(tag),
                        onTap: () => _toggleTag(tag),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$length/${TitleRule.maxLength}',
            style: KeepyText.footnote.copyWith(
              color: length > 90 ? KeepyColors.orange : KeepyColors.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      key: const Key('send-button'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: KeepyMotion.fast,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: enabled ? KeepyGradients.primary : null,
          color: enabled ? null : KeepyColors.fill,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled ? glowShadow(KeepyColors.blue, strength: 0.7) : null,
        ),
        child: Icon(
          CupertinoIcons.arrow_up,
          size: 20,
          color: enabled ? Colors.white : KeepyColors.tertiaryLabel,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KeepyMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? KeepyGradients.primary : null,
          color: selected ? null : KeepyColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : KeepyColors.separator),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : KeepyColors.label,
          ),
        ),
      ),
    );
  }
}
