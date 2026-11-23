# Keepy 단계별 정리 — 미니프로젝트 1 · 2 · 3단계

> 주제 #2109 할 일 앱 – BaaS, AI 활용. 같은 앱(Keepy)을 단계마다 키워 왔습니다.
> 각 단계는 **앞 단계를 깨지 않고 그 위에 얹는** 방식이라, 3단계 앱도 로그인하지 않으면 2단계와 똑같이 동작합니다.

| 단계 | 이름 | 핵심 질문 | 결과 | 앱 버전 |
|---|---|---|---|---|
| **MP1** | 할 일 앱 화면 만들기 | 목록·입력·완료가 화면에서 도는가? | 메인 목록, 입력 바, 완료 토글, 빈 상태 안내 | 0.2.0 |
| **MP2** | 저장되는 앱으로 만들기 | 껐다 켜도 남는가? 고치고 지우고 거를 수 있는가? | 기기 저장(shared_preferences), 수정·삭제·필터 | 0.2.0 ~ 0.5.0 |
| **MP3** | 백엔드 서비스로 동기화하기 | 두 기기가 같은 목록을 보는가? 오프라인에서 쓴 것도 올라가는가? | Supabase 로그인·동기화·충돌 처리·오프라인 대기열 | **0.6.0** |

---

## 한눈에 보는 구조

```
                ┌──────────────────────── 화면 (ui/) ────────────────────────┐
                │ 설정 ← 메인 → 날짜   +  수정 시트 · 태그 관리 · 계정·동기화(MP3) │
                └───────────────┬───────────────────────────┬────────────────┘
                                │ 읽기·변경 요청              │ 상태 표시
                  ┌─────────────▼─────────────┐   ┌─────────▼──────────┐
   MP1 ─────────► │ TaskStore (state/)         │◄──│ SyncController     │ ◄── MP3
                  │  할 일 상태의 단일 출처     │   │  변경 감지·당겨오기  │
                  └─────────────┬─────────────┘   │  ·올리기·충돌 처리    │
                                │ 저장              └───┬──────────┬─────┘
                  ┌─────────────▼─────────────┐       │ 장부      │ HTTPS
   MP2 ─────────► │ TaskRepository (data/)     │  ┌────▼─────┐ ┌──▼──────────────┐
                  │  shared_preferences JSON    │  │ 기기 저장  │ │ Supabase         │
                  └────────────────────────────┘  │ (대기열)   │ │ Auth + keepy_tasks│
                                                   └──────────┘ └──────────────────┘
```

- **화면은 저장 방식을 모른다** — 화면은 `TaskStore` 만 보고, `TaskStore` 는 `TaskRepository` 계약만 안다 (MP2 설계).
- **동기화는 옆에 붙는다** — `SyncController` 는 `TaskStore` 의 변경을 지켜보다가 서버와 주고받고, 받은 변경은
  `TaskStore.applyRemote` 한 곳으로만 넣는다. 그래서 1·2단계 코드를 고치지 않고 3단계를 얹을 수 있었다 (MP3).

---

## MP1 — 할 일 앱 화면 만들기

### 목표와 통과 기준
| 통과 기준 | 결과 |
|---|---|
| 항목 추가와 완료 토글이 동작한다 | ✅ 입력 바 → 목록, 체크박스 → 완료 구역 |
| 빈 상태에서 안내 화면이 표시된다 | ✅ "등록된 태스크가 없습니다 / 기억하고 싶은 할 일이 있나요? / 아래에서 첫 태스크를 추가해 보세요" |
| README 에 실행 절차·기능 목록, prompts_log.md 기록 | ✅ |

