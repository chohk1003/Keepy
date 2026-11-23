import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'fx.dart';
import 'pill.dart';
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

class _TaskTileState extends State<TaskTile>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _motion =
      AnimationController.unbounded(vsync: this)..addListener(() {
        if (mounted) setState(() => _x = _motion.value);
      });
  double _shape(double raw, double limit) {
    final v = raw * .72;
    if (v <= limit) return v;
    final over = v - limit;
    return limit + (1 - 1 / (over * .55 / 110 + 1)) * 66;
  }

  double _unshape(double shown, double limit) {
    if (shown <= limit) return shown / .72;
    final extra = ((shown - limit) / 66).clamp(0.0, .99);
    return (limit + (1 / (1 - extra) - 1) * 110 / .55) / .72;
  }

  double _shownFor(double raw) => raw >= 0
      ? _shape(raw, 76)
      : raw <= -24
      ? -(80 + _shape((-raw - 24) * .32, 52))
      : raw * .45;

  double _rawFor(double shown) => shown >= 0
      ? _unshape(shown, 76)
      : shown <= -80
      ? -(24 + _unshape(-shown - 80, 52) / .32)
      : shown * 24 / 80;

  // Closing can pass through the snap gap; preserve that visual offset
  // when caught, then blend it out as the finger moves.
  double _resumeOffset = 0, _resumeTravel = 0;

  void _spring(double target, [double velocity = 0]) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = target;
      return;
    }
    _motion.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 1050, damping: 58),
        _x,
        target,
        velocity * .72,
      ),
    );
  }

  double _raw = 0, _x = 0, _startY = 0;
  bool _dragging = false, _cancelled = false, _deleteOpen = false;
  bool? _pendingDone;
  Timer? _commit;
  ScrollPosition? _scroll;
  Drag? _scrollDrag;
  VelocityTracker? _scrollVelocity;
  int? _pointer;
  @override
  bool get wantKeepAlive => _pointer != null;

  void _finishScroll({bool cancel = false}) {
    final drag = _scrollDrag;
    _scrollDrag = null;
    final velocity = _scrollVelocity?.getVelocity().pixelsPerSecond.dy ?? 0;
    _scrollVelocity = null;
    if (cancel) {
      drag?.cancel();
    } else {
      drag?.end(
        DragEndDetails(
          velocity: Velocity(pixelsPerSecond: Offset(0, velocity)),
          primaryVelocity: velocity,
        ),
      );
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (_scrollDrag == null &&
        _dragging &&
        !_cancelled &&
        (event.position.dy - _startY).abs() > 24) {
      _cancelled = true;
      _close();
      HapticFeedback.selectionClick();
      // The horizontal recognizer owns this pointer. Hand vertical movement
      // to the list's normal drag activity, retaining its boundary physics.
      _scrollVelocity = VelocityTracker.withKind(event.kind);
      _scrollDrag = _scroll?.drag(
        DragStartDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          sourceTimeStamp: event.timeStamp,
        ),
        () {
          _scrollDrag = null;
          _scrollVelocity = null;
        },
      );
      // Consume the cancel threshold, rather than jumping the list by it.
      _scrollVelocity?.addPosition(event.timeStamp, event.position);
      return;
    }
    if (_scrollDrag != null) {
      _scrollVelocity?.addPosition(event.timeStamp, event.position);
      _scrollDrag!.update(
        DragUpdateDetails(
          sourceTimeStamp: event.timeStamp,
          delta: Offset(0, event.delta.dy),
          primaryDelta: event.delta.dy,
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      );
    }
  }

  bool _measureQueued = false;

  /// 날짜 다이얼 단계 — 끌어온 거리의 경계와 그 단계가 뜻하는 일수.
  static const _stepEdges = <double>[24, 110, 180];
  static const _stepDays = <int>[0, 1, 2, 7];

  /// 경계에서 손이 조금 떨려도 단계가 오락가락하지 않도록 둔 여유.
  /// 올라가는 경계는 그대로 두고, 한 번 들어온 단계는 이만큼 더 돌아와야 풀린다.
  static const _stepSlack = 14.0;

  int _stepIndex = 0;
  int get _step => _stepDays[_stepIndex];

  /// [_raw] 에 맞춰 단계를 다시 정한다. 단계가 바뀐 그 순간에만 진동이 울려서
  /// 화면의 숫자와 손끝의 느낌이 어긋나지 않는다.
  void _syncStep({bool silent = false}) {
    final travel = -_raw;
    var next = _stepIndex;
    while (next < _stepEdges.length && travel >= _stepEdges[next]) {
      next++;
    }
    while (next > 0 && travel < _stepEdges[next - 1] - _stepSlack) {
      next--;
    }
    if (next == _stepIndex) return;
    _stepIndex = next;
    if (!silent) HapticFeedback.selectionClick();
  }

  bool get _done => _pendingDone ?? widget.task.done;
  bool get _today => sameDay(widget.task.due, DateTime.now());

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
    _finishScroll(cancel: true);
    _motion.dispose();
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
      _raw = 0;
      _stepIndex = 0;
      _deleteOpen = false;
      _dragging = false;
    });
    _spring(0);
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
    _motion.stop();
    _cancelled = false;
    setState(() {
      _dragging = true;
      _raw = _rawFor(_x);
      _resumeOffset = _x - _shownFor(_raw);
      _resumeTravel = 0;
      // 다시 잡은 자리의 단계를 조용히 맞춰 둔다 (잡자마자 진동하지 않게)
      _syncStep(silent: true);
    });
  }

  void _update(DragUpdateDetails d) {
    if (_cancelled) return;
    _raw += d.delta.dx;
    _resumeTravel += d.delta.dx.abs();
    final target =
        _shownFor(_raw) +
        _resumeOffset * (1 - _resumeTravel / 48).clamp(0.0, 1.0);
    if (_raw <= -24 || _resumeOffset.abs() > .5) {
      _spring(target);
    } else {
      _motion.stop();
      _motion.value = target;
    }
    _syncStep();
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
        _deleteOpen = _raw >= 50 || (d.primaryVelocity ?? 0) > 500;

        _dragging = false;
      });
      _spring(_deleteOpen ? 76 : 0, d.primaryVelocity ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TapRegion(
      onTapOutside: (_) {
        if (_deleteOpen) _close();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Listener(
          onPointerDown: (event) {
            if (_pointer != null) return;
            _pointer = event.pointer;
            updateKeepAlive();
            _startY = event.position.dy;
          },
          onPointerMove: _pointerMove,
          onPointerUp: (event) {
            if (event.pointer != _pointer) return;
            _finishScroll();
            _pointer = null;
            updateKeepAlive();
          },
          onPointerCancel: (event) {
            if (event.pointer != _pointer) return;
            _finishScroll(cancel: true);
            _pointer = null;
            updateKeepAlive();
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
                                color: _raw >= 230 ? K.red : K.overdueInk,
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
                                    _step == 0 ? '' : '+$_step일',
                                    style: T.headline.copyWith(
                                      fontSize: 15,
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
                      duration: Duration.zero,
                      padding: EdgeInsets.only(
                        left: _x > 0 ? reveal + 8 : 0,
                        right: _x < 0 ? reveal + 8 : 0,
                      ),
                      child: Pressable(
                        scale: .96,
                        haptic: false,
                        onTap: _deleteOpen ? _close : widget.onTap,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 58),
                          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                          decoration: BoxDecoration(
                            color: _done ? K.doneCard : K.card,
                            borderRadius: BorderRadius.circular(K.radiusCard),
                            border: Border.all(color: K.hairline, width: 0.8),
                            boxShadow: _done
                                ? null
                                : K.cardShadow(
                                    _deleteOpen || _dragging ? .7 : 0,
                                  ),
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
                                      maxLines: 1,
                                    ),
                                    if (widget.task.due != null ||
                                        widget.task.tags.isNotEmpty ||
                                        widget.status != TaskStatus.pending)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        // 카드가 줄어들어도 높이가 변하지 않게 한 줄로
                                        // 고정하고 넘치는 부분은 자른다 (목록이 튀지 않게).
                                        child: SizedBox(
                                          height:
                                              MediaQuery.textScalerOf(context)
                                                  .scale(12) +
                                              8,
                                          child: ClipRect(
                                            child: OverflowBox(
                                              maxWidth: 1200,
                                              alignment: Alignment.centerLeft,
                                              child: Row(
                                                key: ValueKey(
                                                  'meta-${widget.task.id}',
                                                ),
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (widget.status ==
                                                      TaskStatus.overdue)
                                                    const _Meta(
                                                      Pill(
                                                        '지연',
                                                        gradient: K.danger,
                                                      ),
                                                    ),
                                                  if (widget.status ==
                                                      TaskStatus.late)
                                                    const _Meta(
                                                      Pill(
                                                        '늦은 완료',
                                                        gradient: K.late,
                                                      ),
                                                    ),
                                                  if (widget.task.due != null)
                                                    _Meta(
                                                      Pill(
                                                        mdw(widget.task.due!),
                                                        color: _today
                                                            ? K.blue
                                                            : K.label2,
                                                      ),
                                                    ),
                                                  if (widget.task.due == null &&
                                                      !_done)
                                                    const _Meta(Pill('날짜 미지정')),
                                                  for (final tag
                                                      in widget.task.tags)
                                                    _Meta(
                                                      Pill(
                                                        '#${tag.label}',
                                                        color: _done
                                                            ? K.label3
                                                            : tag.color,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
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
}

/// 메타 한 칸 — 오른쪽 간격만 둔다 (한 줄 고정이라 Wrap 을 쓰지 않는다)
class _Meta extends StatelessWidget {
  const _Meta(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(right: 5), child: child);
}
