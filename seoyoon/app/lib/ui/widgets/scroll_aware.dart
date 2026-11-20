import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 리스트 안에서 이 위젯이 뷰포트의 어디에 있는지 계산하는 도우미.
mixin ScrollAwareState<T extends StatefulWidget> on State<T> {
  ScrollPosition? _scrollPosition;

  /// 스크롤될 때마다 불린다.
  void onScrollChanged();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _scrollPosition) {
      _scrollPosition?.removeListener(_handleScroll);
      _scrollPosition = pos;
      _scrollPosition?.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (mounted) onScrollChanged();
  }

  /// (뷰포트 기준 위쪽 y, 내 높이, 뷰포트 높이). 계산할 수 없으면 null.
  (double top, double height, double viewport)? viewportGeometry() {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final vp = scrollable?.context.findRenderObject();
    if (box is! RenderBox || vp is! RenderBox) return null;
    if (!box.attached || !vp.attached || !box.hasSize || !vp.hasSize) return null;
    final top = box.localToGlobal(Offset.zero, ancestor: vp).dy;
    return (top, box.size.height, vp.size.height);
  }
}

/// 하단 탭 전환 영역 (prompts_log #12).
///
/// 입력 바 위로 할 일 블럭 하나 높이만큼은 리스트 항목이 작아지며 흐려져
/// 사라진다. 이 영역의 항목은 터치를 받지 않으므로, 여기서 좌우로 밀면
/// 리스트가 아닌 페이지가 넘어간다 (탭 전환).
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child, this.zone = 72});

  final Widget child;

  /// 사라지는 영역 높이 (할 일 블럭 1개 정도).
  final double zone;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> with ScrollAwareState<EdgeFade> {
  double _t = 0;

  @override
  void onScrollChanged() => _recompute();

  void _recompute() {
    final g = viewportGeometry();
    if (g == null) return;
    final (top, height, viewport) = g;
    final center = top + height / 2;
    final zoneTop = viewport - widget.zone;
    final t = ((center - zoneTop) / widget.zone).clamp(0.0, 1.0);
    if ((t - _t).abs() > 0.01 || (t == 0 && _t != 0) || (t == 1 && _t != 1)) {
      setState(() => _t = t);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 배치가 끝난 뒤 위치를 다시 잰다 (항목 추가·삭제, 키보드 등장 등).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recompute();
    });

    // 구조를 항상 같게 유지해야 안쪽 할 일 블럭의 상태(스와이프 등)가 보존된다.
    final t = _t;
    final child = Opacity(
      opacity: (1 - t * 1.1).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 1 - 0.14 * t,
        alignment: Alignment.topCenter,
        child: ImageFiltered(
          // 웹에서는 개별 blur 가 무거워 투명도·크기만 쓴다
          enabled: !kIsWeb && t > 0.001,
          imageFilter: ImageFilter.blur(sigmaX: 4 * t + 0.001, sigmaY: 4 * t + 0.001),
          child: widget.child,
        ),
      ),
    );
    return IgnorePointer(ignoring: t > 0.35, child: child);
  }
}