### 구현
| 기능 | 내용 | 파일 |
|---|---|---|
| 목록 | 지연 → 해야 할 일 → 완료한 일 순, 개수 배지 | `ui/pages/main_page.dart` |
| 입력 | 하단 고정 입력 바, 공백 제외 1~100자만, 빈 입력은 흔들림 + 안내 | `ui/widgets/quick_input_bar.dart`, `models/task.dart`(`TitleRule`) |
| 완료 토글 | 둥근 네모 체크 → 취소선 → 완료 구역, 0.6초 '취소' 알림 | `ui/widgets/task_tile.dart`, `ui/widgets/undo_toast.dart` |
| 상태 관리 | `TaskStore`(ChangeNotifier) 한곳에서 변경 → `ListenableBuilder` 로 즉시 반영 | `state/task_store.dart`, `state/keepy_scope.dart` |
| 화면 구조 | 3단 좌우 화면(설정 · 메인 · 날짜) + 하단 탭 바, iOS 느낌 | `ui/shell/home_shell.dart`, `core/theme.dart` |

### 검증
위젯 테스트 '처음 켜면 빈 상태 안내', '입력 바로 할 일을 추가' · 스크린샷 `mp1_01`~`mp1_05`

---

## MP2 — 저장되는 앱으로 만들기

### 목표와 통과 기준
| 통과 기준 | 결과 |
|---|---|
| 수정·삭제·필터가 모두 동작한다 | ✅ 수정 시트, 밀어서 삭제, 전체/미완료/완료 탭 |
| 앱 재시작 후에도 데이터가 유지된다 | ✅ 변경 직후 저장, 시작 시 불러오기 |
| README 에 저장 방식 선택 이유가 대안 비교와 함께 있다 | ✅ README 10절 (shared_preferences vs sqflite·Hive/Isar·drift·JSON 파일) |

### 구현
| 기능 | 내용 | 파일 |
|---|---|---|
| 기기 저장 | 모든 변경 직후 JSON 저장(순서대로 이어 붙여 덮어쓰기 방지), 깨진 값은 백업 키에 보관 | `data/local_repositories.dart`, `TaskStore._commit` |
| 수정 | 제목·태그·기한(빠른 칩 + 한 달 달력) | `ui/widgets/task_editor_sheet.dart`, `ui/widgets/mini_calendar.dart` |
| 삭제 | → 밀어 삭제 버튼 / 세게 밀어 즉시 삭제 / 시트의 휴지통, '취소' 가능 | `ui/widgets/task_tile.dart`, `ui/widgets/task_actions.dart` |
| 필터 | 전체/미완료/완료 탭 + 실시간 개수 | `ui/pages/main_page.dart` |
| 저장 계약 | 화면은 `TaskRepository` 계약만 사용 → 저장 방식을 바꿔도 화면은 그대로 | `data/repositories.dart` |

### 2단계에서 덧붙인 것 (v0.3 ~ v0.5)
날짜 화면·한 달 캘린더, ← 당겨 +1/+2/+7일, 편집 모드 순서 바꾸기, 태그 관리, 다크 모드, 카메라 OCR,
미니게임(계단 오르기 → v0.7 에서 **오리 수영장**으로 교체), 오늘 요약 카드, 완료한 일 접기·비우기, v0.7 **오늘 통계** — [README_KEEPY.md](../README_KEEPY.md) 참고.

### 저장 구조
| 키 | 내용 |
|---|---|
| `keepy.tasks.v1` | 할 일 JSON 배열 — `id, title, done, createdAt, completedAt, due, tags, completedLate, updatedAt, order` |
| `keepy.settings.v1` | 설정 JSON — 화면 모드, 알림, 달력, 지연 기준, 태그, 오리 수영장 켜기(`miniGameEnabled`) |

### 검증
`task_store_test.dart`(추가·수정·삭제·되돌리기·정렬·태그), `task_status_test.dart`(지연 판정·JSON 왕복),
위젯 테스트 '완료·미완료 탭', 저장 테스트 '다시 불러와도 그대로' · PC `flutter run -d chrome` 실행 확인 · 스크린샷 `mp2_01`~`mp2_07`

---

## MP3 — 백엔드 서비스로 동기화하기

