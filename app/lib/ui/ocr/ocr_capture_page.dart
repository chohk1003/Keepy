import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_cleanup.dart';
import '../../services/ocr_service.dart';
import '../widgets/basics.dart';

/// 촬영 흐름 (UI 설계서 09 / FR-13 / NFR-02, NFR-05, NFR-07).
///
/// "프레임 안에 맞춰 주세요" 안내 → 셔터 → 기기 안에서 글자 인식 →
/// 원본 이미지 즉시 삭제 → 줄 단위 후보를 돌려준다(검토 화면 08).
class OcrCapturePage extends StatefulWidget {
  const OcrCapturePage({super.key, required this.ocr, this.picker});

  final OcrService ocr;
  final ImagePicker? picker;

  /// 후보 목록을 돌려준다. 취소하면 null.
  static Future<List<String>?> open(BuildContext context, OcrService ocr) {
    return Navigator.of(context).push<List<String>>(
      PageRouteBuilder<List<String>>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => OcrCapturePage(ocr: ocr),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  State<OcrCapturePage> createState() => _OcrCapturePageState();
}

class _OcrCapturePageState extends State<OcrCapturePage> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  bool _busy = false;

  Future<void> _capture(ImageSource source) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    if (!widget.ocr.isSupported) {
      await _pasteFallback();
      return;
    }
    setState(() => _busy = true);
    String? path;
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 90);
      if (file == null) return;
      path = file.path;
      final lines = await widget.ocr.recognizeLines(file.path);
      if (!mounted) return;
      if (lines.isEmpty) {
        _showMessage('글자를 찾지 못했어요', '메모가 프레임 안에 잘 보이도록 다시 찍어 주세요.');
        return;
      }
      Navigator.pop(context, lines);
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code.contains('access_denied') || e.code.contains('permission')) {
        _showMessage(
          '카메라 권한이 필요해요',
          '설정 > Keepy 에서 카메라(사진) 접근을 허용하면 종이 메모를 찍어 할 일로 바꿀 수 있어요.',
        );
      } else {
        _showMessage('촬영하지 못했어요', e.message ?? e.code);
      }
    } catch (e) {
      if (mounted) _showMessage('인식하지 못했어요', '$e');
    } finally {
      // NFR-05: 원본 메모 이미지는 인식 직후 영구 삭제
      if (path != null) await deleteCapturedImage(path);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 웹·데스크톱 등 OCR 미지원 환경: 메모 내용을 붙여넣어 같은 검토 흐름을 쓴다.
  Future<void> _pasteFallback() async {
    final controller = TextEditingController();
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('메모 내용 붙여넣기'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('이 기기에서는 글자 인식을 쓸 수 없어요.\n한 줄에 하나씩 적으면 할 일 후보로 나눠 드려요.'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                minLines: 4,
                maxLines: 6,
                placeholder: '- 자료구조 과제\n- 팀 회의 준비',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('나누기'),
          ),
        ],
      ),
    );
    // 대화상자가 닫히는 애니메이션 동안 controller 를 쓰므로 여기서 dispose 하지 않는다.
    if (!mounted || result == null) return;
    final lines = splitCandidates(result);
    if (lines.isEmpty) return;
    Navigator.pop(context, lines);
  }

  void _showMessage(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1F26),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('ocr-close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: _GuideFrame(busy: _busy),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _SideButton(
                      icon: CupertinoIcons.photo,
                      label: '앨범',
                      onTap: () => _capture(ImageSource.gallery),
                    ),
                    PressScale(
                      onTap: () => _capture(ImageSource.camera),
                      scale: 0.9,
                      child: Container(
                        key: const Key('shutter'),
                        width: 74,
                        height: 74,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        ),
                      ),
                    ),
                    _SideButton(
                      icon: CupertinoIcons.doc_on_clipboard,
                      label: '붙여넣기',
                      onTap: _pasteFallback,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideFrame extends StatelessWidget {
  const _GuideFrame({required this.busy});
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Stack(
        children: <Widget>[
          // 모서리 강조
          for (final a in <Alignment>[Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
            Align(
              alignment: a,
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border(
                    top: a.y < 0 ? const BorderSide(color: Color(0xFF8FB0FF), width: 3) : BorderSide.none,
                    bottom: a.y > 0 ? const BorderSide(color: Color(0xFF8FB0FF), width: 3) : BorderSide.none,
                    left: a.x < 0 ? const BorderSide(color: Color(0xFF8FB0FF), width: 3) : BorderSide.none,
                    right: a.x > 0 ? const BorderSide(color: Color(0xFF8FB0FF), width: 3) : BorderSide.none,
                  ),
                ),
              ),
            ),
          Center(
            child: busy
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CupertinoActivityIndicator(color: Colors.white, radius: 14),
                      SizedBox(height: 12),
                      Text('기기 안에서 글자를 읽는 중…', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        '프레임 안에 맞춰 주세요',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '한 줄이 할 일 하나가 돼요\n사진은 인식 후 바로 지워져요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}
