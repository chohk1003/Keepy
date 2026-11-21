import 'package:flutter_test/flutter_test.dart';
import 'package:keepy_prototype/features/ocr/viewmodels/ocr_view_model.dart';

void main() {
  test('OCR mock parser collects non-empty lines as candidates', () {
    final result = OcrViewModel().extractTaskCandidates('회의 준비\n\n- 보고서 작성\n');
    expect(result, ['회의 준비', '보고서 작성']);
  });
}
