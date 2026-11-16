# Firebase 동기화 구조 보고서

> 작성: 2026-11-16 · 기준 커밋: `0d0c896` (브랜치 `희일`) · 분석 대상: 리베이스로 들어온 `0d6a331` "MP3: Firebase 동기화"
> 읽는 목적: **리베이스로 합쳐진 Firebase 코드가 어디에 어떻게 끼워졌는지** 파악

---

## 1. 요약 — 무엇이 들어왔나

`chohk1003`의 커밋 `0d6a331` 한 개로 MP3(백엔드 동기화) 전체가 들어왔다. 핵심은 **기존 코드를 거의 안 고치고 저장소 계층만 갈아끼운 것**이다.

| 구분 | 내용 |
|---|---|
| 선택한 BaaS | Firebase — Authentication(이메일/비밀번호) + Cloud Firestore |
| 추가된 패키지 | `firebase_core ^5.1.0`, `firebase_auth ^7.0.1`, `cloud_firestore ^7.1.0` |
| 새 파일 (lib) | `data/firebase_env.dart`, `data/auth_service.dart`, `data/firestore_backend.dart`, `pages/account_page.dart` |
| 기존 파일 (MP2 때 이미 준비) | `data/task_store.dart`(인터페이스), `data/sync_store.dart`(병합 로직) |
| 설정 파일 | `.env.example`, `firestore.rules`, `.gitignore`에 `.env`·`google-services.json` 제외 |
| 동기화 대상 | **태스크만** (`users/{uid}/tasks`). 완료 기록(`doneLog`)·설정은 기기별 로컬 보관 |
| Firebase 없이 실행 | `.env`가 없으면 로그인 UI까지 비활성 → 기존과 똑같은 **로컬 전용 게스트 모드** (크래시 없음) |

핵심 설계 두 줄로:

1. **로컬 우선(local-first)** — 화면은 항상 로컬(`shared_preferences`)에서 읽는다. 서버가 느리거나 끊겨도 앱이 안 멈춘다.
2. **항목 단위 Last-Write-Wins** — 충돌은 `updatedAt`이 더 늦은 쪽이 이기고, 삭제는 지우지 않고 `deleted: true` 표식(tombstone)을 남긴다.

---

## 2. 계층 구조 — 어디에 끼워졌나

`AppState`는 `TaskStore`라는 **인터페이스만** 본다. 그래서 그 자리에 `LocalStore`를 넣으면 로컬 전용, `SyncStore`를 넣으면 동기화 모드가 된다. **`AppState`·화면 코드는 저장소 종류를 모른다.**

```mermaid
flowchart TD
    subgraph UI["화면 (pages / widgets)"]
        HS["HomeShell<br/>main · date · settings"]
        AC["AccountPage<br/>로그인 · 회원가입 · 로그아웃"]
    end

    AS["AppState<br/>state/app_state.dart<br/>· 상태 · 설정 · 250ms 디바운스 저장"]
    TS{{"TaskStore (인터페이스)<br/>data/task_store.dart"}}
    LS["LocalStore<br/>shared_preferences<br/>keepy.*.v2"]
    SS["SyncStore<br/>data/sync_store.dart<br/>로컬 우선 + 대기 큐 + LWW 병합"]
    SB{{"SyncBackend (인터페이스)"}}
    NB["NoopSyncBackend<br/>아무것도 안 함"]
    FB["FirestoreBackend<br/>data/firestore_backend.dart"]
    AUTH["AuthService<br/>data/auth_service.dart"]
    ENV["FirebaseEnv<br/>.env 설정값"]
    FS[("Cloud Firestore<br/>users/{uid}/tasks")]
    FA[("Firebase Auth")]

    HS --> AS
    AC --> AUTH
    AS --> TS
    TS -.->|".env 없음"| LS
    TS -.->|".env 있음"| SS
    SS --> LS
    SS --> SB
    SB -.-> NB
    SB -.-> FB
    FB <--> FS
    FB -->|"uid 감시"| FA
    AUTH --> FA
    ENV -->|"initializeApp options"| FB
    FB -->|"onRemoteTasks"| AS

    classDef new fill:#FF9F0A,stroke:#9c6100,color:#fff
    classDef iface fill:#5E5CE6,stroke:#3a38a8,color:#fff
    class FB,AUTH,ENV,AC,FS,FA new
    class TS,SB iface
```

