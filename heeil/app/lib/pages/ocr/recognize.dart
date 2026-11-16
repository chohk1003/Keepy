/// 플랫폼별 인식 구현을 골라 주는 진입점 (MP4)
///
/// ML Kit과 `image_picker`의 파일 처리는 `dart:io`에 기댄다. 그냥 import하면
/// `flutter build web`이 컴파일 단계에서 깨진다 (팀 전원이 `-d chrome`·`-d windows`로
/// 개발 중 — TEAM_NOTES 2장·8장). 그래서 조건부 export로 갈라 둔다.
///
/// - `dart:io` 있음 (모바일·데스크톱) → `recognize_io.dart`
///   데스크톱은 ML Kit 플러그인이 없으므로 그 안에서 다시 샘플 폴백으로 빠진다.
/// - `dart:io` 없음 (웹) → `recognize_stub.dart`
library;

export 'recognize_stub.dart' if (dart.library.io) 'recognize_io.dart';
