# 수정·추가 가이드

"이걸 바꾸고 싶다" → "이 파일을 열면 된다" 표입니다. 고친 뒤에는 `flutter analyze` 와 `flutter test` 를 돌리고,
웹 미리보기(`preview/index.html`)도 같이 맞춰 두면 팀원이 브라우저로 바로 확인할 수 있습니다.

## 자주 바꿀 것

| 바꾸고 싶은 것 | 파일 | 찾을 이름 |
|---|---|---|
| 색·그라데이션 | `app/lib/core/theme.dart` | `KeepyColors`, `KeepyGradients` |
| 캘린더 완료 농도 색 | `app/lib/core/theme.dart` | `KeepyColors.heat` |
| 애니메이션 속도 | `app/lib/core/theme.dart` | `KeepyMotion` (NFR-01: 0.3초 이내 유지) |
| 글자 크기 | `app/lib/core/theme.dart` | `KeepyText` |
| 처음 설치 시 기본 태그 | `app/lib/models/task.dart` | `defaultTags` (설치 뒤에는 앱의 태그 관리에서) |
| 제목 길이 제한 | `app/lib/models/task.dart` | `TitleRule.maxLength` |
| 지연 판정 규칙 | `app/lib/models/task_status.dart` | `isDelayed` |
| 정렬 순서 | `app/lib/state/task_store.dart` | `sorted` |
| 알림(되돌리기) 시간 0.6초 | `app/lib/ui/widgets/undo_toast.dart` | `ToastController(visibleFor:)` |
| ← 당기기 날짜 단계 (+1/+2/+7) | `app/lib/ui/widgets/task_tile.dart` | `TaskTile.dateStops` (예: 1~7 전부 `[1,2,3,4,5,6,7]`) |
| 단계 사이 거리·첫 단계 거리 | `app/lib/ui/widgets/task_tile.dart` | `_firstStop`, `_stopSpacing`, `_visualFor` |
| 아래로 내려 취소하는 거리 | `app/lib/ui/widgets/task_tile.dart` | `_cancelDown` |
| 삭제 버튼 폭·걸림 | `app/lib/ui/widgets/task_tile.dart` | `_deleteWidth`, `_snapIn` |
| 글꼴 | `app/pubspec.yaml` fonts + `app/lib/core/theme.dart` | `KeepyText.family` |
| 다크 모드 색 | `app/lib/core/theme.dart` | `KeepyColors` 의 `_d ? 다크 : 라이트` 값 (강조색은 공통 const) |
| 빠른 날짜 칩(오늘·내일·모레·다음 주) | `app/lib/ui/widgets/mini_calendar.dart` | `QuickDatePicker.build` 의 `quick` 목록 |
| 미니게임 캐릭터·펫 그림 | `app/lib/game/pixel_art.dart` | `boySprite`, `girlSprite`, `dogSprite` … (문자 지도) |
| 펫 종류 추가 | `app/lib/models/app_settings.dart` + `pixel_art.dart` + `stair_game_page.dart` | `PetKind`, `petSpriteOf` |
| 태그 이름 길이·최대 개수 | `app/lib/models/task.dart` | `TagRule.maxLength`, `maxCount` |
| 한 달 펼침 최대 높이(62%) | `app/lib/ui/pages/date_page.dart` | `full = …` |
| 미니게임 계단에 셀 할 일 범위 | `app/lib/state/task_store.dart` | `monthStat` |
| 칸 최소 폭 (넓히면 캐릭터도 커짐) | `app/lib/ui/game/stair_game_page.dart` | `StairPainter.minStepWithPet`, `minStepAlone` |
| 캐릭터·펫 크기와 둘 사이 간격 | `app/lib/ui/game/stair_game_page.dart` | `StairPainter.paint` 의 `cs`, `ps`, `gap` |
| 오늘 요약 카드 숫자·이동 | `app/lib/state/task_store.dart`, `app/lib/ui/pages/main_page.dart` | `dueTodayOpenCount` 등, `_TodaySummary` |
| 완료한 일 비우기·되돌리기 | `app/lib/state/task_store.dart`, `app/lib/ui/widgets/task_actions.dart` | `removeDone`, `restoreAll`, `clearDone` |
| 카드 테두리 농도 | `app/lib/core/theme.dart` | `KeepyColors.hairline` |
| 미니게임 격려 문구 | `app/lib/ui/game/stair_game_page.dart` | `_MessageCard.encouragement` |
| 캐릭터 해상도(24×24)·색 수 | `app/lib/models/app_settings.dart`, `app/lib/game/pixel_art.dart` | `characterSize`, `pixelate(colors:)` |
| 기본 캐릭터 그림 | `app/lib/game/pixel_art.dart` | `defaultSprite` (16줄 문자 지도) |
| 날짜 이동 임계값(70px) | `app/lib/ui/pages/date_page.dart` | `DatePage.pullThreshold` |
| 하단 사라짐 영역 높이 | `app/lib/ui/shell/home_shell.dart` | `HomeShell.fadeZone` |
| 설정 항목 추가 | `app/lib/models/app_settings.dart` + `app/lib/ui/pages/settings_page.dart` | 필드 → `copyWith/toJson/fromJson` → 화면 `_Row` |
| 샘플 데이터 | `app/lib/state/task_store.dart` | `addSamples` |