주황 = 리베이스로 새로 들어온 것, 보라 = 갈아끼우기를 가능하게 하는 인터페이스.

### 파일별 역할

| 파일 | 줄 수 | 하는 일 |
|---|---:|---|
| `lib/data/firebase_env.dart` | 32 | `String.fromEnvironment`로 `.env` 값 4개를 읽어 `FirebaseOptions` 조립. 하나라도 비면 `configured == false` |
| `lib/data/auth_service.dart` | 81 | 이메일/비밀번호 로그인·가입·로그아웃. `ChangeNotifier`라 UI가 바로 따라감. 에러 코드를 한국어 문장으로 번역 |
| `lib/data/firestore_backend.dart` | 146 | `SyncBackend` 구현체. `users/{uid}/tasks` 읽기/쓰기/실시간 구독, Firestore 전용 필드 추가·제거 |
| `lib/data/sync_store.dart` | 243 | **Firebase 의존 없음.** 로컬 우선 쓰기, 대기 큐, `mergeTasks()` 순수 함수 LWW 병합 |
| `lib/data/task_store.dart` | 26 | `hasData`/`readTasks`/`readLog`/`readSettings`/`write` 5개짜리 저장소 계약 |
| `lib/pages/account_page.dart` | 269 | 로그인/회원가입 토글 폼, 로그인 후에는 이메일 + 로그아웃 버튼 |
| `firestore.rules` | 32 | 본인 문서만 접근 + **서버에서도 LWW 강제** + `delete` 금지 |

---

## 3. 앱 시작 흐름 (`main.dart`)

`.env` 유무가 모드를 가른다. 초기화가 실패해도 `catch`에서 `null`을 돌려주고 로컬 전용으로 계속 실행한다.

```mermaid
sequenceDiagram
    participant M as main()
    participant L as LocalStore
    participant E as FirebaseEnv
    participant F as Firebase
    participant S as SyncStore
    participant A as AppState

    M->>L: LocalStore.open()
    L->>L: v1 → v2 키 마이그레이션
    M->>E: configured?
    alt .env 없음 / 값 비어 있음
        E-->>M: false
        M->>A: AppState(store: local)
        Note over M,A: 게스트 — 이 기기에만 저장
    else .env 있음
        M->>F: Firebase.initializeApp(options)
        alt 초기화 실패
            F-->>M: 예외
            M->>A: AppState(store: local)
            Note over M,A: 로컬 전용으로 계속 (크래시 없음)
        else 성공
            M->>M: AuthService.init()
            M->>S: SyncStore(local, FirestoreBackend())
            M->>A: AppState(store: sync)
            M->>A: flush() — 첫 실행 샘플을 먼저 로컬에 저장
            M->>S: onRemoteTasks = state.applyRemote
            M->>S: start() — 실시간 구독 + uid 감시
        end
    end
```

`flush()`를 미리 부르는 이유: 첫 실행 샘플 7개는 메모리에만 있어서, 저장하지 않으면 로그인했을 때 서버로 올라가지 않는다.

---

## 4. 쓰기 경로 — 로컬 먼저, 서버 나중

`AppState`의 모든 변경은 `notifyListeners()` → 250ms 디바운스 → `flush()` → `store.write()`로 흐른다. `SyncStore.write()`는 **로컬을 먼저 끝낸 뒤** 서버로 보낸다.

