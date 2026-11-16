import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/diff_sliver_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/fx.dart';
import '../widgets/quick_input_bar.dart';
import '../widgets/task_actions.dart';
import '../widgets/week_calendar.dart';

/// 날짜 화면 (UI설계서 03, CST-01: 상단 1/4 캘린더 고정, 하단 3/4 목록)
/// - 캘린더에서 직접 고른 날은 비어 있어도 그 날짜로 바로 추가 가능
/// - 목록 끝에서 더 세게 끌면 날짜 제목이 손가락을 따라 다음·이전 날로 넘어가고,
///   임계값을 넘긴 채 놓으면 '할 일이 있는' 그날로 이동
/// - 오른쪽 아래 [오늘] 버튼으로 바로 복귀
class DatePage extends StatefulWidget {
  const DatePage({super.key});

  @override
  State<DatePage> createState() => _DatePageState();
}

class _DatePageState extends State<DatePage> with SingleTickerProviderStateMixin {
  /// 목록 끝을 넘어 끌린 거리가 이 값을 넘어야 이동
  static const _threshold = 72.0;

  bool _pointerDown = false;

  bool _armed = false;

  /// 제목 전환: 지금 보이는 날 → [_peekDay], 진행도 0~1
  DateTime? _titleDay;
  DateTime? _peekDay;
  int _peekDir = 1;
  double _peek = 0;

