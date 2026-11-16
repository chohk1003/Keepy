# Keepy

할 일 앱 — UI설계서 기준, Apple HIG 스타일 조작·디자인

## 실행

```powershell
flutter pub get
flutter run --dart-define-from-file=.env   # Android 에뮬레이터 권장 (MP3 동기화 포함)
flutter run                                # .env 없이 → 로그인 없는 로컬 전용(게스트) 모드
flutter analyze
flutter test
```

> **처음 MP3 설정을 하는 사람은 [docs/MP3_따라하기.md](docs/MP3_따라하기.md)를 순서대로 따라 하면 된다.**
> Firebase 설정값은 `.env`에 넣고 커밋하지 않는다. 필요한 키 목록은 [.env.example](.env.example).

## 조작

| 위치 | 조작 | 결과 |
|---|---|---|
| 전체 | 좌우 스와이프 / 하단 유리 탭 바 | 설정 ← 메인 → 날짜 (탭 알약이 스와이프를 따라옴) |
| 태스크 | 네모 체크 | 체크 그리기 + 입자 효과 + 취소선 → 잠시 뒤 '완료'로 이동, 토스트에서 취소 |
| 태스크 | 왼쪽으로 끌기 | 카드가 줄어들며 [날짜][태그] 버튼 등장(고무줄 저항, 놓아도 유지). [날짜] 끌기 = 그대로/+1~+7, [태그] 끌기 = 그대로/자주 쓰는 순/없음. 카드·바깥 터치, 화면 밖 스크롤 시 닫힘 |
| 태스크 | 오른쪽으로 끌기 | 삭제 버튼이 나온 상태로 스냅(누르면 삭제), 더 세게 끌면 바로 삭제. 끄는 중 위·아래로 벗어나면 취소 |
| 태스크 | 탭 | 편집 시트 (제목·태그·날짜 휠 피커·삭제) |
| 메인 | 상단 슬라이딩 세그먼트 | 전체 / 미완료 / 완료 |
| 입력 바 | 포커스 | 태그 칩(#과제 #수업 #팀 프로젝트 #개인), 1~100자일 때 전송 활성, 빈 입력은 흔들림 |
| 입력 바 | 카메라 | 촬영 → 인식 결과 검토 → N개 추가 (현재 샘플, MP4에서 ML Kit로 교체) |
| 날짜 | 캘린더 좌우 스와이프 / 날짜 탭 | 주 단위 스냅 이동. 고른 날은 비어 있어도 그 날짜로 바로 추가 |
| 날짜 | 목록 끝에서 더 세게 위·아래로 끌기 | 날짜 제목이 손가락을 따라 넘어가고, 임계값을 넘긴 채 놓으면 **할 일이 있는** 다음·이전 날로 이동 |
| 날짜 | 오른쪽 아래 [오늘] | 오늘로 바로 이동 |
| 메인·날짜 | 목록 아래 끝 · 입력 바 | 항목이 작아지며 흐려져 사라지는 영역과 입력 바 위에서 좌우로 밀면 탭 전환. 입력은 누를 때만 |
| 메인 | 분류 | 지연 · 할 일 · 늦은 완료 · 완료, 각각 날짜순 |
| 날짜 | 캘린더 칸 색 | 파랑 = 남은 할 일(많을수록 진함), 초록 = 전부 완료(완료가 많을수록 진함), 오늘 = 그라데이션 숫자 + 밑줄 |
| 전체 | 토스트 | 0.6초만 표시, 다른 곳을 누르면 즉시 닫힘 |
| 설정 | 달력 행 / 이번 주 위치 / 완료율(바·원형·그래프) | 날짜 화면에 즉시 반영 |

## 구조

```
lib/
  main.dart                  앱 시작, 로컬 저장소 열기, (.env 있으면) Firebase 동기화 연결
  theme.dart                 컬러·그라데이션·모션·타이포 토큰
  data/local_store.dart      shared_preferences JSON 저장 (FR-10)
  data/sync_store.dart       로컬 우선 동기화 계층 + LWW 병합 (MP3)
  data/firestore_backend.dart Firestore 연결 (users/{uid}/tasks)
  data/auth_service.dart     이메일/비밀번호 로그인
  data/firebase_env.dart     .env 에서 Firebase 설정값 읽기
  models/task.dart           Task, TaskTag, DoneEvent (+ JSON)
  state/app_state.dart       상태·설정, 변경 시 자동 저장
  pages/                     home_shell, main, date, settings, ocr, account(로그인)
  widgets/
    task_tile.dart           스냅 다이얼·삭제 제스처
    square_check.dart        네모 체크 + 입자 효과, 취소선 텍스트
    diff_sliver_list.dart    추가·삭제·이동 애니메이션 목록
    quick_input_bar.dart     유리 입력 바, 태그 칩
    week_calendar.dart       주 스와이프 캘린더, 완료율
    glass_tab_bar.dart       유리 탭 바
    task_editor.dart         편집 시트
    fx.dart                  눌림·그라데이션·유리·링·롤링 숫자 등 공통 효과
assets/fonts/                Pretendard (SIL OFL 1.1)
```

## 문서

- **[docs/STATUS.md](docs/STATUS.md)** — 남은 작업 현황 (할 일이 위, 끝난 일이 아래)
- [docs/](docs/README.md) — 기능별 구조 문서 (화면 · 태스크 · 제스처 · 저장 · 로그인 · Firebase · OCR)
- [docs/MP3_따라하기.md](docs/MP3_따라하기.md) — Firebase 설정부터 두 기기·오프라인 검증까지 순서대로
- [docs/FIREBASE_구조_보고서.md](docs/FIREBASE_구조_보고서.md) — 동기화 코드 전체 그림
- [TEAM_NOTES.md](TEAM_NOTES.md) — 팀 환경·브랜치·규칙

## MP3 — 백엔드 동기화

### 선택한 BaaS: Firebase (Authentication + Cloud Firestore)

| 비교 | Firebase | Supabase |
|---|---|---|
| Flutter 지원 | 공식 FlutterFire 패키지 | 공식 패키지 |
| 오프라인 | **SDK가 쓰기를 기기에 쌓아 두었다가 자동 전송** (앱 재시작 후에도 유지) | 직접 큐를 구현해야 함 |
| 실시간 | `snapshots()` 한 줄 | Realtime 채널 설정 필요 |
| 데이터 모델 | 문서형 — 지금 JSON 구조를 그대로 저장 | 관계형 — 테이블 설계·변환 필요 |
| 무료 요금제 | Spark (카드 등록 없음) | Free |

MP3의 핵심인 **오프라인 작성 → 온라인 복귀 반영**을 SDK가 기본으로 해 주고, 이미 쓰고 있는 JSON(`Task.toJson`)을
변환 없이 문서로 올릴 수 있어서 Firebase를 골랐다.

### 구조

```
AppState ──► SyncStore ──┬─► LocalStore (shared_preferences)   항상 먼저 저장, 읽기는 전부 여기서
   ▲                     └─► FirestoreBackend ──► users/{uid}/tasks/{taskId}
   └── applyRemote ◄──────── 실시간 수신(snapshots)
```

- **로컬 우선**: 화면은 항상 로컬 데이터로 그린다. 서버가 느리거나 끊겨도 앱이 멈추지 않는다.
- **로그인**: 이메일/비밀번호. 익명 로그인은 기기마다 다른 사용자가 되어 "두 기기 같은 목록"이 안 되므로 쓰지 않는다.
- **로그인 전(게스트)**: 이 기기에만 저장. 로그인하면 그동안 쓴 할 일이 계정으로 올라가 합쳐진다.
- **로그아웃**: 이 기기의 목록은 남고 동기화만 멈춘다.

### 동기화 충돌 처리 방침

1. **항목 단위 Last-Write-Wins** — 같은 할 일을 두 기기에서 고치면, `updatedAt`(마지막 수정 시각)이 더 늦은 쪽이 이긴다.
   다른 할 일끼리는 서로 영향이 없다.
2. **서버에서도 강제** — Firestore 보안 규칙([firestore.rules](firestore.rules))이 서버에 있는 것보다 오래된 버전으로
   덮어쓰는 것을 거절한다. 오프라인이던 기기가 나중에 옛날 값을 올려도 다른 기기의 최신 수정이 지워지지 않는다.
3. **로그인 직후에는 받고 나서 올린다** — 서버를 먼저 읽어 병합한 뒤, 이 기기 쪽이 더 최신인 것만 올린다.
4. **삭제는 tombstone** — 문서를 지우지 않고 `deleted: true`로 표시한다. 그래야 오프라인 기기에도 삭제가 전달되고,
   지운 항목이 옛 데이터 때문에 되살아나지 않는다. 화면에서는 보이지 않는다.
5. **샘플 데이터** — 첫 실행 샘플 7개는 기기마다 같은 id에 아주 오래된 수정 시각으로 만든다.
   두 기기에서 로그인해도 두 벌로 늘지 않고, 다른 기기에서 고치거나 지운 샘플이 되살아나지 않는다.
6. **한계** — 수정 시각은 각 기기의 시계를 쓰므로, 기기 시계가 크게 틀리면 판정이 어긋날 수 있다.
   완료 기록(`doneLog`)과 설정은 기기별로 저장하고 동기화하지 않는다.

### 백엔드 설정 절차 · 실행 절차

[docs/MP3_따라하기.md](docs/MP3_따라하기.md) — Firebase 프로젝트 만들기부터 두 기기 동기화·오프라인 확인까지 순서대로 정리.

### 측정값 (NFR-03 · NFR-04)

| 항목 | 목표 | 측정값 |
|---|---|---|
| 기기 A 추가 → 기기 B 표시 | 3초 이내 | _측정 후 기록_ |
| 오프라인 작성 → 온라인 복귀 후 서버 반영 | 5초 이내 | _측정 후 기록_ |

## 남은 단계

- MP3: 위 측정값 기록, 스크린샷(기기 A 추가 · 기기 B 동기화 · 오프라인→온라인 · 콘솔)
- MP4: 실기기에서 OCR 검증 (docs/STATUS.md)