### 목표와 통과 기준
| 통과 기준 | 결과 | 근거 |
|---|---|---|
| 1. 기기 A 에서 추가한 할 일이 기기 B 새로고침 후 표시된다 | ✅ (실서버 확인 ⏳) | `sync_test.dart` · `mp3_01/02` |
| 2. 오프라인 작성 항목이 온라인 복귀 후 서버에 반영된다 | ✅ (실서버 확인 ⏳) | `sync_test.dart` · `mp3_03/04` |
| 3. README 에 동기화 충돌 처리 방침이 기술되어 있다 | ✅ | README 4절 |
| 4. 설정 키 하드코딩 없음, `.env.example` 만 제출 | ✅ | README 6절, `core/env.dart` |

### 선택: Supabase (REST 직접 호출)
Firebase 와 비교해 **서버 트리거로 충돌 규칙을 DB 가 보장**하고, **`http` 패키지 하나**로 붙어 1·2단계의 OCR·이미지
패키지와 플랫폼 설정을 건드리지 않으며, **웹에서도 같은 코드**로 두 기기를 재현할 수 있어서 골랐다 (README 2절).

### 구현
| 부분 | 내용 | 파일 |
|---|---|---|
| 설정 키 | 실행 시 `--dart-define-from-file=.env` → `String.fromEnvironment`. 값이 없으면 동기화 꺼짐(2단계와 같음) | `core/env.dart`, `app/.env.example` |
| 서버 통신 | 인증(가입·로그인·토큰 갱신), 새로 온 줄 받기, 여러 줄 올리기. 오류를 오프라인·인증·서버로 나눠 한국어 안내 | `services/sync/supabase_backend.dart`, `services/sync/sync_backend.dart` |
| 동기화 장부 | 할 일별 `updatedAt·dirty(올릴 변경)·deleted(삭제 표시)·json` + 서버 커서. 기기에 저장 → **오프라인 대기열** | `services/sync/sync_ledger.dart` |
| 동기화 흐름 | ① 변경 감지 → ② 당겨오기(synced_at 이후만) → ③ 올리기. 앱 시작·복귀·변경 1.2초 뒤·20초마다·버튼, 오프라인이면 10초마다 재시도 | `state/sync_controller.dart` |
| 충돌 처리 | 할 일 단위 마지막 수정 우선 + 삭제 표시 + 로그인 시 할 일의 수정 시각으로 합치기 | `SyncController._applyRemoteRows`, `app/supabase/schema.sql` 트리거 |
| 받은 변경 반영 | 서버 변경은 한 곳으로만 넣고 다시 올리지 않음 | `TaskStore.applyRemote` |
| 서버 | `keepy_tasks` 표, RLS 정책 3개(자기 줄만), 오래된 쓰기 무시 트리거, DELETE 차단 | `app/supabase/schema.sql` |
| 화면 | 계정 · 동기화 시트(가입/로그인/로그아웃, 상태·마지막 동기화·올릴 변경 수·지금 동기화), 메인 ☁ 배지, 설정 계정 줄 | `ui/pages/account_sheet.dart`, `main_page.dart`, `settings_page.dart` |
| 플랫폼 | 안드로이드 정식 빌드용 인터넷 권한을 설정 스크립트가 추가 | `tool/setup_platforms.ps1`, `.sh` |

### 동기화 한 번의 흐름

```
syncNow()
 ├─ 변경 감지: 할 일 목록 vs 장부 → 새로 생김·바뀜·사라짐 = dirty
 ├─ 당겨오기: GET keepy_tasks?synced_at=gt.(커서-3초)&order=synced_at.asc
 │    └─ 줄마다: 내 dirty 가 더 최신이면 건너뜀 / 같은 버전이면 건너뜀 / 아니면 반영(삭제 표시면 지움)
 ├─ 올리기:   POST keepy_tasks?on_conflict=user_id,id (merge-duplicates)
 │    └─ 서버 트리거: updated_at 이 더 오래되면 무시, 아니면 synced_at = 지금
 └─ 결과: idle(✓) / offline(대기열 유지, 10초 뒤 재시도) / error(안내) / 인증 만료(로그아웃 + 안내)
```

