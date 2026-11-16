/// 플랫폼 공통 OCR 타입·상수 (MP4)
///
/// 여기에는 `dart:io`·ML Kit 의존이 없어야 한다. 웹 빌드도 이 파일을 컴파일한다.
library;

/// 인식 제한 시간 (NFR-02: 촬영 → 검토 화면 3초 이내)
const Duration ocrTimeout = Duration(seconds: 3);

/// 폴백에서 흉내 내는 인식 시간
const Duration _sampleDelay = Duration(milliseconds: 900);

/// 웹·데스크톱 폴백용 샘플 5줄. ML Kit은 모바일 전용이라 여기서는 실제 인식을 못 한다.
const List<String> sampleLines = [
  '운영체제 과제 제출',
  '장보기 우유 계란',
  '팀플 회의록 정리',
  '도서관 책 반납',
  '컴그 4장 복습',
];

/// 타임아웃 안내 (NFR-02)
const String timeoutMessage = '인식 3초 초과\n글자가 크게 보이도록 다시 촬영';

/// 권한 거부 안내 (NFR-07)
const String cameraDeniedMessage = '카메라 권한 없음\n설정 > Keepy > 카메라 허용';

/// 사진 접근 거부 안내 (NFR-07)
const String photoDeniedMessage = '사진 권한 없음\n설정 > Keepy > 사진 허용';

/// 인식 결과 한 묶음.
///
/// 실패·거부·타임아웃도 예외를 던지지 않고 이 타입으로 돌려준다.
/// 촬영 화면이 분기 하나로 처리할 수 있게 하려는 것.
class OcrResult {
  const OcrResult({
    this.lines = const [],
    this.elapsed = Duration.zero,
    this.sample = false,
    this.message,
    this.cancelled = false,
  });

  /// 인식된 줄 (빈 줄 제거됨)
  final List<String> lines;

  /// 실측 소요 시간. 제출 시 README에 적을 값 (NFR-02)
  final Duration elapsed;

  /// 웹·데스크톱 폴백인지 — 검토 화면의 '샘플' 배지 조건
  final bool sample;

  /// 사용자에게 보일 안내 문구. 정상이면 null (NFR-02, NFR-07)
  final String? message;

  /// 사용자가 촬영을 취소함 — 안내 없이 촬영 화면에 머문다
  final bool cancelled;

  bool get hasLines => lines.isNotEmpty;
}

/// ML Kit을 못 쓰는 플랫폼(웹·데스크톱)에서 쓰는 샘플 폴백.
Future<OcrResult> sampleFallback() async {
  final sw = Stopwatch()..start();
  await Future<void>.delayed(_sampleDelay);
  sw.stop();
  return OcrResult(lines: sampleLines, elapsed: sw.elapsed, sample: true);
}
