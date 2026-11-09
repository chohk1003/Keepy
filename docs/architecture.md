# 전체 구조

> 🟢 구현 완료 · 패턴: `ChangeNotifier` + `InheritedNotifier` (외부 상태관리 패키지 없음)

## 할 일

- [ ] `AppState`에 **저장된 JSON에서 목록을 다시 읽는 수단**이 없다 — 서버에서 병합된 결과를
    화면에 반영하려면 필요하다 (`SyncStore.onRemoteTasks`에 연결할 자리, [firebase.md](firebase.md))

## 레이어

```mermaid
flowchart TD
    subgraph UI["화면 (lib/pages, lib/widgets)"]
        HS[home_shell]
        PG[main · date · settings · ocr]
        WG[task_tile · week_calendar · quick_input_bar ...]
    end

    subgraph STATE["상태 (lib/state)"]
        AS["AppState<br/>ChangeNotifier"]
        SC["AppScope<br/>InheritedNotifier"]
    end

    subgraph DATA["데이터 (lib/data, lib/models)"]
        TS["TaskStore<br/>저장소 공통 계약"]
        LS["LocalStore<br/>shared_preferences"]
        MD["Task · TaskTag · DoneEvent"]
    end

    subgraph SHARED["공용 (lib/theme.dart, lib/util)"]
        TH["theme.dart<br/>K · Motion · T"]
        DT["dates.dart"]
    end

    UI -->|읽기 AppScope.of / 쓰기 AppScope.read| SC
    SC --- AS
    AS -->|JSON| TS
    TS --- LS
    AS --> MD
    UI -.색·모션 토큰.-> TH
    UI -.날짜 포맷.-> DT
    AS -.날짜 계산.-> DT

    SS["SyncStore<br/>TaskStore 구현 · 스켈레톤"]
    FB["FirestoreBackend<br/>(MP3 2라운드)"]:::todo
    TS --- SS
    SS -.-> LS
    SS -.->|원격| FB

    classDef todo fill:#8E8E93,stroke:#48484a,color:#fff,stroke-dasharray: 4 3
```

**의존 방향은 한쪽으로만** — 화면 → 상태 → 데이터. 데이터 계층은 화면을 모른다.

## 앱 시작

```mermaid
sequenceDiagram
    participant M as main()
    participant LS as LocalStore
    participant AS as AppState
    participant UI as HomeShell

    M->>M: WidgetsFlutterBinding.ensureInitialized()
    M->>M: 상태바 스타일 지정
    M->>LS: open() — SharedPreferences 획득
    LS-->>M: store
    M->>AS: AppState(store: store)
    alt 저장된 데이터 있음
        AS->>LS: readTasks / readLog / readSettings
        LS-->>AS: JSON
    else 첫 실행
        AS->>AS: _seed() — 샘플 7개
    end
    AS->>AS: 1분 타이머 시작 (지연 상태 갱신)
    M->>UI: runApp(KeepyApp) → AppScope → MaterialApp → HomeShell
```

## 상태 전파와 저장

```mermaid
sequenceDiagram
    participant W as 위젯
    participant AS as AppState
    participant T as 타이머(250ms)
    participant LS as LocalStore

    W->>AS: add / setDone / update / remove
    AS->>AS: notifyListeners() 재정의
    AS-->>W: AppScope 구독 위젯 리빌드
    AS->>T: 기존 타이머 취소 후 재시작
    Note over T: 연속 변경은 마지막 1회만 저장
    T->>AS: flush()
    AS->>LS: write(tasks, log, settings)
```

`notifyListeners()`를 **오버라이드해서 저장을 걸어 둔 것**이 이 구조의 핵심. 화면 코드는 저장을 신경 쓰지 않는다.

## 구현 위치

| 파일 | 역할 |
|---|---|
| `lib/main.dart` | 진입점, 저장소 open, `MaterialApp`, iOS식 스크롤(`_AppleScroll`) |
| `lib/state/app_state.dart` | `AppState` — 태스크·설정·화면 상태 전부. `AppScope` 주입 |
| `lib/data/task_store.dart` | `TaskStore` — `AppState`가 보는 저장소 계약 |
| `lib/data/local_store.dart` | `LocalStore` — JSON 읽기/쓰기 + v1 → v2 마이그레이션 |
| `lib/data/sync_store.dart` | `SyncStore` · `SyncBackend` — 동기화 계층 스켈레톤 (MP3) |
| `lib/models/task.dart` | `Task` · `TaskTag` · `DoneEvent` + JSON 변환 |
| `lib/theme.dart` | 색(`K`)·모션(`Motion`)·타이포(`T`) 토큰. **화면 파일에 색 직접 쓰지 않기** |
| `lib/util/dates.dart` | 날짜 계산·한국어 포맷 |

## 규칙

- 화면에서 상태를 **읽을 때** `AppScope.of(context)` (리빌드 구독), **콜백 안에서 쓸 때** `AppScope.read(context)`
- 색·애니메이션 시간은 `theme.dart`에서만 가져온다
- `Motion.spring`은 1을 넘어 튀는 곡선 → **그림자·투명도 보간에 쓰면 예외 발생**. 그런 곳은 `Motion.out`

## 완료된 것

- [x] 저장소를 `TaskStore` 인터페이스로 분리 — `AppState`를 고치지 않고 동기화 계층 교체 가능 (2026-11-09)
- [x] 레이어 분리와 단방향 의존 (2026-11-02)
- [x] 디바운스 자동 저장 + 앱 일시정지 시 즉시 저장 (2026-11-03)
- [x] 1분 주기 리빌드로 '지연' 상태 자동 반영 (2026-11-03)
