import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// 항목이 추가·삭제·이동될 때 자동으로 애니메이션하는 슬리버 목록
/// - 추가: 위에서 내려오며 펼쳐짐
/// - 삭제/다른 목록으로 이동: 접히며 사라짐
class DiffSliverList<E> extends StatefulWidget {
  const DiffSliverList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
  });

  final List<E> items;
  final String Function(E) idOf;
  final Widget Function(BuildContext context, E item) itemBuilder;

  @override
  State<DiffSliverList<E>> createState() => _DiffSliverListState<E>();
}

class _DiffSliverListState<E> extends State<DiffSliverList<E>> {
  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey<SliverAnimatedListState>();
  late List<E> _items = List.of(widget.items);

  @override
  void didUpdateWidget(covariant DiffSliverList<E> old) {
    super.didUpdateWidget(old);
    final next = widget.items;
    final idOf = widget.idOf;
    final list = _listKey.currentState;
    if (list == null) {
      _items = List.of(next);
      return;
    }

    final nextIds = next.map(idOf).toSet();
    final prevIds = _items.map(idOf).toSet();

    // 남는 항목의 상대 순서가 바뀌었으면 애니메이션 없이 새로 그림
    final keptPrev = [for (final e in _items) if (nextIds.contains(idOf(e))) idOf(e)];
    final keptNext = [for (final e in next) if (prevIds.contains(idOf(e))) idOf(e)];
    if (!listEquals(keptPrev, keptNext)) {
      _items = List.of(next);
      _listKey = GlobalKey<SliverAnimatedListState>();
      return;
    }

    // 1) 삭제 (뒤에서부터)
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      if (nextIds.contains(idOf(item))) continue;
      _items.removeAt(i);
      list.removeItem(
        i,
        (context, a) => _Removing(
          animation: a,
          child: widget.itemBuilder(context, item),
        ),
        duration: Motion.med,
      );
    }

    // 2) 추가 (앞에서부터)
    for (var i = 0; i < next.length; i++) {
      final id = idOf(next[i]);
      if (prevIds.contains(id)) continue;
      _items.insert(i, next[i]);
      list.insertItem(i, duration: Motion.slow);
    }

    // 3) 최신 객체로 교체 (id·순서 동일)
    _items = List.of(next);
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      itemBuilder: (context, i, a) {
        if (i >= _items.length) return const SizedBox.shrink();
        final item = _items[i];
        return _Inserting(
          key: ValueKey(widget.idOf(item)),
          animation: a,
          child: widget.itemBuilder(context, item),
        );
      },
    );
  }
}

class _Inserting extends StatelessWidget {
  const _Inserting({super.key, required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Motion.out);
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Motion.spring)),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1)
                .animate(CurvedAnimation(parent: animation, curve: Motion.spring)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Removing extends StatelessWidget {
  const _Removing({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
    return IgnorePointer(
      child: SizeTransition(
        sizeFactor: curved,
        alignment: Alignment.center,
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: child,
          ),
        ),
      ),
    );
  }
}
