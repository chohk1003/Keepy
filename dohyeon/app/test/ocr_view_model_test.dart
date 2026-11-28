import 'package:flutter_test/flutter_test.dart';
import 'package:keepy_prototype/features/ocr/viewmodels/ocr_view_model.dart';

void main() {
  test('OCR mock parser collects non-empty lines as candidates', () {
    final result = OcrViewModel().extractTaskCandidates('회의 준비\n\n- 보고서 작성\n');
    expect(result, ['회의 준비', '보고서 작성']);
  });

  test('candidate extraction preserves mixed text and does not truncate', () {
    final laterLines = List.generate(11, (index) => 'Memo ${index + 1}');
    final lines = ['1.   회의 Follow-up  ', '2026 일정', '•', ...laterLines];
    expect(OcrViewModel().extractTaskCandidates(lines.join('\r\n')), [
      '회의 Follow-up',
      '2026 일정',
      ...laterLines,
    ]);
  });
}