```mermaid
flowchart TD
    U["사용자 조작<br/>추가 · 완료 · 수정 · 삭제"] --> N["AppState.notifyListeners()"]
    N --> R["화면 즉시 갱신"]
    N --> D["250ms 디바운스 타이머"]
    D --> FL["flush()"]
    FL --> W["SyncStore.write(tasks, log, settings)"]
    W --> LW["LocalStore.write — 먼저, 반드시"]
    LW --> C{"backend.canSync?<br/>(= 로그인했나)"}
    C -->|"아니오 (게스트)"| Q["대기 큐에 id 적립<br/>_pending"]
    C -->|"예"| P["FirestoreBackend.push()"]
    P --> K{"_known[id] == updatedAt?<br/>(서버에 이미 있는 버전)"}
    K -->|"같음"| SK["건너뜀 — 쓰기 횟수 절약"]
    K -->|"다름"| SET["doc(id).set(...)<br/>await 하지 않음"]
    SET --> OFF{"온라인?"}
    OFF -->|"예"| OK["즉시 반영"]
    OFF -->|"아니오"| SDK["Firestore SDK가 기기에 쌓아 둠<br/>앱을 껐다 켜도 유지 → 복귀 시 자동 전송"]

    classDef hot fill:#0A84FF,stroke:#0060df,color:#fff
    class LW,SDK hot
```

포인트 세 가지:

- **`set()`의 결과를 기다리지 않는다**(`unawaited`). 오프라인 큐는 Firestore SDK가 알아서 관리하므로 앱이 직접 네트워크 상태를 감시하지 않는다.
- **`_known` 맵**으로 "서버에 이미 올라간 버전"을 기억해 같은 값을 두 번 올리지 않는다. 업로드가 거절되면 `_known`에서 되돌려 다음에 다시 시도한다.
- **대기 큐(`_pending`)** 는 로그인 전(게스트)에 바뀐 id만 담는다. 로그인하면 `resync()`가 올리고 비운다.

---

## 5. 수신 경로와 충돌 해결 (LWW)

서버 변경은 두 길로 들어온다. ① 로그인 직후 `resync()`의 1회 `pullTasks()`, ② `snapshots()` 실시간 스트림. 둘 다 결국 `AppState.applyRemote()`에서 **항목 단위**로 병합된다.

```mermaid
flowchart TD
    FS[("Firestore<br/>users/{uid}/tasks")] -->|"snapshots()"| FB["FirestoreBackend<br/>_fromDoc: serverUpdatedAt·updatedAtMs 제거"]
    FB --> W["SyncStore._onRemote"]
    W --> AR["AppState.applyRemote(remote)"]
    AR --> L1{"로컬에 같은 id 있나?"}
    L1 -->|"없음"| ADD["목록에 추가<br/>(tombstone이어도 기록으로 남김)"]
    L1 -->|"있음"| L2{"서버 updatedAt이 더 최신?"}
    L2 -->|"예"| REP["기존 Task 객체의 필드만 교체<br/>title·done·due·doneAt·tags·deleted"]
    L2 -->|"아니오"| IG["무시 — 내가 더 최근에 고쳤다"]
    ADD --> NT["notifyListeners → 화면 갱신 + 로컬 저장"]
    REP --> NT

    classDef warn fill:#FF9F0A,stroke:#9c6100,color:#fff
    class REP warn
```

`applyRemote`가 **객체를 바꿔치기하지 않고 필드만 수정**하는 게 중요하다. 편집 시트 같은 화면이 같은 `Task` 객체를 들고 있어서, 새 객체로 교체하면 화면과 데이터가 어긋난다.

### 로그인 직후 순서 (`SyncStore.resync`)

```mermaid
sequenceDiagram
    participant A as AuthService / Auth 상태
    participant FB as FirestoreBackend
    participant SS as SyncStore
    participant L as LocalStore
    participant FS as Firestore

    A->>FB: authStateChanges → uid
    FB->>SS: uidChanges.add(uid)
    SS->>FS: ① pullTasks() — 먼저 받는다
    FS-->>SS: 서버 목록
    SS->>SS: ② mergeTasks(local, remote, pending)
    SS->>L: ③ 병합 결과 로컬 저장
    SS->>SS: ④ onRemoteTasks → AppState.applyRemote (화면 갱신)
    SS->>FS: ⑤ 병합 결과 push — 내 쪽이 더 최신인 것만
    Note over SS,FS: 순서가 중요: 먼저 올리면 이 기기의<br/>오래된 값이 다른 기기의 최신 수정을 덮어쓴다
```

