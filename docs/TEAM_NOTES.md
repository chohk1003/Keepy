# TEAM_NOTES — 팀 공유 메모

> 이 문서는 **본인 브랜치에만** 둡니다 (prompts_log #6).

## 브랜치 규칙

- 각자 **개인 브랜치**에서 구현한다. (`dev` 브랜치 흐름은 쓰지 않음)
- 구현 결과를 비교해 **선정본만 `main`** 에 올린다.
- 커밋 전 `flutter analyze` / `flutter test` 통과 확인.

## 개발 환경

- Flutter **stable 3.47.9** 로 통일 (`flutter --version`). 버전이 다르면 `pubspec.lock` 충돌과 빌드 차이가 생긴다.
- Windows 에서 예전 SDK가 잡히면: PowerShell 에서
  ```powershell
  where.exe flutter
  [Environment]::GetEnvironmentVariable('Path','User')
  [Environment]::GetEnvironmentVariable('Path','Machine')
  ```
  로 사용자·시스템 `Path` 를 모두 확인하고, 시스템 쪽에 남은 옛 경로를 새 SDK의 `bin` 으로 교체 (prompts_log #5).
- 처음 받으면 `app\tool\setup_platforms.ps1` 실행 (android/ios/web 생성 + OCR 설정). Flutter 명령은 모두 `app/` 폴더에서.

## 올리면 안 되는 것 (CST-04)

- `.env` (BaaS 키) — `.env.example` 만 커밋
- 팀원 이름·학번이 들어간 명세서 PDF → `docs/private/` 에 두면 gitignore 됨
- 실제 메모 사진

## 서버 동기화 (MP3) 키 나누기

- Supabase 주소·공개 키는 각자 `app/.env` 에만 둔다. 채팅방·문서·커밋 메시지에 붙이지 않는다.
- 같은 서버를 같이 쓰려면 프로젝트 소유자가 팀원을 Supabase 조직에 초대 → 각자 대시보드에서 복사.
  따로 쓰려면 각자 무료 프로젝트를 만들고 `app/supabase/schema.sql` 을 실행한다.
- Secret key·`service_role` 키는 앱에 절대 넣지 않는다.
- 실행: `flutter run -d chrome --dart-define-from-file=.env` (자세한 순서는 `docs/MP3_실행_매뉴얼.md`).

## AI 사용 기록

- AI 결과는 실행 화면·`flutter test`·`flutter analyze` 로 확인한 뒤 반영하고, 고친 경우 이유를 `docs/prompts_log.md` 에 남긴다.
