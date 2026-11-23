import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../pages/companion_room.dart';
import 'companion_art.dart';

/// Only this region owns the room gesture; task cancellation and list scrolling
/// keep their existing recognizers. The work page stays mounted below the route.
class CompanionHeader extends StatefulWidget {
  const CompanionHeader({super.key});
  @override
  State<CompanionHeader> createState() => _CompanionHeaderState();
}

class _CompanionHeaderState extends State<CompanionHeader>
    with SingleTickerProviderStateMixin {
  double _pull = 0;
  bool _opening = false;
  bool _canPull = false;
  int? _lastPending;
  late final AnimationController _reaction = AnimationController(
    vsync: this,
    duration: Motion.celebration,
  );
  @override
  void dispose() {
    _reaction.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    setState(() => _pull = 0);
    final state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    final box = context.findRenderObject();
    // 레이아웃 전이면 화면 위 가장자리(높이 0)에서 펼친다.
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : Offset.zero & Size(MediaQuery.sizeOf(context).width, 0);
    await openCompanionRoom(context, state, origin: origin);
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pending = state.pendingCredits.length;
    if (_lastPending != null &&
        pending > _lastPending! &&
        !MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reaction.forward(from: 0);
      });
    }
    _lastPending = pending;
    return Semantics(
      label: '캐릭터 방 열기',
      button: true,
      onTap: _open,
      child: GestureDetector(
        key: const Key('companion-header'),
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        onVerticalDragDown: (_) {
          final position = Scrollable.maybeOf(context)?.position;
          _canPull =
              position == null ||
              (!position.isScrollingNotifier.value &&
                  position.pixels <= position.minScrollExtent + .5);
        },
        onVerticalDragUpdate: (d) => setState(
          () => _pull = _canPull ? (_pull + d.delta.dy).clamp(0, 110) : 0,
        ),
        onVerticalDragEnd: (d) {
          if (_canPull && _pull >= 72) {
            _open();
          } else {
            setState(() => _pull = 0);
          }
        },
        onVerticalDragCancel: () => setState(() => _pull = 0),
        child: Container(
          height: 188 + MediaQuery.paddingOf(context).top + _pull * .2,
          color: K.room,
          child: Stack(
            children: [
              Positioned(
                top: MediaQuery.paddingOf(context).top + 14,
                left: 22,
                child: Text('Keepy', style: T.title3.copyWith(color: K.blue)),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                right: 8,
                child: IconButton(
                  key: const Key('room-open'),
                  tooltip: '캐릭터 방 열기',
                  onPressed: _open,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(
                    CupertinoIcons.chevron_down,
                    size: 24,
                    color: K.ink,
                  ),
                ),
              ),
              Positioned(
                left: 42,
                right: 42,
                top: MediaQuery.paddingOf(context).top + 32,
                bottom: 20,
                child: Transform.translate(
                  offset: Offset(0, _pull * .16),
                  child: AnimatedBuilder(
                    animation: _reaction,
                    builder: (_, _) => Hero(
                      tag: 'keepy-companion',
                      child: CompanionArt(
                        kind: state.companion,
                        faceOnly: true,
                        joy: _reaction.isAnimating ? 1 - _reaction.value : 0,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 28,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 7,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Motion.med,
                    child: CrumbPile(key: ValueKey(pending), count: pending),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