### 삭제는 tombstone

```mermaid
stateDiagram-v2
    [*] --> 보임: 할 일 추가
    보임 --> 숨김: remove() — deleted=true, updatedAt 갱신
    숨김 --> 보임: restore(index, task) — 되돌리기
    숨김 --> 숨김: 다른 기기도 deleted 수신 → 숨김
    note right of 숨김
        문서를 지우지 않는다.
        지우면 오프라인 기기에
        "삭제됨"이 전달되지 않고
        옛 데이터로 되살아난다.
    end note
```

`AppState._live`가 `deleted` 항목을 전부 걸러서 화면·캘린더·집계에 안 보이게 한다. **목록 조회는 반드시 `_live`를 거쳐야 한다**(빠뜨리면 지운 항목이 남는다). 저장·동기화는 tombstone까지 포함한 `_tasks`를 쓴다.

---

## 6. Firestore 문서 구조와 보안 규칙

```
users/{uid}/tasks/{taskId}
```

문서 필드 = `Task.toJson()` 그대로 + 서버용 2개:

```json
{
  "id": "m3x9k2p0",
  "title": "운영체제 과제",
  "done": false,
  "due": "2026-11-03T00:00:00.000",
  "tags": ["assignment", "team"],
  "createdAt": "2026-11-02T21:40:12.000",
  "doneAt": null,
  "updatedAt": "2026-11-03T10:12:00.000",
  "deleted": false,

  "updatedAtMs": 1762146720000,
  "serverUpdatedAt": "<서버 타임스탬프>"
}
```

- `updatedAtMs` — 정수. **보안 규칙이 LWW를 비교할 때** 쓴다(문자열 ISO로는 규칙에서 비교가 안 된다).
- `serverUpdatedAt` — 콘솔에서 보기 좋게 남기는 서버 시각.
- 둘 다 읽을 때(`_fromDoc`) 제거한다. `Timestamp` 객체가 남으면 로컬 JSON 저장이 깨진다.

`firestore.rules`가 **클라이언트를 믿지 않고 서버에서도 같은 규칙을 강제**한다:

```mermaid
flowchart LR
    REQ["쓰기 요청"] --> O{"request.auth.uid == {uid}?"}
    O -->|"아니오"| X1["거절"]
    O -->|"예"| V{"title is string ≤300자<br/>updatedAtMs is int<br/>deleted is bool"}
    V -->|"아니오"| X2["거절"]
    V -->|"예"| T{"update인가?"}
    T -->|"create"| OK1["허용"]
    T -->|"update"| M{"새 updatedAtMs ≥ 기존 값?"}
    M -->|"예"| OK2["허용"]
    M -->|"아니오"| X3["거절 — 옛 버전이 최신을 덮어쓰는 것 차단"]
    DEL["delete 요청"] --> X4["항상 거절 (tombstone만 허용)"]

    classDef no fill:#FF375F,stroke:#a3002c,color:#fff
    class X1,X2,X3,X4 no
```

---

## 7. 로그인 UX

```mermaid
stateDiagram-v2
    [*] --> 설정없음: .env 없이 실행
    설정없음 --> 설정없음: 계정 행 탭 → 토스트<br/>"Firebase 설정(.env)이 없어 이 기기에만 저장돼요"

    [*] --> 게스트: .env 있고 미로그인
    게스트 --> 계정화면: 설정 맨 위 계정 행 탭
    계정화면 --> 게스트: 뒤로
    계정화면 --> 로그인됨: 로그인 / 가입 성공
    로그인됨 --> 동기화: resync — 받고 병합한 뒤 올림
    동기화 --> 로그인됨
    로그인됨 --> 게스트: 로그아웃<br/>(이 기기 목록은 남고 동기화만 멈춤)
    로그인됨 --> 로그인됨: 앱 재시작 — 세션 복원
```

