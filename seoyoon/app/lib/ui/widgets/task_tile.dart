import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/shadows.dart';
import '../../core/theme.dart';
import '../../models/task.dart';
import '../../models/task_status.dart';
import 'basics.dart';
import 'scroll_aware.dart';

/// 한 번에 하나의 할 일 블럭만 열려 있게 한다 (삭제 버튼이 열린 블럭).
class SwipeGroupController extends ValueNotifier<String?> {
  SwipeGroupController() : super(null);
  void closeAll() => value = null;
}

class SwipeGroup extends InheritedWidget {
  const SwipeGroup({super.key, required this.controller, required super.child});
  final SwipeGroupController controller;

  static SwipeGroupController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SwipeGroup>()?.controller;

  @override
  bool updateShouldNotify(SwipeGroup oldWidget) => controller != oldWidget.controller;
}

/// 할 일 블럭 (UI 설계서 02-2, 05 / prompts_log #3, #13 / v0.3 요청 #3).
///
/// - 오른쪽 → 왼쪽으로 당기기: **날짜 설정만** 나온다. 당긴 거리에 따라
///   +1 → +2 → +7 일이 단계마다 '딸깍' 걸리고, 손을 떼면 그 날짜로 저장.
/// - 누른 채 아래로 당기면 하던 조작이 무효(취소)된다.
/// - 왼쪽 → 오른쪽으로 당기기: 삭제 버튼에 걸리고, 절반 넘게 세게 끌고 놓으면 즉시 삭제.
/// - [editing] 이면 스와이프 대신 오른쪽 손잡이로 끌어서 순서를 바꾼다.
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.status,
    required this.today,
    required this.onToggle,
    required this.onSetDue,
    required this.onDelete,
    this.onOpen,
    this.editing = false,
    this.reorderIndex,
  });

  final Task task;
  final TaskStatus status;
  final DateTime today;
  final VoidCallback onToggle;
  final ValueChanged<DateTime> onSetDue;
  final VoidCallback onDelete;
  final VoidCallback? onOpen;

  /// 편집 모드 (순서 바꾸기).
  final bool editing;

  /// 편집 모드에서 SliverReorderableList 안의 위치 (손잡이 연결용).
  final int? reorderIndex;

  /// 당기는 거리에 따라 고를 수 있는 날짜 (오늘 기준 +N일).
  /// 1~7일 전부로 바꾸려면 <int>[1, 2, 3, 4, 5, 6, 7] 로 고치면 된다.
  static const dateStops = <int>[1, 2, 7];

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile>
    with SingleTickerProviderStateMixin, ScrollAwareState<TaskTile> {
  static const double _badgeWidth = 100; // 날짜 배지 자리
  static const double _deleteWidth = 86;
  static const double _gap = 8;
  static const double _firstStop = 46; // 이만큼 당기면 첫 단계(+1)
  static const double _stopSpacing = 58; // 다음 단계까지 거리
  static const double _snapIn = 0.42;
  static const double _cancelDown = 28; // 아래로 이만큼 당기면 취소

  late final AnimationController _offset = AnimationController.unbounded(vsync: this);
  SwipeGroupController? _group;

  bool _deleteOpen = false;
  bool _dragging = false;
  bool _cancelled = false;
  double _raw = 0; // 손가락이 실제로 움직인 거리 (부호 포함)
  double _startY = 0;
  int _stop = -1; // 왼쪽: 고른 단계 (-1 = 아직 없음)
  int _zone = 0; // 오른쪽: 0 없음, 1 미달, 2 삭제 걸림, 3 즉시 삭제
  double _cardWidth = 300;
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = SwipeGroup.maybeOf(context);
    if (g != _group) {
      _group?.removeListener(_onGroupChanged);
      _group = g;
      _group?.addListener(_onGroupChanged);
    }
  }

  @override
  void didUpdateWidget(TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && !oldWidget.editing) _close();
  }

  @override
  void dispose() {
    _group?.removeListener(_onGroupChanged);
    _offset.dispose();
    super.dispose();
  }

  void _onGroupChanged() {
    if (_group?.value != widget.task.id && _deleteOpen) _close();
  }

  /// 삭제 버튼이 열린 채 화면 밖으로 절반 넘게 나가면 닫는다.
  @override
  void onScrollChanged() {
    if (!_deleteOpen || _dragging) return;
    final g = viewportGeometry();
    if (g == null) return;
    final (top, height, viewport) = g;
    final visible = (math.min(top + height, viewport) - math.max(top, 0.0)).clamp(0.0, height);
    if (visible / height < 0.5) _close();
  }

  // ------------------------------------------------------------ 열고 닫기

  void _animateTo(double target, {Duration duration = KeepyMotion.normal}) {
    _offset.animateTo(target, duration: duration, curve: KeepyMotion.settle);
  }

  void _close() {
    if (_deleteOpen) setState(() => _deleteOpen = false);
    _raw = 0;
    _stop = -1;
    _zone = 0;
    _animateTo(0);
  }

  void _openDelete() {
    setState(() => _deleteOpen = true);
    _group?.value = widget.task.id;
    _raw = _deleteWidth;
    _animateTo(_deleteWidth);
  }

  void _deleteNow() {
    HapticFeedback.mediumImpact();
    _offset.animateTo(_cardWidth + 40, duration: KeepyMotion.fast, curve: Curves.easeIn).whenComplete(() {
      if (mounted) widget.onDelete();
    });
  }

  // ------------------------------------------------------------ 드래그 → 위치 (단계 스냅)

  int _stopFor(double distance) {
    if (distance < _firstStop) return -1;
    return math.min(TaskTile.dateStops.length - 1, ((distance - _firstStop) / _stopSpacing).floor());
  }

  /// 손가락 거리 → 화면에 보이는 카드 이동량.
  /// 손을 그대로 따라가지 않고 단계마다 걸린다 (prompts_log #3, #13).
  double _visualFor(double raw) {
    if (raw < 0) {
      final d = -raw;
      final stop = _stopFor(d);
      if (stop < 0) return -d * 0.5; // 무거운 구간
      final last = _firstStop + _stopSpacing * TaskTile.dateStops.length;
      final rubber = d > last ? (d - last) * 0.08 : 0.0;
      return -(_badgeWidth + stop * 10 + rubber); // 단계마다 10px씩 '딸깍'
    } else {
      final d = raw;
      const w = _deleteWidth;
      final commit = _cardWidth * 0.55;
      if (d < w * _snapIn) return d * 0.55;
      if (d < commit) return w + (d - w) * 0.08; // 삭제 버튼에 걸림
      return d * 0.92; // 즉시 삭제 구간
    }
  }

  int _zoneFor(double raw) {
    if (raw <= 0) return 0;
    if (raw < _deleteWidth * _snapIn) return 1;
    if (raw < _cardWidth * 0.55) return 2;
    return 3;
  }

  void _onDragStart(DragStartDetails d) {
    _dragging = true;
    _cancelled = false;
    _startY = d.globalPosition.dy;
    _raw = _deleteOpen ? _deleteWidth : 0;
    _stop = -1;
    _zone = _zoneFor(_raw);
    _offset.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging || _cancelled) return;
    _raw += d.delta.dx;
    // 삭제 버튼이 열린 상태에서는 왼쪽(날짜)으로 넘어가지 않고 닫힘까지만
    if (_deleteOpen && _raw < 0) _raw = 0;

    final stop = _raw < 0 ? _stopFor(-_raw) : -1;
    final zone = _zoneFor(_raw);
    final target = _visualFor(_raw);
    final changed = stop != _stop || zone != _zone;
    if (changed) {
      if (stop >= 0 && stop != _stop) HapticFeedback.selectionClick();
      if (zone == 2 && _zone != 2) HapticFeedback.selectionClick();
      if (zone == 3 && _zone != 3) HapticFeedback.mediumImpact();
      _stop = stop;
      _zone = zone;
      _animateTo(target, duration: const Duration(milliseconds: 110));
      setState(() {});
    } else if (_offset.isAnimating) {
      _animateTo(target, duration: const Duration(milliseconds: 70));
    } else {
      _offset.value = target;
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    if (_cancelled) return;
    final v = d.primaryVelocity ?? 0;
    if (_raw < 0) {
      final stop = _stop;
      if (stop >= 0) {
        HapticFeedback.lightImpact();
        widget.onSetDue(addDays(widget.today, TaskTile.dateStops[stop]));
      }
      _close();
    } else if (_raw > 0) {
      if (_raw >= _cardWidth * 0.55) {
        _deleteNow();
      } else if (_raw >= _deleteWidth * _snapIn || v > 800) {
        _openDelete();
      } else {
        _close();
      }
    } else {
      _close();
    }
  }

  /// 누른 채 아래로 당기면 하던 조작을 무효로 (v0.3 요청 #3).
  void _onPointerMove(PointerMoveEvent e) {
    if (!_dragging || _cancelled) return;
    if (e.position.dy - _startY > _cancelDown) {
      _cancelled = true;
      _dragging = false;
      HapticFeedback.lightImpact();
      if (_deleteOpen) {
        _openDelete();
      } else {
        _close();
      }
      setState(() {});
    }
  }

  // ------------------------------------------------------------ 완료 체크

  void _handleCheck() {
    if (_deleteOpen) {
      _close();
      return;
    }
    if (widget.task.done) {
      widget.onToggle();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _checking = true);
    // 체크·취소선이 보인 뒤 완료 목록으로 이동 (NFR-01: 0.3초 이내)
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      widget.onToggle();
      if (mounted) setState(() => _checking = false);
    });
  }

  // ------------------------------------------------------------ 화면

  @override
  Widget build(BuildContext context) {
    if (widget.editing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildCard(editing: true),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Listener(
        onPointerMove: _onPointerMove,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: () {
            if (_dragging) {
              _dragging = false;
              if (!_deleteOpen) _close();
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _cardWidth = constraints.maxWidth;
              return AnimatedBuilder(
                animation: _offset,
                builder: (context, _) => _buildStack(_offset.value),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStack(double off) {
    final right = off < 0 ? -off : 0.0; // 카드 오른쪽이 줄어드는 양
    final left = off > 0 ? off : 0.0; // 카드 왼쪽이 줄어드는 양
    final rightProgress = (right / _badgeWidth).clamp(0.0, 1.0);
    final leftProgress = (left / _deleteWidth).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (right > 1)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: math.max(right - _gap, 0),
            child: _buildDateBadge(rightProgress),
          ),
        if (left > 1)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: math.max(left - _gap, 0),
            child: _buildDeleteArea(leftProgress),
          ),
        // 카드는 최대 45%까지만 줄고, 그 이상(즉시 삭제 구간)은 옆으로 밀려난다.
        Transform.translate(
          offset: Offset(math.max(0.0, left - _cardWidth * 0.45), 0),
          child: Padding(
            padding: EdgeInsets.only(
              left: math.min(left, _cardWidth * 0.45),
              right: math.min(right, _cardWidth * 0.45),
            ),
            child: _buildCard(),
          ),
        ),
      ],
    );
  }

  /// 당기는 동안 오른쪽에 보이는 날짜 배지: +1 / +2 / +7 과 실제 날짜.
  Widget _buildDateBadge(double progress) {
    final stop = _stop;
    final active = stop >= 0;
    final days = active ? TaskTile.dateStops[stop] : TaskTile.dateStops.first;
    final date = addDays(widget.today, days);

    return ClipRRect(
      borderRadius: BorderRadius.circular(KeepyRadius.card),
      child: OverflowBox(
        alignment: Alignment.centerRight,
        minWidth: _badgeWidth - _gap,
        maxWidth: _badgeWidth - _gap,
        child: AnimatedContainer(
          duration: KeepyMotion.fast,
          decoration: BoxDecoration(
            gradient: active ? KeepyGradients.primary : null,
            color: active ? null : KeepyColors.fill,
            borderRadius: BorderRadius.circular(KeepyRadius.card),
          ),
          child: Opacity(
            opacity: progress,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 110),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    '+$days',
                    key: ValueKey<int>(active ? days : 0),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: active ? Colors.white : KeepyColors.tertiaryLabel,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMonthDay(date)} (${weekdayKo(date)})',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : KeepyColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '↓ 내리면 취소',
                  style: TextStyle(
                    fontSize: 9,
                    color: active ? Colors.white.withValues(alpha: 0.8) : KeepyColors.tertiaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteArea(double progress) {
    final commit = _zone == 3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _deleteOpen ? _deleteNow : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KeepyRadius.card),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: KeepyGradients.delete)),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _deleteWidth - _gap,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.7 + 0.3 * progress,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        commit ? CupertinoIcons.trash_fill : CupertinoIcons.trash,
                        color: Colors.white,
                        size: 19,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        commit ? '놓으면 삭제' : '삭제',
                        maxLines: 1,
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({bool editing = false}) {
    final task = widget.task;
    final status = widget.status;
    final checked = task.done || _checking;
    final elevated = _deleteOpen || _dragging;
    final index = widget.reorderIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editing
          ? null
          : () {
              if (_deleteOpen) {
                _close();
              } else {
                widget.onOpen?.call();
              }
            },
      child: AnimatedContainer(
        duration: KeepyMotion.fast,
        curve: KeepyMotion.settle, // 그림자에는 되튐 곡선 금지 (prompts_log #4)
        constraints: const BoxConstraints(minHeight: 58),
        padding: EdgeInsets.fromLTRB(4, 4, editing ? 4 : 14, 4),
        decoration: BoxDecoration(
          color: task.done ? KeepyColors.doneCard : KeepyColors.card,
          borderRadius: BorderRadius.circular(KeepyRadius.card),
          border: Border.all(
            color: editing ? KeepyColors.blue.withValues(alpha: 0.25) : KeepyColors.hairline,
            width: editing ? 1 : 0.8,
          ),
          boxShadow: task.done ? null : cardShadow(elevated ? 0.7 : 0),
        ),
        child: Row(
          children: <Widget>[
            KeepyCheckbox(
              checked: checked,
              size: 22,
              warning: status == TaskStatus.delayed,
              onTap: editing ? null : _handleCheck,
            ),
            if (editing) const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedDefaultTextStyle(
                      duration: KeepyMotion.fast,
                      style: KeepyText.body.copyWith(
                        color: checked ? KeepyColors.secondaryLabel : KeepyColors.label,
                        decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: KeepyColors.secondaryLabel,
                      ),
                      child: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (_metaWidgets().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _metaWidgets(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (editing && index != null)
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(CupertinoIcons.line_horizontal_3, color: KeepyColors.secondaryLabel, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _metaWidgets() {
    final task = widget.task;
    final status = widget.status;
    final due = task.due;
    final out = <Widget>[];

    switch (status) {
      case TaskStatus.delayed:
        out.add(const Pill('지연', gradient: KeepyGradients.delayed));
        if (due != null) out.add(_metaText(relativeDayLabel(due, widget.today)));
      case TaskStatus.lateDone:
        out.add(const Pill('늦은 완료', color: KeepyColors.orange));
        if (due != null) out.add(_metaText(relativeDayLabel(due, widget.today)));
      case TaskStatus.todo:
        if (due == null) {
          out.add(Pill('날짜 미지정', color: KeepyColors.secondaryLabel, background: KeepyColors.fill));
        } else if (isSameDay(due, widget.today)) {
          out.add(const Pill('오늘'));
        } else {
          out.add(Pill(relativeDayLabel(due, widget.today), color: KeepyColors.secondaryLabel, background: KeepyColors.fill));
        }
      case TaskStatus.done:
        if (due != null) out.add(_metaText(relativeDayLabel(due, widget.today)));
    }
    for (final tag in task.tags) {
      out.add(_metaText('#$tag'));
    }
    return out;
  }

  Widget _metaText(String text) => Text(text, style: KeepyText.footnote);
}