### 검증
| 방법 | 내용 |
|---|---|
| 동기화 테스트 11개 (`test/sync_test.dart`) | 실서버와 같은 규칙의 가짜 서버로: A 추가 → B 표시, 오프라인 대기열 → 복귀 반영, 앱 재시작 후 대기열 유지, 수정·완료·삭제 전파, LWW 충돌, 삭제 vs 나중 수정, 받은 변경 재전송 없음, 로그인 시 합치기, 잘못된 비밀번호, 로그아웃 후 데이터 유지, 설정 없음 |
| PostgreSQL 16 에서 SQL 실행 | 두 번 실행해도 안전 · 오래된 쓰기 무시 · 다른 사용자 줄 안 보임 · 남의 user_id 로 쓰기 차단 · DELETE 거부 |
| 실서버 (⏳) | [MP3_실행_매뉴얼.md](MP3_실행_매뉴얼.md) 6~7단계, 스크린샷 `mp3_01`~`mp3_05` |

---

## 단계별 파일 지도

| 폴더 / 파일 | MP1 | MP2 | MP3 |
|---|:-:|:-:|:-:|
| `lib/models/task.dart` (할 일·제목 규칙·JSON) | ● | ● (`updatedAt`, `order`) | |
| `lib/state/task_store.dart` | ● | ● (저장 연결) | ● (`applyRemote`) |
| `lib/data/` (저장 계약·구현) | | ● | |
| `lib/core/env.dart` | | | ● |
| `lib/services/sync/` | | | ● |
| `lib/state/sync_controller.dart` | | | ● |
| `lib/ui/pages/main_page.dart` | ● | ● (필터) | ● (☁ 배지) |
| `lib/ui/pages/settings_page.dart` | | ● | ● (계정 줄) |
| `lib/ui/pages/account_sheet.dart` | | | ● |
| `lib/ui/widgets/task_editor_sheet.dart` | | ● | |
| `app/supabase/schema.sql` | | | ● |
| `app/.env.example` | | ● (자리만) | ● (실제 사용) |
| `test/widget_test.dart` | ● | ● | |
| `test/task_store_test.dart`, `task_status_test.dart` | | ● | |
| `test/sync_test.dart` | | | ● |

## 테스트 현황

| 파일 | 개수 | 다루는 것 |
|---|---:|---|
| `widget_test.dart` | 11 | 빈 상태, 추가, 필터, 수정 시트, 다크 모드, 오리 수영장(열기·단계·탭 이동), 오늘 통계 펼치기, 오늘 요약·비우기 |
| `task_store_test.dart` | 15 | 추가·수정·삭제·되돌리기·정렬·순서·태그·월 통계·오늘 요약·오늘의 할 일·오늘 태그 통계 |
| `task_status_test.dart` | 10 | 지연·늦은 완료 판정, 제목·태그 규칙, JSON 왕복 |
| `sync_test.dart` | 11 | 두 기기·오프라인·재시작·충돌·로그인 합치기 (MP3) |
| `ocr_split_test.dart` | 2 | 메모 사진 글자 → 할 일 나누기 |
| `motion_safety_test.dart` | 2 | 그림자 애니메이션 안전 |
| **합계** | **51** | `flutter test` (v0.7: 미니게임 그림 테스트 6개 삭제, 수영장·통계 5개 추가) |

## 단계별 산출물

| 산출물 | MP1 | MP2 | MP3 |
|---|---|---|---|
| `app/` | 화면 | + 저장·CRUD·필터 | + 서버 동기화 |
| `README.md` | 실행 절차·기능 | + 저장 방식 비교 | + BaaS 선택 이유·충돌 처리 방침·백엔드 설정·실행 절차 (지금 README) |
| `screenshots/` | `mp1_*` | `mp2_*` | `mp3_*` (기기 A·B, 오프라인→온라인, 콘솔) |
| `prompts_log.md` | 1~13 | 14~33 | 34~ |
| 그 밖 | | | `.env.example`, `app/supabase/schema.sql`, `docs/MP3_실행_매뉴얼.md` |