  /// 목록 전환 방향
  int _dir = 1;

  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() => setState(() => _peek = _t.value));

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// 제목을 [to]로 마저 넘기고, 끝나면 [then] 실행
  void _finishTitle(DateTime to, int dir, {VoidCallback? then}) {
    _peekDay = to;
    _peekDir = dir;
    _t.value = _peek;
    _t.animateTo(1, curve: Curves.easeOutCubic).whenComplete(() {
      if (!mounted) return;
      then?.call();
      setState(() {
        _titleDay = to;
        _peekDay = null;
        _peek = 0;
      });
    });
  }

  bool _onScroll(ScrollNotification n, AppState s) {
    if (n.depth != 0 || !_pointerDown || _t.isAnimating) return false;
    final m = n.metrics;
    var over = 0.0;
    if (m.pixels > m.maxScrollExtent) {
      over = m.pixels - m.maxScrollExtent;
    } else if (m.pixels < m.minScrollExtent) {
      over = m.pixels - m.minScrollExtent;
    }
    final dir = over > 0 ? 1 : -1;
    final target = over == 0 ? null : s.neighborTaskDay(s.selectedDay, dir);
    final armed = target != null && over.abs() >= _threshold;
    if (armed != _armed) {
      armed ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
    setState(() {
      _armed = armed;
      _peekDay = target;
      _peekDir = dir;
      // 손가락을 따라 제목이 넘어감 (놓기 전에는 85%까지만)
      _peek = target == null ? 0 : (over.abs() / _threshold).clamp(0.0, 1.0) * 0.85;
    });
    return false;
  }

  void _onRelease(AppState s) {
    if (!_pointerDown) return;
    _pointerDown = false;
    final target = _peekDay;
    if (_armed && target != null) {
      HapticFeedback.lightImpact();
      _dir = _peekDir;
      _finishTitle(target, _peekDir, then: () => s.selectDay(target));
    } else if (_peek > 0) {
      // 임계값 전이면 되돌아감
      _t.value = _peek;
      _t.animateTo(0, curve: Curves.easeOutCubic).whenComplete(() {
        if (mounted) setState(() => _peekDay = null);
      });
    }
    _armed = false;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final day = s.selectedDay;
    final today = dayOf(DateTime.now());

    // 캘린더 탭·오늘 버튼 등으로 날짜가 바뀐 경우에도 같은 전환 재생
    final shown = _titleDay ??= day;
    if (!sameDay(shown, day) && !_t.isAnimating && _peekDay == null) {
      _dir = day.isAfter(shown) ? 1 : -1;
      final dir = _dir;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finishTitle(day, dir);
      });
    }

    final list = s.onDay(day);
    final pending = list.where((t) => !t.done).toList();
    final done = list.where((t) => t.done).toList();
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom;
    const zoneTop = EdgeFade.zone - 8.0;

    return Stack(
      children: [
        Column(
          children: [
            // 뷰포트 높이의 1/4 고정 (키보드가 올라와도 유지)
            SizedBox(height: mq.size.height / 4, child: const WeekCalendar()),
            SizedBox(
              height: 52,
              child: ClipRect(
                child: _DayTitle(
                  day: shown,
                  peekDay: _peekDay,
                  dir: _peekDir,
                  progress: _peek,
                  armed: _armed,
                ),
              ),
            ),
            Expanded(
              // 목록은 입력 바 위에서 끝남 (입력 바 아래로 비치지 않게)
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom + QuickInputBar.height),
                child: Listener(
                onPointerDown: (_) => _pointerDown = true,
                onPointerUp: (_) => _onRelease(s),
                onPointerCancel: (_) => _onRelease(s),
                onPointerPanZoomStart: (_) => _pointerDown = true,
                onPointerPanZoomEnd: (_) => _onRelease(s),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) => _onScroll(n, s),
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: Motion.slow,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (c, a) {
                        final incoming = c.key == ValueKey(day);
                        return FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, (incoming ? 0.3 : -0.3) * _dir),
                              end: Offset.zero,
                            ).animate(a),
                            child: c,
                          ),
                        );
                      },
                      child: CustomScrollView(
                        key: ValueKey(day),
                        slivers: [
                          SliverToBoxAdapter(child: SectionHeader('할 일', pending.length)),
                          DiffSliverList<Task>(
                            items: AppState.sortByDate(pending),
                            idOf: (t) => t.id,
                            itemBuilder: buildTaskTile,
                          ),
                          SliverToBoxAdapter(
                            child: SectionHeader('완료', done.length, gradient: K.success),
                          ),
                          DiffSliverList<Task>(
                            items: AppState.sortByDate(done),
                            idOf: (t) => t.id,
                            itemBuilder: buildTaskTile,
                          ),
                          if (list.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: zoneTop / 2),
                                child: const Center(child: EmptyState(title: '일정 없음')),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: EdgeFade.zone + 8)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
          ],
        ),
        // 오늘로 바로 가기 (우측 하단, 입력 바 위)
        Positioned(
          right: 16,
          bottom: bottom + QuickInputBar.height + 12,
          child: AnimatedScale(
            scale: sameDay(day, today) ? 0 : 1,
            duration: Motion.med,
            curve: sameDay(day, today) ? Curves.easeIn : Curves.easeOutBack,
            child: Pressable(
              onTap: () => s.selectDay(today),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
                decoration: BoxDecoration(
                  gradient: K.brand,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: K.glow(K.indigo, a: 0.35, blur: 14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.arrow_uturn_left, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('오늘', style: T.subhead.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: QuickInputBar(
            dueLabel: md(day),
            onSubmit: (title, tags) => s.add(title, due: day, tags: tags),
          ),
        ),
      ],
    );
  }
}

/// 날짜 제목 — 제스처 진행도에 맞춰 현재 날짜가 밀려나고 다음 날짜가 들어옴
class _DayTitle extends StatelessWidget {
  const _DayTitle({
    required this.day,
    required this.peekDay,
    required this.dir,
    required this.progress,
    required this.armed,
  });

  final DateTime day;
  final DateTime? peekDay;
  final int dir;
  final double progress;
  final bool armed;

  static const _travel = 34.0;

  @override
  Widget build(BuildContext context) {
    final p = peekDay == null ? 0.0 : progress;
    return Stack(
      children: [
        _line(day, -dir * p * _travel, 1 - p),
        if (peekDay != null) _line(peekDay!, dir * (1 - p) * _travel, p, highlight: armed),
      ],
    );
  }

  Widget _line(DateTime d, double dy, double opacity, {bool highlight = false}) {
    final isToday = sameDay(d, DateTime.now());
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Flexible(
                  child: highlight
                      ? GradientText(longKo(d), style: T.title2)
                      : Text(longKo(d), style: T.title2, overflow: TextOverflow.ellipsis),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: K.brand2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('오늘', style: T.caption.copyWith(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
