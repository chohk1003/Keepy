import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 되돌리기 알림의 내용.
@immutable
class ToastMessage {
  const ToastMessage(this.text, {this.actionLabel, this.onAction, this.id = 0});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int id;
}

/// 직접 만든 되돌리기 알림 (prompts_log #9).
///
/// 최신 Flutter 의 SnackBar 는 '취소' 같은 동작 버튼이 있으면 저절로 닫히지
/// 않아 화면에 남는 문제가 있었다. 그래서 직접 만들었다.
/// - 0.6초만 떠 있다 (연속 조작을 막지 않도록).
/// - 알림 밖 아무 곳이나 누르면 즉시 사라진다.
class ToastController extends ChangeNotifier {
  ToastController({this.visibleFor = const Duration(milliseconds: 600)});

  final Duration visibleFor;
  ToastMessage? _current;
  Timer? _timer;
  int _seq = 0;

  /// 알림 안을 누른 포인터인지 표시 (바깥 누름 판정용).
  bool pointerInsideToast = false;

  ToastMessage? get current => _current;

  void show(String text, {String? actionLabel, VoidCallback? onAction}) {
    _timer?.cancel();
    _current = ToastMessage(text, actionLabel: actionLabel, onAction: onAction, id: ++_seq);
    notifyListeners();
    _timer = Timer(visibleFor, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  void runAction() {
    final action = _current?.onAction;
    dismiss();
    action?.call();
  }

  /// 화면 어디든 손가락이 닿으면 셸이 부른다.
  void handleGlobalPointerDown() {
    if (pointerInsideToast) {
      pointerInsideToast = false;
      return;
    }
    if (_current != null) dismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class UndoToastView extends StatelessWidget {
  const UndoToastView({super.key, required this.controller});
  final ToastController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final msg = controller.current;
        return AnimatedSwitcher(
          duration: KeepyMotion.fast,
          switchInCurve: KeepyMotion.settle,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: msg == null
              ? const SizedBox.shrink(key: ValueKey<int>(-1))
              : Listener(
                  key: ValueKey<int>(msg.id),
                  onPointerDown: (_) => controller.pointerInsideToast = true,
                  child: _ToastBody(message: msg, onAction: controller.runAction),
                ),
        );
      },
    );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.message, required this.onAction});
  final ToastMessage message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.only(left: 16, right: 6),
          color: const Color(0xE61C1C1E),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  message.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              if (message.actionLabel != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text(
                      message.actionLabel!,
                      style: const TextStyle(color: Color(0xFF8FB0FF), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                const SizedBox(width: 10, height: 44),
            ],
          ),
        ),
      ),
    );
  }
}
