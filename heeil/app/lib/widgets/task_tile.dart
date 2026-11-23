import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'fx.dart';
import 'square_check.dart';

/// Left: direct +1/+2/+7 day selection on release, relative to today.
/// Right: delete snap / full swipe. Vertical escape cancels either operation.
/// Tags are edited in the tap editor, not a second swipe panel.
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.status,
    required this.tagOrder,
    required this.onToggle,
    required this.onTap,
    required this.onDial,
    required this.onTag,
    required this.onDelete,
  });
  final Task task;
  final TaskStatus status;
  final List<TaskTag> tagOrder;
  final VoidCallback onToggle, onTap, onDelete;
  final ValueChanged<DateTime> onDial;
  final ValueChanged<TaskTag?> onTag;
  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  double _raw = 0, _x = 0, _startY = 0;
  bool _dragging = false, _cancelled = false, _deleteOpen = false;
  bool? _pendingDone;
  Timer? _commit;
  ScrollPosition? _scroll;
  bool _measureQueued = false;
  int get _step => -_raw < 50
      ? 0
      : -_raw < 110
      ? 1
      : -_raw < 180
      ? 2
      : 7;
  bool get _done => _pendingDone ?? widget.task.done;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _scroll) {
      _scroll?.removeListener(_onScroll);
      _scroll = next;
      _scroll?.addListener(_onScroll);
    }
  }

  @override
  void didUpdateWidget(TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_commit == null) _pendingDone = null;
  }

  @override
  void dispose() {
    _scroll?.removeListener(_onScroll);
    if (_commit?.isActive ?? false) {
      _commit!.cancel();
      scheduleMicrotask(widget.onToggle);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_deleteOpen || _measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (!mounted || !_deleteOpen) return;
      final box = context.findRenderObject(),
          viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
      if (box is! RenderBox ||
          viewport is! RenderBox ||
          !box.hasSize ||
          !viewport.hasSize) {
        return;
      }
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final visible =
          math.min(top + box.size.height, viewport.size.height) -
          math.max(top, 0.0);
      if (visible < box.size.height / 2) _close();
    });
  }

  void _close() {
    if (!mounted) return;
    setState(() {
      _x = 0;
      _raw = 0;
      _deleteOpen = false;
      _dragging = false;
    });
  }

  void _check() {
    if (_commit?.isActive ?? false) {
      _commit!.cancel();
      _commit = null;
      setState(() => _pendingDone = null);
      return;
    }
    setState(() => _pendingDone = !widget.task.done);
    _commit = Timer(const Duration(milliseconds: 520), () {
      _commit = null;
      widget.onToggle();
    });
  }

  void _delete() {
    _close();
    widget.onDelete();
  }

  void _start(DragStartDetails d) {
    _startY = d.globalPosition.dy;
    _cancelled = false;
    setState(() {
      _dragging = true;
      _raw = _deleteOpen ? 76 : 0;
    });
  }

  void _update(DragUpdateDetails d) {
    if (_cancelled) return;
    final before = _step;
    setState(() {
      _raw += d.delta.dx;
      _x = _raw >= 0
          ? math.min(120.0, _raw * .72)
          : -math.min(158.0, -_raw * .72);
    });
    if (_step != before) HapticFeedback.selectionClick();
  }

  void _end(DragEndDetails d) {
    if (_cancelled) return;
    if (_raw < 0) {
      final step = _step;
      _close();
      if (step > 0) widget.onDial(addDays(dayOf(DateTime.now()), step));
    } else if (_raw >= 230) {
      _delete();
    } else {
      setState(() {
        _deleteOpen = _raw >= 50;
        _x = _deleteOpen ? 76 : 0;
        _dragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    onTapOutside: (_) {
      if (_deleteOpen) _close();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Listener(
        onPointerMove: (event) {
          if (_dragging &&
              !_cancelled &&
              (event.position.dy - _startY).abs() > 36) {
            _cancelled = true;
            _close();
            HapticFeedback.selectionClick();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          onHorizontalDragCancel: _close,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final reveal = _x
                  .abs()
                  .clamp(0.0, math.max(0.0, constraints.maxWidth - 145))
                  .toDouble();
              return Stack(
                children: [
                  if (_x > .5)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: reveal,
                      child: Semantics(
                        label: '${widget.task.title} 삭제',
                        button: true,
                        child: GestureDetector(
                          key: ValueKey('del-${widget.task.id}'),
                          onTap: _delete,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _raw >= 230
                                  ? K.red
                                  : const Color(0xFFB75D53),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              CupertinoIcons.trash,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_x < -.5)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: reveal,
                      child: Container(
                        key: ValueKey('act-${widget.task.id}'),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _step == 0 ? K.fill2 : K.blue,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRect(
                          child: OverflowBox(
                            maxWidth: 130,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.calendar,
                                  color: _step == 0 ? K.ink : Colors.white,
                                  size: 19,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _step == 0 ? '그대로' : '+$_step일',
                                  style: T.headline.copyWith(
                                    color: _step == 0 ? K.ink : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedPadding(
                    duration: _dragging ? Duration.zero : Motion.fast,
                    padding: EdgeInsets.only(
                      left: _x > 0 ? reveal + 8 : 0,
                      right: _x < 0 ? reveal + 8 : 0,
                    ),
                    child: Pressable(
                      scale: .985,
                      haptic: false,
                      onTap: _deleteOpen ? _close : widget.onTap,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 68),
                        padding: const EdgeInsets.fromLTRB(4, 7, 12, 7),
                        decoration: BoxDecoration(
                          color: _done ? const Color(0xFFF7F9F6) : K.card,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFE4EAE3)),
                        ),
                        child: Row(
                          children: [
                            SquareCheck(
                              key: ValueKey('check-${widget.task.id}'),
                              value: _done,
                              onTap: _check,
                              colors: const [K.blue, K.blue],
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StrikeText(
                                    widget.task.title,
                                    struck: _done,
                                    style: T.body.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                  ),
                                  if (widget.task.due != null ||
                                      widget.task.tags.isNotEmpty ||
                                      widget.status == TaskStatus.overdue)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (widget.status ==
                                              TaskStatus.overdue)
                                            Text(
                                              '지연',
                                              style: T.caption.copyWith(
                                                color: K.red,
                                              ),
                                            ),
                                          if (widget.task.due != null)
                                            Text(
                                              mdw(widget.task.due!),
                                              style: T.caption,
                                            ),
                                          for (final tag in widget.task.tags)
                                            Text(
                                              '#${tag.label}',
                                              style: T.caption.copyWith(
                                                color: _done
                                                    ? K.label3
                                                    : tag.color,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
