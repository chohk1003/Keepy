import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'fx.dart';
import 'quick_input_bar.dart';
import 'task_actions.dart';

/// 태스크 편집 시트 (FR-04) — 날짜는 휠 피커로 스냅 선택
Future<void> showTaskEditor(BuildContext context, Task task) {
  final state = AppScope.read(context);
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _Editor(task: task, state: state, hostContext: context),
  );
}

enum _DueMode { none, today, tomorrow, pick }

class _Editor extends StatefulWidget {
  const _Editor({required this.task, required this.state, required this.hostContext});

  final Task task;
  final AppState state;
  final BuildContext hostContext;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _ctrl = TextEditingController(text: widget.task.title);
  late final Set<TaskTag> _tags = {...widget.task.tags};
  late DateTime? _due = widget.task.due;
  final _today = dayOf(DateTime.now());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  DateTime get _tomorrow => addDays(_today, 1);

  _DueMode get _mode {
    if (_due == null) return _DueMode.none;
    if (sameDay(_due, _today)) return _DueMode.today;
    if (sameDay(_due, _tomorrow)) return _DueMode.tomorrow;
    return _DueMode.pick;
  }

  late bool _picking = _mode == _DueMode.pick;

  bool get _valid {
    final n = _ctrl.text.trim().characters.length;
    return n >= 1 && n <= 100;
  }

  void _save() {
    widget.state.update(
      widget.task,
      title: _ctrl.text,
      tags: _tags,
      due: _due,
      clearDue: _due == null,
    );
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _delete() {
    Navigator.pop(context);
    final s = widget.state;
    final t = widget.task;
    final i = s.remove(t);
    showToast(
      widget.hostContext,
      '삭제',
      icon: CupertinoIcons.trash_fill,
      colors: const [Color(0xFFFF453A), Color(0xFFFF2D55)],
      undo: () => s.restore(i, t),
    );
  }

  void _setMode(_DueMode m) {
    HapticFeedback.selectionClick();
    setState(() {
      _picking = m == _DueMode.pick;
      _due = switch (m) {
        _DueMode.none => null,
        _DueMode.today => _today,
        _DueMode.tomorrow => _tomorrow,
        _DueMode.pick => _due ?? addDays(_today, 2),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => Navigator.pop(context),
                  child: Text('취소', style: T.body.copyWith(color: K.blue)),
                ),
                const Spacer(),
                Text('편집', style: T.headline),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: _valid ? _save : null,
                  child: AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: _valid ? 1 : 0.3,
                    child: GradientText(
                      '완료',
                      style: T.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Group(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _ctrl,
                  style: T.body.copyWith(fontWeight: FontWeight.w600),
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  maxLines: null,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '제목',
                    suffixText: '${_ctrl.text.characters.length}/100',
                    suffixStyle: T.caption.copyWith(color: K.label3),
                  ),
                ),
              ),
            ),
            const _Caption('태그'),
            _Group(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in TaskTag.values)
                      TagToggle(
                        tag: g,
                        selected: _tags.contains(g),
                        onTap: () => setState(() {
                          if (!_tags.remove(g)) _tags.add(g);
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const _Caption('날짜'),
            _Group(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<_DueMode>(
                        groupValue: _mode,
                        onValueChanged: (m) {
                          if (m != null) _setMode(m);
                        },
                        children: {
                          _DueMode.none: const _Seg('없음'),
                          _DueMode.today: const _Seg('오늘'),
                          _DueMode.tomorrow: const _Seg('내일'),
                          _DueMode.pick: _Seg(_mode == _DueMode.pick ? mdw(_due!) : '선택'),
                        },
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: Motion.med,
                    curve: Motion.spring,
                    child: _picking
                        ? SizedBox(
                            height: 180,
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.date,
                              initialDateTime: _due ?? _today,
                              minimumYear: _today.year - 1,
                              maximumYear: _today.year + 3,
                              onDateTimeChanged: (d) {
                                HapticFeedback.selectionClick();
                                setState(() => _due = dayOf(d));
                              },
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Pressable(
              onTap: _delete,
              child: _Group(
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: GradientText(
                      '삭제',
                      gradient: K.danger,
                      style: T.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: T.subhead),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(text, style: T.footnote),
    );
  }
}
