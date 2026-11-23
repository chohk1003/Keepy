import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../state/keepy_scope.dart';
import '../../state/task_store.dart';
import 'basics.dart';
import 'mini_calendar.dart';
import 'tag_manager_sheet.dart';

/// 할 일 수정 시트 (FR-04): 블럭을 누르면 열린다.
/// 제목·태그·기한 수정과 삭제를 한곳에서.
Future<void> showTaskEditor(
  BuildContext context, {
  required TaskStore store,
  required Task task,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    builder: (ctx) => _TaskEditor(store: store, task: task, onDelete: onDelete),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.store, required this.task, required this.onDelete});
  final TaskStore store;
  final Task task;
  final VoidCallback onDelete;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.task.title);
  // 태그는 하나만 (v0.7). 예전에 여러 개 붙은 할 일은 첫 태그만 남긴다.
  late final List<String> _tags = List<String>.of(widget.task.tags.take(1));
  late DateTime? _due = widget.task.due;
  bool _pickingDate = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final ok = widget.store.update(
      widget.task.id,
      title: _title.text,
      tags: _tags,
      due: _due,
      clearDue: _due == null,
    );
    if (ok) {
      HapticFeedback.lightImpact();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.store.today;
    final error = TitleRule.errorOf(_title.text);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: KeepyColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          // 달력을 펼쳐 내용이 길어져도 작은 화면에서 넘치지 않게
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                    Text('할 일 수정', style: KeepyText.title),
                    const Spacer(),
                    PressScale(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDelete();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(CupertinoIcons.trash, color: KeepyColors.red, size: 21),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                KeepyCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _title,
                    autofocus: false,
                    maxLength: TitleRule.maxLength,
                    minLines: 1,
                    maxLines: 3,
                    style: KeepyText.body,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: '할 일 제목',
                      hintStyle: KeepyText.body.copyWith(color: KeepyColors.tertiaryLabel),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          error ?? ' ',
                          style: KeepyText.footnote.copyWith(color: KeepyColors.red),
                        ),
                      ),
                      Text('${TitleRule.normalize(_title.text).length}/${TitleRule.maxLength}', style: KeepyText.footnote),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Text('태그', style: KeepyText.caption),
                    const Spacer(),
                    // 태그 관리 (v0.3 요청 #4)
                    PressScale(
                      key: const Key('tag-settings'),
                      onTap: () => showTagManager(
                        context,
                        onRenamed: (from, to) => setState(() {
                          final i = _tags.indexOf(from);
                          if (i >= 0) _tags[i] = to;
                        }),
                        onDeleted: (tag) => setState(() => _tags.remove(tag)),
                      ),
                      scale: 0.85,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(CupertinoIcons.gear_alt, size: 19, color: KeepyColors.blue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ListenableBuilder(
                  listenable: KeepyScope.of(context).settings,
                  builder: (context, _) {
                    final available = KeepyScope.of(context).settings.settings.tags;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final tag in available)
                          PressScale(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              // 태그는 하나만 (v0.7): 다른 태그를 누르면 기존 태그는 자동으로 해제, 같은 태그를 다시 누르면 해제
                              setState(() {
                                final wasSelected = _tags.contains(tag);
                                _tags.clear();
                                if (!wasSelected) _tags.add(tag);
                              });
                            },
                            child: AnimatedContainer(
                              duration: KeepyMotion.fast,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: _tags.contains(tag) ? KeepyGradients.primary : null,
                                color: _tags.contains(tag) ? null : KeepyColors.card,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _tags.contains(tag) ? Colors.white : KeepyColors.label,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                KeepyCard(
                  child: Column(
                    children: <Widget>[
                      PressScale(
                        scale: 0.985,
                        onTap: () => setState(() => _pickingDate = !_pickingDate),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _pickingDate ? CupertinoIcons.calendar_badge_minus : CupertinoIcons.calendar,
                                size: 20,
                                color: KeepyColors.blue,
                              ),
                              const SizedBox(width: 10),
                              Text('기한', style: KeepyText.body),
                              const Spacer(),
                              Text(
                                _due == null ? '날짜 미지정' : '${formatFull(_due!)} · ${relativeDayLabel(_due!, today)}',
                                style: KeepyText.caption.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: KeepyMotion.normal,
                        curve: KeepyMotion.settle,
                        alignment: Alignment.topCenter,
                        // v0.4: 연·월·일을 돌리는 대신 빠른 선택 칩 + 한 달 달력에서 한 번에 고르기
                        child: _pickingDate
                            ? QuickDatePicker(
                                today: today,
                                selected: _due,
                                onChanged: (d) => setState(() => _due = d),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GradientButton(label: '저장', onPressed: error == null ? _save : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
