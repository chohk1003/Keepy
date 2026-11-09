import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'fx.dart';
import 'square_check.dart';

enum _Mode { closed, open, dial, tag, delete }

/// 태스크 블럭
///
/// - 네모 체크: 완료 (체크 애니메이션을 보여 준 뒤 목록 이동)
/// - 탭: 편집 (무언가 열려 있으면 닫기)
/// - 왼쪽으로 끌기: 아이폰 알림처럼 카드가 줄어들며 오른쪽에 [날짜][태그]가 나오고, 놓아도 유지
///   · [날짜]를 끌면 그대로 / +1 ~ +7 스냅 다이얼
///   · [태그]를 끌면 그대로 / 자주 쓰는 태그 순 / 없음
///   · 다이얼·태그 패널은 두 버튼을 합친 영역 전체를 씀
/// - 오른쪽으로 끌기: 왼쪽에 삭제 버튼이 나온 상태로 스냅. 더 세게 끌면 바로 삭제
/// - 끄는 도중 손가락이 위·아래로 벗어나면 그 동작은 취소되고 원래대로
/// - 열린 채로 화면 밖으로 절반 이상 스크롤되면 원래대로
/// - 손가락 이동을 그대로 따라가지 않음: 버튼 폭까지는 72%, 그 뒤는 고무줄 저항
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

  /// 태그 선택 순서 (사용 빈도순)
  final List<TaskTag> tagOrder;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final ValueChanged<DateTime> onDial;

  /// null이면 태그 없음
  final ValueChanged<TaskTag?> onTag;
  final VoidCallback onDelete;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with SingleTickerProviderStateMixin {
  static const _actW = 150.0; // 왼쪽 끌기: [날짜][태그] 영역
  static const _delW = 76.0; // 오른쪽 끌기: 삭제 버튼 영역
  static const _follow = 0.72; // 버튼 폭까지 손가락을 따라가는 비율
  static const _fullDelete = 230.0; // 이만큼 손가락을 끌면 바로 삭제
  static const _cancelDy = 36.0; // 위·아래로 이만큼 벗어나면 취소
  static const _dialPx = 26.0;
  static const _tagPx = 40.0;
  static const _maxStep = 7;
  static const _minCard = 160.0;
  static const _commitDelay = Duration(milliseconds: 520);

  /// > 0: 왼쪽 삭제 영역 폭, < 0: 오른쪽 액션 영역 폭(음수)
  double _x = 0;

  /// 손가락 누적 이동량 (부호 포함)
  double _raw = 0;
  _Mode _mode = _Mode.closed;
  Offset _start = Offset.zero;
  bool _cancelled = false;
  bool _flyingOut = false;
  bool _hint = false;
  bool _nearFull = false;

  // 다이얼·태그 선택 (0 = 그대로)
  double _acc = 0;
  int _step = 0;
  int _baseStep = 0;
  int _tagIdx = 0;
  int _baseTagIdx = 0;

  // 체크 지연 반영
  bool? _pendingDone;
  Timer? _commit;

  // 화면 밖으로 나가면 닫기
  ScrollPosition? _pos;
  bool _measureQueued = false;

  late final AnimationController _ctrl = AnimationController.unbounded(vsync: this)
    ..addListener(() => setState(() => _x = _ctrl.value));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _pos) {
      _pos?.removeListener(_onScroll);
      _pos = pos;
      _pos?.addListener(_onScroll);
    }
  }

  @override
  void didUpdateWidget(TaskTile old) {
    super.didUpdateWidget(old);
    if (_commit == null) _pendingDone = null;
  }

  @override
  void dispose() {
    _pos?.removeListener(_onScroll);
    _ctrl.dispose();
    if (_commit?.isActive ?? false) {
      _commit!.cancel();
      scheduleMicrotask(widget.onToggle);
    }
    super.dispose();
  }

  bool get _done => _pendingDone ?? widget.task.done;
  DateTime get _base => widget.task.due ?? dayOf(DateTime.now());

  // ---------------------------------------------------------------- 화면 밖 감지
  void _onScroll() {
    if (_mode == _Mode.closed || _measureQueued) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (!mounted || _mode == _Mode.closed) return;
      final box = context.findRenderObject();
      final vp = Scrollable.maybeOf(context)?.context.findRenderObject();
      if (box is! RenderBox || vp is! RenderBox || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero, ancestor: vp).dy;
      final h = box.size.height;
      final visible = (math.min(top + h, vp.size.height) - math.max(top, 0.0)).clamp(0.0, h);
      if (visible < h / 2) _close();
    });
  }

  // ---------------------------------------------------------------- 체크
  void _onCheck() {
    if (_commit?.isActive ?? false) {
      _commit!.cancel();
      _commit = null;
      setState(() => _pendingDone = null);
      return;
    }
    setState(() => _pendingDone = !widget.task.done);
    _commit = Timer(_commitDelay, () {
      _commit = null;
      widget.onToggle();
    });
  }

  // ---------------------------------------------------------------- 위치 계산
  /// 손가락 이동량 → 보이는 폭 (버튼 폭까지 72%, 그 뒤 고무줄)
  static double _shape(double raw, double limit) {
    final v = raw * _follow;
    if (v <= limit) return v;
    final over = v - limit;
    const d = 110.0;
    return limit + (1 - 1 / (over * 0.55 / d + 1)) * d * 0.6;
  }

  static double _unshape(double shown, double limit) =>
      math.min(shown, limit) / _follow;

  // ---------------------------------------------------------------- 열기·닫기
  void _springTo(double target, _Mode mode, [double velocity = 0]) {
    setState(() {
      _mode = mode;
      _nearFull = false;
    });
    _ctrl.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 520, damping: 34),
        _x,
        target,
        velocity,
      ),
    );
  }

  void _close() {
    if (_mode == _Mode.closed && _x == 0) return;
    _springTo(0, _Mode.closed);
  }

  void _cancel() {
    _cancelled = true;
    HapticFeedback.selectionClick();
    _close();
  }

  Future<void> _deleteNow() async {
    if (_flyingOut) return;
    _flyingOut = true;
    HapticFeedback.heavyImpact();
    final w = context.size?.width ?? 400;
    _ctrl.stop();
    await _ctrl.animateTo(
      w + 24,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInCubic,
    );
    if (mounted) widget.onDelete();
  }

  // ---------------------------------------------------------------- 카드 드래그
  void _onCardStart(DragStartDetails d) {
    if (_flyingOut) return;
    _ctrl.stop();
    _start = d.globalPosition;
    _cancelled = false;
    if (_mode == _Mode.dial || _mode == _Mode.tag) setState(() => _mode = _Mode.open);
    _raw = _x >= 0 ? _unshape(_x, _delW) : -_unshape(-_x, _actW);
    _hint = _x.abs() > 1;
  }

  void _onCardUpdate(DragUpdateDetails d) {
    if (_flyingOut || _cancelled) return;
    if ((d.globalPosition.dy - _start.dy).abs() > _cancelDy) {
      _cancel();
      return;
    }
    _raw += d.delta.dx;
    if (_raw >= 0) {
      if (_raw >= _fullDelete) {
        _deleteNow();
        return;
      }
      final near = _raw >= _fullDelete * 0.75;
      if (near != _nearFull) {
        setState(() => _nearFull = near);
        if (near) HapticFeedback.mediumImpact();
      }
      _ctrl.value = _shape(_raw, _delW);
    } else {
      _ctrl.value = -_shape(-_raw, _actW);
    }
    final hint = _x.abs() > (_x > 0 ? _delW : _actW) * 0.4;
    if (hint != _hint) {
      _hint = hint;
      HapticFeedback.selectionClick();
    }
  }

  void _onCardEnd(DragEndDetails d) {
    if (_flyingOut || _cancelled) return;
    final v = d.primaryVelocity ?? 0;
    if (_x > 0) {
      final open = v > 500 || (_x > _delW * 0.4 && v >= -500);
      if (open && _mode != _Mode.delete) HapticFeedback.lightImpact();
      _springTo(open ? _delW : 0, open ? _Mode.delete : _Mode.closed, v);
    } else if (_x < 0) {
      final open = v < -500 || (-_x > _actW * 0.4 && v <= 500);
      if (open && _mode != _Mode.open) HapticFeedback.lightImpact();
      _springTo(open ? -_actW : 0, open ? _Mode.open : _Mode.closed, v);
    } else {
      _springTo(0, _Mode.closed);
    }
  }

  // ---------------------------------------------------------------- 액션 영역 (날짜·태그)
  void _enter(_Mode m) {
    HapticFeedback.mediumImpact();
    setState(() {
      _mode = m;
      _acc = 0;
      _step = _baseStep = 0;
      _tagIdx = _baseTagIdx = 0;
    });
  }

  void _onActionTap(TapUpDetails d, double w) {
    switch (_mode) {
      case _Mode.open:
        _enter(d.localPosition.dx < w / 2 ? _Mode.dial : _Mode.tag);
      case _Mode.dial:
      case _Mode.tag:
        _apply();
      case _Mode.closed:
      case _Mode.delete:
        break;
    }
  }

  void _onActionStart(DragStartDetails d, double w) {
    _ctrl.stop();
    _start = d.globalPosition;
    _cancelled = false;
    if (_mode == _Mode.open) {
      _enter(d.localPosition.dx < w / 2 ? _Mode.dial : _Mode.tag);
    }
    _acc = 0;
    _baseStep = _step;
    _baseTagIdx = _tagIdx;
  }

  void _onActionUpdate(DragUpdateDetails d) {
    if (_cancelled) return;
    if ((d.globalPosition.dy - _start.dy).abs() > _cancelDy) {
      _cancel();
      return;
    }
    _acc += d.delta.dx;
    if (_mode == _Mode.dial) {
      final s = (_baseStep + (-_acc / _dialPx).truncate()).clamp(0, _maxStep);
      if (s != _step) {
        HapticFeedback.selectionClick();
        setState(() => _step = s);
      }
    } else if (_mode == _Mode.tag) {
      final last = widget.tagOrder.length + 1; // 0 그대로, 1..n 태그, n+1 없음
      final i = (_baseTagIdx + (-_acc / _tagPx).truncate()).clamp(0, last);
      if (i != _tagIdx) {
        HapticFeedback.selectionClick();
        setState(() => _tagIdx = i);
      }
    }
  }

  void _onActionEnd(DragEndDetails d) {
    if (_cancelled) return;
    if (_mode == _Mode.dial || _mode == _Mode.tag) _apply();
  }

  void _apply() {
    if (_mode == _Mode.dial && _step > 0) {
      HapticFeedback.mediumImpact();
      widget.onDial(addDays(_base, _step));
    } else if (_mode == _Mode.tag && _tagIdx > 0) {
      HapticFeedback.mediumImpact();
      final order = widget.tagOrder;
      widget.onTag(_tagIdx <= order.length ? order[_tagIdx - 1] : null);
    }
    _springTo(0, _Mode.closed);
  }

  // ---------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (_mode != _Mode.closed) _close();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: LayoutBuilder(builder: (context, box) => _layout(box.maxWidth)),
      ),
    );
  }

  Widget _layout(double w) {
    final left = math.max(0.0, _x);
    final right = math.max(0.0, -_x);
    final gl = left > 0 ? 8 * math.min(1.0, left / 30) : 0.0;
    final gr = right > 0 ? 8 * math.min(1.0, right / 30) : 0.0;
    final cardW = math.max(_minCard, w - left - gl - right - gr);
    final id = widget.task.id;

    return SizedBox(
      width: w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (left > 0.5)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: left,
              child: GestureDetector(
                key: ValueKey('del-$id'),
                behavior: HitTestBehavior.opaque,
                onTap: _deleteNow,
                child: _DeleteArea(
                  t: (left / _delW).clamp(0.0, 1.0),
                  hot: _nearFull || _flyingOut,
                ),
              ),
            ),
          if (right > 0.5)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: right,
              child: LayoutBuilder(
                builder: (context, b) => GestureDetector(
                  key: ValueKey('act-$id'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onActionTap(d, b.maxWidth),
                  onHorizontalDragStart: (d) => _onActionStart(d, b.maxWidth),
                  onHorizontalDragUpdate: _onActionUpdate,
                  onHorizontalDragEnd: _onActionEnd,
                  child: _actions(right),
                ),
              ),
            ),
          // 카드: 열리는 만큼 줄어듦 (삭제 때는 오른쪽으로 밀려남)
          Transform.translate(
            offset: Offset(left + gl, 0),
            child: SizedBox(
              width: cardW,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onCardStart,
                onHorizontalDragUpdate: _onCardUpdate,
                onHorizontalDragEnd: _onCardEnd,
                onHorizontalDragCancel: () {
                  if (!_flyingOut) _springTo(0, _Mode.closed);
                },
                child: _card(widget.task),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(double reveal) {
    final t = (reveal / _actW).clamp(0.0, 1.0);
    final Widget child = switch (_mode) {
      _Mode.dial => _DialPanel(
          key: const ValueKey('dial'),
          step: _step,
          date: _step == 0 ? widget.task.due : addDays(_base, _step),
        ),
      _Mode.tag => _TagPanel(
          key: const ValueKey('tag'),
          order: widget.tagOrder,
          index: _tagIdx,
          current: widget.task.tags,
        ),
      _ => Row(
          key: const ValueKey('buttons'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ActionButton(
                t: Curves.easeOutBack.transform(((t - 0.05) / 0.8).clamp(0.0, 1.0)),
                icon: CupertinoIcons.calendar_badge_plus,
                label: '날짜',
                colors: const [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionButton(
                t: Curves.easeOutBack.transform(((t - 0.2) / 0.8).clamp(0.0, 1.0)),
                icon: CupertinoIcons.tag_fill,
                label: '태그',
                colors: const [Color(0xFFFF9F0A), Color(0xFFFF375F)],
              ),
            ),
          ],
        ),
    };
    return AnimatedSwitcher(
      duration: Motion.med,
      switchInCurve: Curves.easeOutBack,
      // 패널이 두 버튼을 합친 영역을 꽉 채우도록
      layoutBuilder: (cur, prev) => Stack(
        fit: StackFit.expand,
        children: [...prev, ?cur],
      ),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(a), child: c),
      ),
      child: child,
    );
  }

  Widget _card(Task t) {
    final done = _done;
    final st = widget.status;
    return Pressable(
      scale: 0.975,
      haptic: false,
      onTap: () => _mode == _Mode.closed ? widget.onTap() : _close(),
      child: AnimatedContainer(
        duration: Motion.med,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
        decoration: BoxDecoration(
          color: K.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: done ? const [] : K.shadow,
          border: done ? Border.all(color: K.gray5) : null,
        ),
        child: Row(
          children: [
            SquareCheck(
              key: ValueKey('check-${t.id}'),
              value: done,
              onTap: _onCheck,
              colors: t.tags.isEmpty
                  ? const [Color(0xFF0A84FF), Color(0xFF5E5CE6), Color(0xFFBF5AF2)]
                  : t.tags.first.colors,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StrikeText(t.title, struck: done, style: T.headline, maxLines: 1),
                  if (t.due != null ||
                      t.tags.isNotEmpty ||
                      st == TaskStatus.late ||
                      st == TaskStatus.overdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (st == TaskStatus.overdue && !done)
                            const StatusPill('지연', colors: [Color(0xFFFF453A), Color(0xFFFF2D55)]),
                          if (st == TaskStatus.late)
                            const StatusPill('늦은 완료', colors: [Color(0xFFFF9F0A), Color(0xFFFF6B3D)]),
                          if (t.due != null) _DuePill(due: t.due!, done: done),
                          for (final g in t.tags) TagPill(tag: g, muted: done),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 액션 구성 요소

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.t,
    required this.icon,
    required this.label,
    required this.colors,
  });

  final double t;
  final IconData icon;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.5 + 0.5 * t,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(height: 3),
                  Text(label, style: T.caption.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 단계 점 표시 (선택 위치가 길쭉해짐)
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, this.fillBefore = false});

  final int count;
  final int index;
  final bool fillBefore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: i == index ? 12 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: i == index || (fillBefore && i < index) ? 1 : 0.35,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _DialPanel extends StatelessWidget {
  const _DialPanel({super.key, required this.step, required this.date});

  final int step;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final keep = step == 0;
    return AnimatedContainer(
      duration: Motion.med,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: keep
            ? const LinearGradient(colors: [Color(0xFF8E8E93), Color(0xFF636366)])
            : K.brand,
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dots(count: 8, index: step, fillBefore: true),
              const SizedBox(height: 3),
              RollingText(
                keep ? '그대로' : '+$step',
                style: const TextStyle(
                  fontFamily: K.font,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              Text(
                date == null ? '날짜 없음' : mdw(date!),
                style: T.caption.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagPanel extends StatelessWidget {
  const _TagPanel({
    super.key,
    required this.order,
    required this.index,
    required this.current,
  });

  final List<TaskTag> order;

  /// 0 그대로, 1..n 태그, n+1 없음
  final int index;
  final Set<TaskTag> current;

  @override
  Widget build(BuildContext context) {
    final n = order.length;
    final tag = index >= 1 && index <= n ? order[index - 1] : null;
    final String label;
    if (index == 0) {
      label = current.isEmpty ? '그대로' : '그대로 #${current.first.label}';
    } else {
      label = tag == null ? '없음' : '#${tag.label}';
    }
    return AnimatedContainer(
      duration: Motion.med,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: tag?.gradient ??
            const LinearGradient(colors: [Color(0xFF8E8E93), Color(0xFF636366)]),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dots(count: n + 2, index: index),
              const SizedBox(height: 5),
              RollingText(
                label,
                style: T.headline.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 오른쪽 끌기: 삭제 버튼 (더 끌면 붉게 커지며 바로 삭제)
class _DeleteArea extends StatelessWidget {
  const _DeleteArea({required this.t, required this.hot});

  final double t;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final e = Curves.easeOutBack.transform(t);
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: K.danger,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedScale(
              scale: hot ? 1.25 : 0.6 + 0.4 * e,
              duration: Motion.fast,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 22),
                  const SizedBox(height: 3),
                  Text('삭제', style: T.caption.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 표시 요소

class _DuePill extends StatelessWidget {
  const _DuePill({required this.due, required this.done});

  final DateTime due;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final n = dayDiff(DateTime.now(), due);
    final List<Color> colors = done
        ? const [K.gray3, K.gray3]
        : n < 0
            ? const [Color(0xFFFF453A), Color(0xFFFF2D55)]
            : n == 0
                ? const [Color(0xFF0A84FF), Color(0xFF5E5CE6)]
                : const [Color(0xFF8E8E93), Color(0xFF8E8E93)];
    final filled = !done && n == 0;
    return AnimatedContainer(
      duration: Motion.med,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: filled ? LinearGradient(colors: colors) : null,
        color: filled ? null : K.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.calendar, size: 12, color: filled ? Colors.white : colors.first),
          const SizedBox(width: 3),
          Text(
            dueLabel(due),
            style: T.caption.copyWith(color: filled ? Colors.white : colors.first),
          ),
        ],
      ),
    );
  }
}

/// 상태 표시 (지연 / 늦은 완료)
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.colors});

  final String text;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: T.caption.copyWith(color: Colors.white)),
    );
  }
}

/// 태그 칩 (그라데이션 글자 + 옅은 그라데이션 배경)
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.tag, this.muted = false});

  final TaskTag tag;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Motion.med,
      opacity: muted ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [for (final c in tag.colors) c.withValues(alpha: 0.13)],
          ),
        ),
        child: GradientText('#${tag.label}', style: T.caption, gradient: tag.gradient),
      ),
    );
  }
}

