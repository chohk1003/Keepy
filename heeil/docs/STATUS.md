# 작업 현황

> 최종 수정: 2026-11-16 · 기준 브랜치: `희일` (`현규` 브랜치의 MP3 리베이스 반영) · Flutter 3.47.9 stable
> 앱은 `heeil/app`, 문서는 `heeil/docs`. **문서의 코드 경로는 `app/` 기준**이고 `flutter` 명령도 `heeil/app`에서 실행한다.
> **규칙: 할 일은 위, 끝난 일은 [완료](#완료)로 내린다.** 자세한 구조는 [docs/README.md](README.md) 참고.

## 한눈에

```mermaid
flowchart LR
    MP1["MP1<br/>목록·추가·완료"]:::done
    MP2["MP2<br/>수정·삭제·필터·저장"]:::done
    MP3["MP3<br/>Firebase 동기화"]:::part
    MP4["MP4<br/>카메라 OCR"]:::part
    SUB["제출<br/>폴더·문서·스크린샷"]:::todo

    MP1 --> MP2 --> MP3 --> MP4 --> SUB

    classDef done fill:#30D158,stroke:#1a7a33,color:#fff
    classDef part fill:#FF9F0A,stroke:#9c6100,color:#fff
    classDef todo fill:#8E8E93,stroke:#48484a,color:#fff
```

| 영역 | 상태 | 문서 |
|---|---|---|
| 화면·제스처·태스크·로컬 저장 | 🟢 | [screens](screens.md) · [gestures](gestures.md) · [tasks](tasks.md) · [storage](storage.md) |
| 로그인 | 🟢 이메일/비밀번호 로그인·가입·로그아웃 | [auth](auth.md) |
| Firebase 동기화 | 🟡 코드 완료, 콘솔 설정·실측 남음 | [firebase](firebase.md) · [구조 보고서](FIREBASE_구조_보고서.md) |
| 카메라 OCR | 🟡 코드 완료, 실기기 검증 남음 | [ocr](ocr.md) |
| 알림·외부 서비스 | 🔴 설정 토글만 | [integrations](integrations.md) |

## 🔵 라운드 2 — 진행 중

②·③(Firebase 연결 + 로그인 화면)은 `현규` 브랜치에서 끝나 2026-11-16에 리베이스로 들어왔고, ①(폴더 이동)도 같은 날 끝났다. 남은 건 ④⑤ — **둘 다 실기기·측정 쪽**이다.

```mermaid
flowchart TD
    A["① heeil/app 폴더 이동"]:::done
    B["② Firebase 연결"]:::done
    C["③ 로그인 화면"]:::done
    D["④ 회귀 테스트 3건<br/>+ 날짜·설정 화면 테스트"]:::now
    E["⑤ 실기기 검증<br/>OCR·제스처·NFR 측정"]:::now

    A --> D
    A --> E
    B --> C --> E

    classDef now fill:#0A84FF,stroke:#0060df,color:#fff
    classDef done fill:#30D158,stroke:#1a7a33,color:#fff
```

| 순서 | 담당 | 상태 |
|---|---|---|
| ① `heeil/app` 이동 | 헤드 단독 | 🟢 완료 (2026-11-16) — analyze 0 · test 89 · APK 빌드 확인 |
| ② Firebase 연결 + `FirestoreBackend` | sync 담당 | 🟢 완료 (2026-11-15) — 콘솔 설정은 사용자 몫 |
| ③ 로그인 화면 | auth 담당 | 🟢 완료 (2026-11-15) — `app/lib/pages/account_page.dart` |
| ④ 회귀 테스트 3건 | test 담당 | 🔴 남음 |
| ⑤ 실기기 검증 + MP3 측정 | 사용자 | 🔴 남음 ([MP3_따라하기.md](MP3_따라하기.md) 6·7장) |

**④ 회귀 테스트 3건** (라운드 1에서 고친 버그가 다시 안 생기게)

- 설정 '달력 행'을 1로 바꿔도 예외 없음
- 체크 후 520ms 안에 삭제 → `doneLog`가 비어 있음
- 액션 패널 열기→닫기 왕복 시 오버플로 없음

**⑤ 실기기에서 잴 것** → `screenshots/README.md`, [ocr.md](ocr.md)

- OCR 실측 시간(NFR-02) · 원본 미저장(NFR-05) · 권한 거부 안내(NFR-07) · 비행기 모드(CST-02)
- 제스처 손맛 — 임계값은 코드상 문서와 일치하지만 데스크톱·웹에서만 확인됨
## 🟢 제출 폴더 구조 — 이동 완료 (2026-11-16)

심사기준이 요구하는 구조(`app/` + `README.md` + `screenshots/` + `prompts_log.md`)를 **개인 폴더 안에 그대로** 갖췄다. 비교·선정이 끝나면 **고른 폴더의 내용을 루트로 올리기만** 하면 된다.

```mermaid
flowchart LR
    subgraph REPO["저장소 루트"]
        R1["Keepy/<br/>├ README.md  (폴더 배치 안내)<br/>├ .gitignore<br/>├ mergeProject/  통합 대상<br/>└ heeil/"]
    end
    subgraph MINE["heeil/ — 내 구현"]
        M1["├ app/            Flutter 프로젝트<br/>│  ├ pubspec.yaml · lib/ · test/<br/>│  ├ android/ ios/ web/ windows/<br/>│  └ firestore.rules · .env.example<br/>├ README.md      앱 설명·조작·구조<br/>├ docs/          기능별 문서<br/>├ screenshots/<br/>├ prompts_log.md<br/>└ TEAM_NOTES.md"]
    end
    REPO --> MINE
```

**flutter 명령은 `heeil/app`에서 실행한다.**

| 항목 | 필수 | 내용 | 상태 |
|---|---|---|---|
| `app/` | ✅ | 앱 소스 전체 | 🟢 `heeil/app` |
| `README.md` | ✅ | 화면 구성 · 데이터 구조 · 실행 절차 | 🟡 더미 데이터 구조 설명 보강 남음 |
| `screenshots/` | ✅ | 화면별 1장 이상 | 🔴 촬영 필요 |
| `prompts_log.md` | ✅ | 프롬프트 + AI 응답의 **채택/수정 판단** | 🟡 틀만 있음 |

**이동하며 같이 고친 것**

- [x] `git mv` 로 이동 — 전부 R100(내용 변경 없음)으로 이력 보존
- [x] `README.md` · `TEAM_NOTES.md` 실행 절차에 `cd app` 반영
- [x] 이동으로 깨진 상대 링크 5개 (`.env.example` · `firestore.rules`)
- [x] 루트 `README.md` 복구 + 루트 `.gitignore` 추가 (앱 쪽 규칙은 `heeil/app/.gitignore`가 담당)
- [x] `docs/*.md`의 코드 경로는 **`app/` 기준이라고 한 번만 명시** — 80곳 넘는 `lib/…`를 전부 바꾸는 대신 [docs/README.md](README.md#3-구현-위치는-파일-단위로)에 기준을 적었다
- [ ] `keepy.iml`, `.idea/` — IDE 설정 경로 (열어 보고 어긋나면)
- [ ] GitHub Actions 등 CI가 생기면 working-directory

> 이동 후 `heeil/app`에서 확인: `flutter analyze` 0건 · `flutter test` 89개 통과 · `flutter build apk --debug` 성공.

---

## 🟠 MP3 — Firebase Auth + Firestore

→ 설계·구조: [firebase.md](firebase.md), [auth.md](auth.md) · 전체 그림: [FIREBASE_구조_보고서.md](FIREBASE_구조_보고서.md)
→ **코드는 2026-11-15에 다 들어왔다** (아래 완료 참고). 남은 건 **사용자만 할 수 있는 콘솔 설정과 실측**.

### 사용자가 할 일 (절차: [MP3_따라하기.md](MP3_따라하기.md))

- [ ] **Firebase 프로젝트 생성** + Android 앱 등록 → `.env` 값 4개 채우기
- [ ] **Authentication → 이메일/비밀번호 로그인 켜기** (안 켜면 `operation-not-allowed`)
- [ ] **Firestore Database 생성 + [`firestore.rules`](../app/firestore.rules) 게시**
- [ ] **측정** — 동기화 3초 이내(NFR-03), 오프라인 복귀 5초 이내(NFR-04) 실측값 README 기록
- [ ] **스크린샷** — 기기 A 추가 · 기기 B 동기화 · 오프라인→온라인 · Firestore 콘솔

### 코드로 남은 일

- [ ] **tombstone 정리 기준** — 며칠 뒤 실제 삭제할지 미정. 지금은 계정에 계속 쌓인다
- [ ] **`doneLog`·설정 동기화 여부** — 지금은 기기별 로컬 보관. `SyncBackend.push()`가 받는 `log`·`settings` 인자를 `FirestoreBackend`가 쓰지 않아 오해 소지가 있다
- [ ] **v1 키 정리 시점** — 마이그레이션 후에도 남겨 둠. MP3 마무리 때 제거 판단
- [ ] **시계 어긋남** — `updatedAt`이 기기 시계라서 시계가 크게 틀리면 LWW 판정이 어긋난다. 서버 시각 기준으로 바꿀지 판단 (`serverUpdatedAt`은 이미 올라간다)
## 🟡 MP4 — 카메라 + ML Kit

→ 설계·구조: [ocr.md](ocr.md)
→ **코드는 2026-11-09에 붙었다.** 남은 건 실기기 검증과 측정값 기록.

### ⚠ iOS에서는 한국어 인식이 안 된다

`google_mlkit_text_recognition` 1.0.1 기준, iOS는 **라틴 문자만** 지원한다. `TextRecognitionScript.korean`을 넘겨도
죽지는 않고 **라틴 인식기로 조용히 폴백**해서 한글이 안 잡힌다. 추가로 iOS는 배포 타깃 15.0+,
`OTHER_LDFLAGS`에 `-ObjC`·`-all_load`, `LatinOCRResources.bundle` 수동 추가까지 Xcode 작업이 필요하다.

→ **MP4 시연·스크린샷은 Android로 잡는다.** (TEAM_NOTES 8장의 아이폰 확인 절차는 MP1~MP3용)

### 남은 일

- [ ] **Android 실기기 검증** — 한글 인쇄물(강의계획서·시간표)과 손글씨를 각각 촬영, 몇 줄 잡히는지 확인
- [ ] **NFR-02 실측값 README 기록** — 검토 화면이 `N줄 · 0.00초`로 표시하니 그 값을 그대로 적으면 된다
- [ ] **NFR-05 실물 확인** — 촬영 후 `adb shell run-as <패키지> ls cache/` 로 사진이 안 남는지. `image_picker`가 캐시에 복사본을 만들어서 이 확인이 의미 있다
- [ ] **NFR-07 실측** — 카메라 권한을 끈 뒤 촬영 → 안내 팝업 확인. 기기마다 `image_picker`가 주는 code가 달라서, 기본 분기(`인식 실패`)로 떨어지면 `recognize_io.dart`의 `_deniedMessage`에 그 code를 추가해야 한다
- [ ] **비행기 모드 확인** — 모델이 APK에 번들된 것은 확인됨. 스크린샷 한 장이면 CST-02 근거가 된다
- [x] ~~데스크톱 빌드 확인~~ — `flutter build windows --debug` 성공 (2026-11-09, 47.2s). 조건부 import가 데스크톱에서 정상 컴파일됨. 실행 중 샘플 폴백 화면 확인은 남음
- [ ] **측정 구간 합의** — 지금은 사진을 받은 뒤부터 줄 추출까지만 잰다(카메라 앱 체류 시간 제외). NFR-02를 다르게 읽어야 하면 `recognize_io.dart`의 Stopwatch 시작 위치만 올리면 된다
## 🟢 제출 준비

> 폴더 구조는 [이동 완료](#-제출-폴더-구조--이동-완료-2026-11-16). 남은 건 내용 채우기.

- [ ] **`prompts_log.md` 내용 채우기** — 틀은 만들어 둠. 각자 쓴 프롬프트·판단을 취합할 것
- [ ] **`screenshots/` 촬영** — 찍을 목록은 `screenshots/README.md` 에 단계별로 정리됨
- [ ] **README 보강** — 심사기준이 요구하는 3가지 중 **더미(샘플) 데이터 구조** 설명이 아직 없다
- [ ] **MP2 저장 방식 비교** — shared_preferences vs sqflite vs Hive, 고른 이유 ([storage.md](storage.md#할-일))
- [ ] 요구사항 명세서 문구 수정 — "왼쪽으로 스와이프 시 설정"이 손가락 방향과 반대 ([screens.md](screens.md#스와이프-방향))

## ⚪ 품질

라운드 1의 오류 담당이 찾았지만 **범위가 달라 안 고친 것들.** 전부 증상이 없거나 발생 확률이 낮아 당장 급하지는 않다.

| 심각도 | 증상 | 위치 |
|---|---|---|
| 낮음 | `Toast`의 정적 `Timer`가 위젯 트리보다 오래 산다 — 토스트 뜨는 흐름의 테스트는 1.2초를 `pump` 해야 함 | `lib/widgets/toast.dart` |
| 낮음 | `DatePage.build`가 빌드 중에 상태 필드를 바꾼다 (`_titleDay`, `_dir`) — 지금은 예외 없음 | `lib/pages/date_page.dart` |
| 낮음 | `WeekCalendar.build`가 `PageController`를 빌드 안에서 만들고 매 빌드마다 `addPostFrameCallback`을 건다 | `lib/widgets/week_calendar.dart` |
| 낮음 | 작은 화면(720x1280)에서 '달력 행' 4로 두면 날짜 칸이 찌그러진다 (예외는 없음) | `DatePage` CST-01 고정 높이 |

### 그 외

- [ ] **실기기 확인** — 아이폰·안드로이드 모두 아직 아무도 안 함 (TEAM_NOTES 8장)
- [ ] **첫 실행 샘플 7개** — 제출 스크린샷 전에 지울지 결정 (`AppState._seed()`)
- [ ] 테스트 공백 — 날짜 화면 제스처, 설정 화면 UI, OCR 흐름, `EdgeFade` 탭 전환, 다크 모드
- [ ] 다크 모드 — 미검토 (`buildTheme()`은 라이트 전용)
- [ ] `Toast.dismiss()` 테스트 정리 훅을 `lib`에 열지 결정 — 테스트 담당과 조율 필요

---

## 완료

<details open>
<summary><b>MP3 — Firebase 동기화</b> (2026-11-15, `현규` 브랜치 → 2026-11-16 리베이스)</summary>

**인증**
- [x] BaaS 선정 — Firebase (오프라인 큐·실시간·문서형 모델 때문에, 비교표는 [firebase.md](firebase.md#왜-firebase인가-supabase와-비교))
- [x] 로그인 방식 — 이메일/비밀번호. **익명 로그인 제외** (기기마다 uid가 달라 FR-11이 성립하지 않음)
- [x] `AuthService` — 로그인·가입·로그아웃 + 오류 코드 한국어 번역
- [x] 계정 화면 `pages/account_page.dart` + 설정 계정 행이 상태에 따라 문구 변경
- [x] 로그아웃 정책 — 이 기기 목록은 남고 동기화만 멈춤

**동기화**
- [x] `FirestoreBackend` — `push` · `pullTasks` · `watchTasks(snapshots)` · uid 전환 시 재구독
- [x] `AppState.applyRemote()` — 실시간 수신분을 항목별 LWW 병합 (**객체 교체 없이 필드만** 수정)
- [x] 스키마 확정 `users/{uid}/tasks/{taskId}` + 서버용 `updatedAtMs`·`serverUpdatedAt`
- [x] 보안 규칙 `firestore.rules` — 본인 문서만 + **서버 측 LWW 강제** + `delete` 금지
- [x] `remove()`·`clearDone()` tombstone 전환 + `_rawIndexOfLive()` 되돌리기 인덱스 변환
- [x] 첫 실행 샘플을 고정 id + `updatedAt = 2000년`으로 — 기기 간 중복·부활 방지
- [x] 쓰기 단위 — `FirestoreBackend._known`(id → `updatedAt`) 비교로 **바뀐 문서만** `set()`. `TaskStore` 계약 변경 없이 해결
- [x] 오프라인 큐 — 직접 구현하지 않고 Firestore SDK에 맡김(`set()`을 await 하지 않음). 앱은 네트워크 상태를 감시하지 않는다

**설정·안전장치**
- [x] `.env` / `.env.example` 분리 + `.gitignore`(`.env` · `google-services.json` · `firebase_options.dart`) (NFR-06, CST-04)
- [x] `.env`가 없거나 초기화가 실패하면 **로컬 전용 게스트 모드로 계속 실행** (크래시 없음)
- [x] Android `minSdk` 23 상향
- [x] `test/sync_test.dart` 9건 — 메모리 가짜 백엔드로 로그인 승계·LWW·실시간 반영·tombstone 전파 검증
- [x] OCR 일괄 추가(`addAll`)에 1~100자 규칙 적용 — 품질 표의 '중간' 항목 해소 (CST-03)
- [x] `clearDone()` 되돌리기가 목록 전체를 덮어쓰지 않도록 수정 — 그사이 추가한 할 일이 사라지지 않는다

</details>

<details open>
<summary><b>라운드 1 — 서브에이전트 4개 병렬</b> (2026-11-09) · analyze 0건 / test 79개 전부 통과</summary>

**테스트 (test-lead)**
- [x] 단위 테스트 65개 신규 — `app_state_test.dart` 46 · `task_model_test.dart` 12 · `local_store_test.dart` 7
- [x] `statusOf()` 4분류 **경계값**, `sortByDate()` 3단 규칙, 되돌리기 왕복, `doneLog` 100개 상한, `neighborTaskDay()`
- [x] 시계 의존 제거(`statusOf(t, now:)` 주입) · 1분 타이머 `addTearDown(dispose)` 정리
- [x] **문서가 사실과 달랐던 것 발견** — TEAM_NOTES의 "test 6개 전부 통과"는 실제로 14개 중 5개 실패 상태였음

**오류 (bug-hunter)**
- [x] **액션 패널 RenderFlex 오버플로 수정** — 고정 폭 `SizedBox(width: 6)`을 버튼별 `Padding(3)`으로. 폭이 0이어도 수학적으로 오버플로 불가. 깨지던 테스트 5개 복구
- [x] **설정 '달력 행' 1로 바꾸면 죽던 크래시 수정** — 칸 2개 미만이면 `CupertinoSlidingSegmentedControl` 대신 고정 라벨
- [x] **체크 후 520ms 안에 삭제하면 '완료 기록'에 남던 버그 수정**
- [x] `Motion.spring` 전수 조사 15곳 → `settings_page._Toggle` 1곳 교정. 나머지는 안전 확인
- [x] 제스처 임계값 10개가 문서와 전부 일치함을 대조 확인
- [x] Chrome 실행으로 3화면·필터·스와이프·편집 시트 콘솔 오류 0 확인

**동기화 선행 (sync-prep)**
- [x] `Task.updatedAt`(LWW) · `deleted`(tombstone) + `touch()`. 구버전 JSON 하위호환
- [x] 저장 키 v2 + v1→v2 마이그레이션 (v1 보존 — 브랜치 비교 중 되돌아갈 때를 위해)
- [x] `TaskStore` 계약 추출 → `AppState.store` 타입 변경. **`main.dart` 한 줄로 Firestore 교체 가능**
- [x] `SyncStore` + `SyncBackend` + 순수 함수 `mergeTasks()` LWW 병합 (Firebase 의존 없음)
- [x] tombstone 조회 필터 8곳 선반영 (`tasks` `todo` `done` `ofStatus` `onDay` `dayCounts` `neighborTaskDay` `tagsByUsage`)

**OCR (ocr-prep)**
- [x] `recognizeLines()`를 실제 ML Kit 경로로 교체 — `image_picker` → `InputImage` → `TextRecognizer(korean)`
- [x] **조건부 export로 웹 분리** — 웹 번들에 ML Kit 코드가 안 들어감. `flutter build web` 성공 확인
- [x] 데스크톱은 `Platform` 가드로 샘플 폴백 (`MissingPluginException` 방지)
- [x] 한국어 모델 `com.google.mlkit:text-recognition-korean:16.0.1` 추가 — **APK 안에 모델 파일 존재까지 확인**
- [x] NFR-05 원본 즉시 삭제(`finally`) · NFR-02 3초 타임아웃 · NFR-07 권한 거부 안내
- [x] 소요 시간 실측 표시 (`N줄 · 0.00초`) · '샘플' 배지는 폴백일 때만
- [x] Android `CAMERA` 권한 + `uses-feature required=false`
- [x] **iOS는 한국어 미지원 발견** — 라틴으로 조용히 폴백. MP4 시연은 Android로 확정

**헤드**
- [x] iOS `Info.plist` 카메라·사진 권한 추가 (2026-11-09)
- [x] 9월부터 남아 있던 `enable-windows-desktop: false` 복원 → `flutter doctor` **No issues found!**
- [x] `flutter build windows --debug` 성공 (47.2s) — 조건부 import 데스크톱 컴파일 검증
- [x] `Motion.spring` 경고 문구 정정 — "예외가 난다" → "그림자 blur가 음수가 되어 깨진다" (3.47.9 재확인)
- [x] `prompts_log.md` 틀 · `screenshots/README.md` 촬영 목록 · `docs/` 11개 문서

</details>


<details open>
<summary><b>MP2 — 수정·삭제·필터·로컬 저장</b> (2026-11-03)</summary>

- [x] 로컬 영속성 — `shared_preferences` + JSON, 0.25초 디바운스 자동 저장 (2026-11-02) · [storage.md](storage.md)
- [x] 앱 일시정지 시 즉시 저장 (`HomeShell.didChangeAppLifecycleState`) (2026-11-03)
- [x] 편집 시트 — 제목·태그·날짜 휠 피커·삭제 (2026-11-03)
- [x] 삭제 제스처 — 오른쪽으로 끌기, 스냅 후 버튼 / 230px 이상 즉시 삭제 (2026-11-03)
- [x] 필터 — 전체 / 미완료 / 완료 슬라이딩 세그먼트 (2026-11-02)
- [x] 분류 — 지연 · 할 일 · 늦은 완료 · 완료, 각 날짜순 (2026-11-03) · [tasks.md](tasks.md)
- [x] 완료 이벤트 내역 + 완료 항목 일괄 삭제·되돌리기 (2026-11-03)
- [x] `flutter analyze` 0건, `flutter test` 6개 통과 (2026-11-03)

</details>

<details>
<summary><b>MP1 — 목록·추가·완료·빈 상태</b> (2026-11-02)</summary>

- [x] 3단 수평 스와이프 셸 + 유리 탭 바 (2026-11-02) · [screens.md](screens.md)
- [x] 태스크 추가 — 유리 입력 바, 태그 칩, 1~100자 검증, 빈 입력 흔들림 (2026-11-02)
- [x] 완료 토글 — 네모 체크 + 입자 효과 + 취소선, 0.52초 뒤 이동, 토스트 되돌리기 (2026-11-02)
- [x] 빈 상태 화면 (2026-11-02)
- [x] 주 스와이프 캘린더 — 완료율 색, 할 일 있는 날로만 이동 (2026-11-03)
- [x] 왼쪽 끌기 스냅 다이얼 — [날짜] +1~+7 / [태그] 빈도순 (2026-11-03) · [gestures.md](gestures.md)
- [x] 설정 화면 — 달력 행·이번 주 위치·완료율 표시 방식 (2026-11-03)
- [x] Pretendard 폰트 + 디자인 토큰 `theme.dart` (2026-11-02)

</details>
