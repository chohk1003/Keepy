import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/fx.dart';
import '../widgets/square_check.dart';
import '../widgets/task_actions.dart';

/// 촬영 → 인식 → 검토 흐름 (UI설계서 08·09)
/// 실제 카메라·ML Kit OCR은 MP4에서 [recognizeLines]만 교체하면 된다.
/// 원본 이미지는 저장하지 않는다 (NFR-05).
Future<List<String>> recognizeLines() async {
  await Future<void>.delayed(const Duration(milliseconds: 900));
  return const [
    '운영체제 과제 제출',
    '장보기 우유 계란',
    '팀플 회의록 정리',
    '도서관 책 반납',
    '컴그 4장 복습',
  ];
}

void openCapture(BuildContext context) {
  FocusScope.of(context).unfocus();
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: Motion.slow,
      reverseTransitionDuration: Motion.med,
      pageBuilder: (_, _, _) => const CapturePage(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.06, end: 1).animate(
            CurvedAnimation(parent: a, curve: Motion.out),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with TickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  bool _busy = false;
  bool _pressed = false;

  @override
  void dispose() {
    _scan.dispose();
    _flash.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    if (_busy) return;
    HapticFeedback.heavyImpact();
    setState(() => _busy = true);
    _flash.forward(from: 0);
    final lines = await recognizeLines();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(builder: (_) => ReviewPage(lines: lines)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 가이드 프레임 + 스캔 라인
          Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Padding(
                padding: const EdgeInsets.all(34),
                child: LayoutBuilder(
                  builder: (context, box) => AnimatedBuilder(
                    animation: _scan,
                    builder: (context, _) => CustomPaint(
                      painter: _FramePainter(
                        Curves.easeInOut.transform(_scan.value),
                        _busy,
                      ),
                      child: SizedBox(width: box.maxWidth, height: box.maxHeight),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 8,
            left: 8,
            child: CupertinoButton(
              onPressed: () => Navigator.pop(context),
              child: const Icon(CupertinoIcons.xmark, color: Colors.white),
            ),
          ),
          Positioned(
            top: pad.top + 20,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.med,
                child: Container(
                  key: ValueKey(_busy),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _busy ? '인식 중' : '프레임에 맞추기',
                    style: T.subhead.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom + 36,
            child: Center(
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: _shoot,
                child: AnimatedScale(
                  scale: _pressed ? 0.86 : 1,
                  duration: _pressed ? const Duration(milliseconds: 90) : Motion.slow,
                  curve: _pressed ? Curves.easeOut : Motion.spring,
                  child: Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: AnimatedContainer(
                      duration: Motion.med,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _busy ? K.brand : null,
                        color: _busy ? null : Colors.white,
                      ),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 셔터 플래시
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) => ColoredBox(
                color: Colors.white.withValues(
                  alpha: _flash.isAnimating ? (1 - _flash.value) * 0.85 : 0,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.t, this.busy);

  final double t;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    const len = 34.0;
    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = K.brand.createShader(r);
    void l(Offset a, Offset b) => canvas.drawLine(a, b, corner);
    // 네 모서리 브래킷
    l(r.topLeft, r.topLeft + const Offset(len, 0));
    l(r.topLeft, r.topLeft + const Offset(0, len));
    l(r.topRight, r.topRight + const Offset(-len, 0));
    l(r.topRight, r.topRight + const Offset(0, len));
    l(r.bottomLeft, r.bottomLeft + const Offset(len, 0));
    l(r.bottomLeft, r.bottomLeft + const Offset(0, -len));
    l(r.bottomRight, r.bottomRight + const Offset(-len, 0));
    l(r.bottomRight, r.bottomRight + const Offset(0, -len));

    // 스캔 라인
    final y = r.top + 12 + (r.height - 24) * t;
    final glow = Rect.fromLTWH(r.left + 10, y - 26, r.width - 20, 52);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            K.indigo.withValues(alpha: 0),
            K.indigo.withValues(alpha: busy ? 0.5 : 0.28),
            K.indigo.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
    canvas.drawLine(
      Offset(r.left + 10, y),
      Offset(r.right - 10, y),
      Paint()
        ..strokeWidth = 2
        ..shader = K.brand.createShader(Rect.fromLTWH(r.left, y - 1, r.width, 2)),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.t != t || old.busy != busy;
}

/// 인식 결과 검토 (FR-14): 줄 단위 후보 수정·선택 → 일괄 추가
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.lines});

  final List<String> lines;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final List<TextEditingController> _ctrls = [
    for (final l in widget.lines) TextEditingController(text: l),
  ];
  late final List<bool> _checked = List.filled(widget.lines.length, true);

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  int get _count {
    var n = 0;
    for (var i = 0; i < _ctrls.length; i++) {
      if (_checked[i] && _ctrls[i].text.trim().isNotEmpty) n++;
    }
    return n;
  }

  void _add() {
    final s = AppScope.read(context);
    final n = s.addAll([
      for (var i = 0; i < _ctrls.length; i++)
        if (_checked[i]) _ctrls[i].text,
    ]);
    HapticFeedback.mediumImpact();
    final nav = Navigator.of(context);
    final host = nav.context;
    nav.pop();
    showToast(host, '$n개 추가', icon: CupertinoIcons.doc_text_viewfinder);
  }

  @override
  Widget build(BuildContext context) {
    final all = _checked.every((c) => c);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: GradientText('인식 결과', style: T.largeTitle),
                backgroundColor: K.bg.withValues(alpha: 0.82),
                border: null,
                transitionBetweenRoutes: false,
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _checked.fillRange(0, _checked.length, !all));
                  },
                  child: Text(all ? '전체 해제' : '전체 선택', style: T.body.copyWith(color: K.blue)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: K.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('샘플', style: T.caption.copyWith(color: K.orange)),
                      ),
                      const SizedBox(width: 8),
                      Text('${widget.lines.length}줄', style: T.footnote),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: _ctrls.length,
                itemBuilder: (context, i) => TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 380 + i * 70),
                  curve: Motion.spring,
                  builder: (context, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: AnimatedContainer(
                      duration: Motion.med,
                      decoration: BoxDecoration(
                        color: K.card,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _checked[i] ? K.shadow : const [],
                      ),
                      padding: const EdgeInsets.only(right: 14),
                      child: Row(
                        children: [
                          SquareCheck(
                            value: _checked[i],
                            onTap: () => setState(() => _checked[i] = !_checked[i]),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _ctrls[i],
                              onChanged: (_) => setState(() {}),
                              style: T.headline.copyWith(
                                color: _checked[i] ? K.label : K.label3,
                              ),
                              inputFormatters: [LengthLimitingTextInputFormatter(100)],
                              decoration: const InputDecoration(border: InputBorder.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: bottom + 100)),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 16,
            child: Pressable(
              onTap: _count > 0 ? _add : null,
              child: AnimatedContainer(
                duration: Motion.med,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _count > 0 ? K.brand : null,
                  color: _count > 0 ? null : K.gray5,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _count > 0 ? K.glow(K.indigo, a: 0.4, blur: 20) : const [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RollingText(
                      '$_count',
                      style: T.headline.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '개 추가',
                      style: T.headline.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