## 기능을 새로 붙일 때

**새 할 일 속성 (예: 메모, 우선순위)**
1. `Task` 에 필드 + `copyWith` + `toJson/fromJson` (없는 값은 기본값으로 — 예전 저장 데이터도 읽히게)
2. `TaskStore.update` 에 인자 추가
3. 수정 시트 `task_editor_sheet.dart`, 필요하면 블럭 `_metaWidgets`
4. `app/test/task_status_test.dart` JSON 왕복 테스트에 추가

**서버 동기화 (MP3, FR-01/11/12) — 이미 구현됨, 고칠 곳**
| 바꾸고 싶은 것 | 파일 | 위치 |
|---|---|---|
| 자동 동기화 간격 (20초 / 오프라인 재시도 10초 / 변경 후 1.2초) | `app/lib/state/sync_controller.dart` | 생성자 `pollInterval`, `retryInterval`, `debounce` |
| 충돌 규칙 (지금: 할 일 단위 마지막 수정 우선) | `sync_controller.dart` + `app/supabase/schema.sql` | `_applyRemoteRows`, 트리거 `keepy_tasks_lww` — 둘을 같이 바꾸고 `test/sync_test.dart` 도 |
| 서버 주소·키 | `app/.env` (코드 아님) | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| 다른 BaaS 로 바꾸기 (Firebase 등) | `app/lib/services/sync/` | `SyncBackend` 계약을 구현한 클래스 하나 + `main.dart` 에서 교체 |
| 오류 안내 문구 | `services/sync/supabase_backend.dart` | `_check`, `_authMessage` |
| 계정 화면 | `app/lib/ui/pages/account_sheet.dart` | |
| 메인 ☁ 배지 | `app/lib/ui/pages/main_page.dart` | `_SyncBadge` |
| 서버 표·보안 규칙 | `app/supabase/schema.sql` | 고친 뒤 SQL Editor 에서 다시 Run (여러 번 실행해도 안전) |

주의: 서버에서 받은 변경은 `TaskStore.applyRemote` 로만 넣는다. 다른 메서드로 넣으면 '내 변경' 으로 보고 다시 올라간다.

**푸시 알림**
`flutter_local_notifications` 추가 → `AppSettings.remindDaysBefore/remindMinutes` 로 예약 → 할 일 추가·수정·완료 때 다시 예약

## 새 화면·위젯 규칙

- 색·크기는 숫자를 직접 쓰지 말고 `KeepyColors/KeepyText/KeepyRadius` 사용
- **다크 모드:** 바탕·카드·글자색(`KeepyColors.background/card/label…`)과 `KeepyText.*` 는 모드에 따라 바뀌는 값이라
  `const` 안에 넣을 수 없다 (`const Text('..', style: KeepyText.body)` → 컴파일 오류). 강조색(`blue`, `sky`, `red` …)과 그라데이션은 const 가능
- 그림자·blur 에는 `KeepyMotion.pop`(되튐) 금지, `cardShadow()` 사용 (prompts_log #4)
- 상태 변경은 화면에서 직접 하지 말고 `TaskStore`/`SettingsStore` 메서드로
- 되돌릴 수 있는 동작은 `TaskActions` 에 넣고 알림에 '취소' 연결
- 좌우 제스처를 새로 만들면 화면 전환(PageView)과 겹치는지 먼저 확인 (prompts_log #7, #12)

## 웹 미리보기 갱신

`preview/index.html` 한 파일입니다. 같은 이름의 함수(`visualFor`, `zoneFor`, `status`, `sorted` …)가
Flutter 코드와 1:1로 대응하니 같이 고쳐 주세요 (`DATE_STOPS` ↔ `TaskTile.dateStops`, `pixelate`, `monthStat` 등). 글꼴은 `preview/fonts/` 에 한글 2,350자만 남긴 가벼운 버전이 있습니다. 브라우저에서 파일을 바로 열어도 동작합니다.
