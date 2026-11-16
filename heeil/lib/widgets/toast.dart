import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass_tab_bar.dart';

/// 하단 토스트
/// - [life] 동안만 보이고 사라짐 (기본 0.6초)
/// - 토스트 바깥을 누르거나 끄는 등 다른 동작을 하면 즉시 사라짐
/// - 새 토스트가 뜨면 이전 것은 바로 교체
abstract final class Toast {
  static OverlayEntry? _entry;
  static GlobalKey<_ToastViewState>? _view;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String text, {
    required IconData icon,
    List<Color> colors = const [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
    VoidCallback? undo,
    Duration life = const Duration(milliseconds: 600),
  }) {
    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    dismiss(immediate: true);

    final mq = MediaQuery.of(context);
    final base = mq.viewInsets.bottom > 0
        ? mq.viewInsets.bottom
        : mq.viewPadding.bottom + GlassTabBar.height;
    final key = GlobalKey<_ToastViewState>();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 16,
        right: 16,
        bottom: base + 74,
        child: _ToastView(
          key: key,
          text: text,
          icon: icon,
          colors: colors,
          onUndo: undo == null
              ? null
              : () {
                  undo();
                  dismiss(immediate: true);
                },
          onOutside: dismiss,
        ),
      ),
    );
    overlay.insert(entry);
    _entry = entry;
    _view = key;
    _timer = Timer(life, dismiss);
  }

  static void dismiss({bool immediate = false}) {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    final view = _view?.currentState;
    _entry = null;
    _view = null;
    if (entry == null) return;
    void remove() {
      if (entry.mounted) entry.remove();
    }

    if (immediate || view == null) {
      remove();
    } else {
      view.hide().whenComplete(remove);
    }
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.text,
    required this.icon,
    required this.colors,
    required this.onUndo,
    required this.onOutside,
  });

  final String text;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onUndo;
  final VoidCallback onOutside;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 140),
  )..forward();

  Future<void> hide() => _c.reverse();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return TapRegion(
      onTapOutside: (_) => widget.onOutside(),
      child: FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(a),
            child: Material(
              color: const Color(0xF01C1C1E),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) =>
                          LinearGradient(colors: widget.colors).createShader(Offset.zero & r.size),
                      child: Icon(widget.icon, size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: T.subhead.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (widget.onUndo != null)
                      TextButton(
                        onPressed: widget.onUndo,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64D2FF),
                          minimumSize: const Size(56, 40),
                        ),
                        child: Text(
                          '취소',
                          style: T.subhead.copyWith(
                            color: const Color(0xFF64D2FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
