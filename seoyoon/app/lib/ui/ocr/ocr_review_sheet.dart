import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/task.dart';
import '../widgets/basics.dart';

/// 카메라 인식 결과 검토 (UI 설계서 08 / FR-14).
///
/// 줄마다 하나의 후보. 글자를 직접 고칠 수 있고, 체크한 것만
/// '선택한 N개 추가'로 한 번에 등록한다. 돌려주는 값은 등록할 제목들.
Future<List<String>?> showOcrReview(BuildContext context, List<String> candidates) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => _OcrReview(candidates: candidates),
  );
}

class _OcrReview extends StatefulWidget {
  const _OcrReview({required this.candidates});
  final List<String> candidates;

  @override
  State<_OcrReview> createState() => _OcrReviewState();
}

class _OcrReviewState extends State<_OcrReview> {
  late final List<TextEditingController> _controllers =
      widget.candidates.map((c) => TextEditingController(text: c)).toList();
  late final List<bool> _checked = List<bool>.filled(widget.candidates.length, true);

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _selectedTitles => <String>[
        for (var i = 0; i < _controllers.length; i++)
          if (_checked[i] && TitleRule.isValid(_controllers[i].text)) _controllers[i].text,
      ];

  @override
  Widget build(BuildContext context) {
    final count = _selectedTitles.length;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: Container(
          decoration: BoxDecoration(
            color: KeepyColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 10, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('온디바이스 인식', style: KeepyText.footnote),
                            const SizedBox(height: 2),
                            Text('인식된 태스크', style: KeepyText.title),
                            const SizedBox(height: 4),
                            Text('등록할 항목을 선택하세요 · 글자를 눌러 고칠 수 있어요', style: KeepyText.caption.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(CupertinoIcons.xmark_circle_fill, color: KeepyColors.tertiaryLabel, size: 26),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    itemCount: _controllers.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AnimatedContainer(
                        duration: KeepyMotion.fast,
                        decoration: BoxDecoration(
                          color: _checked[i] ? KeepyColors.skyTint : KeepyColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _checked[i] ? KeepyColors.blue.withValues(alpha: 0.3) : KeepyColors.separator,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            KeepyCheckbox(
                              checked: _checked[i],
                              size: 22,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _checked[i] = !_checked[i]);
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controllers[i],
                                onChanged: (_) => setState(() {}),
                                maxLength: TitleRule.maxLength,
                                style: KeepyText.body.copyWith(fontSize: 14),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: GradientButton(
                    label: count == 0 ? '추가할 항목을 선택하세요' : '선택한 $count개 추가',
                    onPressed: count == 0 ? null : () => Navigator.pop(context, _selectedTitles),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(
                    '원본 사진은 기기에도 서버에도 저장되지 않아요',
                    textAlign: TextAlign.center,
                    style: KeepyText.footnote,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
