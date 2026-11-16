# Keepy

한성대학교 모바일 프로그래밍 팀 프로젝트 — 할 일 앱.

## 저장소 구조

각자 **본인 브랜치**에서 독립적으로 구현하고, 단계(MP)마다 결과를 비교해 하나를 선정한다.
개인 폴더 안에 제출 심사기준 구조(`app/` + `README.md` + `screenshots/` + `prompts_log.md`)를
그대로 갖춰 두므로, **선정된 폴더의 내용을 루트로 올리기만** 하면 기준을 만족한다.

```
heeil/              희일 구현
  app/              Flutter 프로젝트 — flutter 명령은 여기서 실행
  README.md         앱 설명 · 조작 · 구조
  docs/             기능별 상세 문서 (단일 소스는 docs/STATUS.md)
  screenshots/      제출용 화면
  prompts_log.md    AI 프롬프트와 채택 · 수정 판단
  TEAM_NOTES.md     팀 공통 규칙 (환경 · 브랜치 · 제출 체크)
```

## 실행

```powershell
cd heeil/app
flutter pub get
flutter run          # -d windows / -d chrome / 안드로이드 에뮬레이터
```

Flutter 3.47.9 stable 기준. 환경 설정에서 막히면 [heeil/TEAM_NOTES.md](heeil/TEAM_NOTES.md) 1장을 먼저 볼 것.

Firebase 동기화까지 확인하려면 `.env` 가 필요하다 — [heeil/docs/MP3_따라하기.md](heeil/docs/MP3_따라하기.md)
순서대로 따라 하면 된다. `.env` 없이도 **로컬 전용 게스트 모드**로 돈다.

## 문서

| 문서 | 내용 |
|---|---|
| [heeil/README.md](heeil/README.md) | 앱이 무엇을 하고 어떻게 조작하는지 |
| [heeil/docs/STATUS.md](heeil/docs/STATUS.md) | 남은 작업 체크리스트 (단일 소스) |
| [heeil/TEAM_NOTES.md](heeil/TEAM_NOTES.md) | 개발 환경 · 브랜치 규칙 · 제출 전 체크 |
