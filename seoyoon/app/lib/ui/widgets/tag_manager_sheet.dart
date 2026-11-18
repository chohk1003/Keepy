import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/task.dart';
import '../../state/keepy_scope.dart';
import 'basics.dart';

/// 태그 관리 (v0.3 요청 #4): 할 일 수정 > 태그 옆 톱니바퀴, 또는 설정에서 연다.
///
/// - 새 태그 추가
/// - 이름 바꾸기 → 그 태그가 달린 할 일도 함께 바뀜
/// - 삭제 → 할 일에서도 떼어 냄 (할 일 자체는 남음)
///
/// [onRenamed]/[onDeleted]: 수정 중인 화면(할 일 수정 시트)이 아직 저장 안 한
/// 선택 상태를 맞출 수 있게 알려 준다.
Future<void> showTagManager(
  BuildContext context, {
  void Function(String from, String to)? onRenamed,
  ValueChanged<String>? onDeleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x52000000),
    builder: (_) => _TagManager(onRenamed: onRenamed, onDeleted: onDeleted),
  );
}

class _TagManager extends StatelessWidget {
  const _TagManager({this.onRenamed, this.onDeleted});

  final void Function(String from, String to)? onRenamed;
  final ValueChanged<String>? onDeleted;

  Future<String?> _askName(BuildContext context, {required String title, String initial = '', String? except}) {
    final scope = KeepyScope.of(context);
    final controller = TextEditingController(text: initial);
    String? error;
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CupertinoTextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: TagRule.maxLength,
                  placeholder: '예: 동아리',
                  prefix: const Padding(padding: EdgeInsets.only(left: 8), child: Text('#')),
                  onChanged: (_) => setLocal(() => error = null),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(error!, style: const TextStyle(color: KeepyColors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final e = TagRule.errorOf(controller.text, scope.settings.settings.tags, except: except);
                if (e != null) {
                  setLocal(() => error = e);
                  return;
                }
                Navigator.pop(ctx, TagRule.normalize(controller.text));
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final scope = KeepyScope.of(context);
    final name = await _askName(context, title: '새 태그');
    if (name == null) return;
    HapticFeedback.lightImpact();
    scope.settings.update((s) => s.copyWith(tags: <String>[...s.tags, name]));
  }

  Future<void> _rename(BuildContext context, String tag) async {
    final scope = KeepyScope.of(context);
    final name = await _askName(context, title: '태그 이름 바꾸기', initial: tag, except: tag);
    if (name == null || name == tag) return;
    scope.settings.update((s) => s.copyWith(tags: <String>[for (final t in s.tags) t == tag ? name : t]));
    scope.tasks.renameTag(tag, name);
    onRenamed?.call(tag, name);
  }

  void _delete(BuildContext context, String tag) {
    final scope = KeepyScope.of(context);
    final count = scope.tasks.countWithTag(tag);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('#$tag 태그를 지울까요?'),
        content: Text(count == 0 ? '이 태그를 단 할 일은 없어요.' : '할 일 $count개에서 이 태그가 떨어져요. 할 일은 그대로 남아요.'),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              scope.settings.update((s) => s.copyWith(tags: s.tags.where((t) => t != tag).toList()));
              scope.tasks.removeTag(tag);
              onDeleted?.call(tag);
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = KeepyScope.of(context);
    return ListenableBuilder(
      listenable: scope.settings,
      builder: (context, _) {
        final tags = scope.settings.settings.tags;
        final canAdd = tags.length < TagRule.maxCount;
        return Container(
          decoration: BoxDecoration(
            color: KeepyColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
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
                      Icon(CupertinoIcons.gear_alt, size: 19, color: KeepyColors.blue),
                      SizedBox(width: 8),
                      Text('태그 관리', style: KeepyText.title),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('≡ 를 끌어 순서를 바꾸고, 이름을 누르면 바꿀 수 있어요. 바꾸거나 지우면 할 일에도 반영돼요.', style: KeepyText.caption),
                  const SizedBox(height: 14),
                  // v0.4: 왼쪽 ≡ 손잡이로 끌어 태그 순서 바꾸기 (입력 바·수정 시트의 칩 순서도 따라감)
                  KeepyCard(
                    child: tags.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('태그가 없어요', style: KeepyText.caption),
                          )
                        : ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            padding: EdgeInsets.zero,
                            proxyDecorator: (child, index, animation) => Material(
                              color: KeepyColors.card,
                              elevation: 6,
                              shadowColor: const Color(0x33000000),
                              borderRadius: BorderRadius.circular(12),
                              child: child,
                            ),
                            onReorder: (oldIndex, newIndex) {
                              HapticFeedback.selectionClick();
                              scope.settings.update((st) {
                                final list = List<String>.of(st.tags);
                                final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
                                final moved = list.removeAt(oldIndex);
                                list.insert(target, moved);
                                return st.copyWith(tags: list);
                              });
                            },
                            children: <Widget>[
                              for (var i = 0; i < tags.length; i++)
                                _TagRow(
                                  key: ValueKey<String>('tag-${tags[i]}'),
                                  index: i,
                                  showDivider: i > 0,
                                  tag: tags[i],
                                  count: scope.tasks.countWithTag(tags[i]),
                                  onRename: () => _rename(context, tags[i]),
                                  onDelete: () => _delete(context, tags[i]),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  GradientButton(
                    label: canAdd ? '+ 새 태그 추가' : '태그는 ${TagRule.maxCount}개까지 만들 수 있어요',
                    onPressed: canAdd ? () => _add(context) : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    super.key,
    required this.index,
    required this.showDivider,
    required this.tag,
    required this.count,
    required this.onRename,
    required this.onDelete,
  });
  final int index;
  final bool showDivider;
  final String tag;
  final int count;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        border: showDivider ? Border(top: BorderSide(color: KeepyColors.separator, width: 0.6)) : null,
      ),
      child: Row(
        children: <Widget>[
          ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(CupertinoIcons.line_horizontal_3, size: 18, color: KeepyColors.secondaryLabel),
            ),
          ),
          Expanded(
            child: PressScale(
              onTap: onRename,
              scale: 0.98,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: <Widget>[
                    Text('#$tag', style: KeepyText.body.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('$count개', style: KeepyText.footnote),
                    const SizedBox(width: 6),
                    Icon(CupertinoIcons.pencil, size: 14, color: KeepyColors.tertiaryLabel),
                  ],
                ),
              ),
            ),
          ),
          PressScale(
            onTap: onDelete,
            scale: 0.85,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(CupertinoIcons.minus_circle_fill, color: KeepyColors.red, size: 21),
            ),
          ),
        ],
      ),
    );
  }
}