- 설정 화면 맨 위 `_AccountRow`가 `AuthService.instance`의 상태에 따라 문구를 바꾼다: `게스트 / 이 기기에만 저장 · 동기화 꺼짐` → `이메일 / 동기화 켜짐`.
- **익명 로그인을 쓰지 않은 이유**: 기기마다 다른 사용자가 되어 "두 기기에서 같은 목록"이 성립하지 않는다.
- 게스트로 쌓은 할 일은 로그인 시 `_pending` + `resync()`로 계정에 합쳐진다.

---

## 8. Firebase 없이도 테스트되는 구조

`sync_store.dart`가 **Firebase 패키지를 import하지 않는다**는 점이 테스트 설계의 핵심이다. `test/sync_test.dart`는 `_MemStore`(메모리 저장소) + `_FakeBackend`(메모리 서버)로 동기화 시나리오를 돌린다.

```mermaid
flowchart LR
    T["test/sync_test.dart<br/>9 tests"] --> SS["SyncStore<br/>(실제 코드)"]
    SS --> MS["_MemStore<br/>TaskStore 구현"]
    SS --> FBK["_FakeBackend<br/>SyncBackend 구현<br/>login/logout/remoteEdit"]
    SS -.->|"의존 없음"| NOFB["firebase_* 패키지"]

    classDef gray fill:#8E8E93,stroke:#48484a,color:#fff,stroke-dasharray: 4 3
    class NOFB gray
```

현재 테스트: `app_state_test.dart` 46건, `task_model_test.dart` 12건, `sync_test.dart` 9건, `local_store_test.dart` 7건, `widget_test.dart` 2건.

---

## 9. 리베이스 후 확인해야 할 것

분석 중에 나온, 지금 상태에서 **비어 있거나 어긋난 부분**이다.

| # | 항목 | 상태 |
|---|---|---|
| 1 | `pubspec.lock`, `windows/flutter/generated_plugin*` 미커밋 변경 | `flutter pub get`이 Firebase 3종을 반영한 결과. 커밋할지 결정 필요 |
| 2 | `docs/MP3_따라하기.md` **없음** | `README.md:15`·`README.md`(백엔드 설정 절차 절)·`docs/firebase.md` 상단이 이 파일을 가리키는데 어떤 커밋에도 존재하지 않는다 (링크 깨짐) |
| 3 | `docs/auth.md` 내용이 옛것 | "🔴 미착수 — 진입점만 있음"이라고 써 있지만 `AuthService`·`AccountPage`가 이미 구현돼 있다 |
| 4 | `docs/STATUS.md` 내용이 옛것 | 로그인 🔴, Firebase 🟡 "연결만 남음" — 실제로는 연결 코드까지 들어왔다 |
| 5 | `.env` 실제 값 | `.env.example`만 있다. 실행에는 Firebase 콘솔 값이 담긴 `.env`가 필요하고, 없으면 게스트 모드로만 돈다 |
| 6 | NFR-03 / NFR-04 측정값 | README 표가 "_측정 후 기록_" 상태. 두 기기 동기화 3초, 오프라인 복귀 5초 실측이 남아 있다 |
| 7 | `doneLog` · `settings` 동기화 | `SyncBackend.push()`는 `log`·`settings`를 인자로 받지만 `FirestoreBackend`는 **쓰지 않고 버린다**. 설계상 "기기별 보관"이라 의도된 것이지만, 인자로 남아 있어 오해 소지가 있다 |
| 8 | tombstone 정리 | 오래된 `deleted: true` 문서를 지우는 로직이 없다 (`docs/firebase.md`에도 미완 항목으로 적혀 있음) |
| 9 | `android/app/google-services.json` 없음 | `.gitignore`에 들어 있고, 설정은 `--dart-define`으로 넘기므로 현재 방식에선 필수는 아니다 |

---

## 10. 한눈에 보는 실행 방법

```bash
flutter run --dart-define-from-file=.env
```

```bash
flutter run
```

위가 동기화 모드(`.env` 필요), 아래가 로컬 전용 게스트 모드. 보안 규칙은 Firebase 콘솔 → Firestore Database → 규칙 탭에 `firestore.rules` 내용을 붙여 넣고 게시해야 적용된다.
