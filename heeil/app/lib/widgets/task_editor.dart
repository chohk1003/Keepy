import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../models/companion.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';

import 'task_actions.dart';

Future<void> showTaskEditor(BuildContext context, Task task) {
  final state = AppScope.read(context);
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Motion.sheet,
      reverseDuration: Motion.dismiss,
    ),
    builder: (_) => _Editor(task: task, state: state, hostContext: context),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.task,
    required this.state,
    required this.hostContext,
  });
  final Task task;
  final AppState state;
  final BuildContext hostContext;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _tags = {...widget.task.tags};
  late DateTime? _due = widget.task.due;
  bool _calendar = false;
  bool get _valid =>
      _title.text.trim().characters.isNotEmpty &&
      _title.text.trim().characters.length <= 100;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    widget.state.update(
      widget.task,
      title: _title.text,
      tags: _tags,
      due: _due,
      clearDue: _due == null,
    );
    Navigator.pop(context);
  }

  void _delete() {
    Navigator.pop(context);
    final index = widget.state.remove(widget.task);
    showToast(
      widget.hostContext,
      '삭제',
      icon: CupertinoIcons.trash_fill,
      undo: () => widget.state.restore(index, widget.task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOf(widget.state.now);
    final dates = <String, DateTime?>{
      '오늘': today,
      '내일': addDays(today, 1),
      '모레': addDays(today, 2),
      '다음 주': addDays(today, 8 - today.weekday),
      '없음': null,
    };
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(
              160,
              MediaQuery.sizeOf(context).height * .82 -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('할 일 수정', style: T.headline.copyWith(fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      tooltip: '삭제',
                      onPressed: _delete,
                      icon: const Icon(CupertinoIcons.trash, color: K.red),
                    ),
                    IconButton(
                      tooltip: '취소',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  key: const Key('task-title-editor'),
                  controller: _title,
                  minLines: 1,
                  maxLines: 1,
                  onChanged: (_) => setState(() {}),
                  style: T.body.copyWith(fontSize: 15),
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: InputDecoration(
                    hintText: '할 일 제목',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: K.fill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _valid ? '' : '할 일을 입력해 주세요',
                        style: T.caption.copyWith(color: K.red),
                      ),
                    ),
                    Text(
                      '${_title.text.characters.length}/100',
                      style: T.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('태그', style: T.footnote),
                const SizedBox(height: 2),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tag in TaskTag.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: ChoiceChip(
                            key: ValueKey('editor-tag-${tag.name}'),
                            label: Text(
                              tag.label,
                              style: TextStyle(fontSize: 12, color: tag.color),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            showCheckmark: false,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            selected: _tags.contains(tag),
                            onSelected: (_) => setState(() {
                              if (!_tags.remove(tag)) _tags.add(tag);
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('날짜', style: T.footnote),
                    const Spacer(),
                    TextButton.icon(
                      key: const Key('editor-calendar-toggle'),
                      onPressed: () => setState(() => _calendar = !_calendar),
                      icon: const Icon(CupertinoIcons.calendar, size: 17),
                      label: Text(_due == null ? '날짜 선택' : mdw(_due!)),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in dates.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            key: ValueKey('quick-date-${entry.key}'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            showCheckmark: false,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                            ),
                            label: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: entry.value == null
                                ? _due == null
                                : sameDay(_due, entry.value!),
                            onSelected: (_) =>
                                setState(() => _due = entry.value),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: Motion.feedback,
                  curve: Curves.easeOutCubic,
                  child: _calendar
                      ? CalendarDatePicker(
                          key: ValueKey(dayKey(_due ?? today)),
                          initialDate: _due ?? today,
                          firstDate: DateTime(
                            math.min((_due ?? today).year, today.year) - 1,
                          ),
                          lastDate: DateTime(
                            math.max((_due ?? today).year, today.year) + 10,
                          ),
                          currentDate: today,
                          onDateChanged: (d) => setState(() => _due = dayOf(d)),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('task-editor-save'),
                  onPressed: _valid ? _save : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: K.blue,
                  ),
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
