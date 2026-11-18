# Keepy 3단계(MP3) 프롬프트 — 백엔드 동기화

3단계를 구현할 때 실제로 쓴 프롬프트와, 같은 결과를 다시 만들거나 이어서 고칠 때 쓰는 프롬프트를 모았습니다.
AI 응답과 채택/수정 판단은 [prompts_log.md](../prompts_log.md) 34번부터 있습니다.

| 절 | 내용 |
|---|---|
| A | 실제로 보낸 요청 원문 |
| B | AI 가 요청을 어떻게 해석했나 (설계 결정) |
| C | **마스터 프롬프트** — 2단계 앱에서 3단계를 처음부터 다시 만들 때 |
| D | 확인·수정용 짧은 프롬프트 (실행, 오류, 스크린샷, 충돌 시험) |

---

## A. 요청 원문 (2026-11-16)

첨부: 과제 안내 사진 '주제 #2109 할 일 앱 (계속) — 미니프로젝트 #3' 표
(백엔드 서비스로 동기화하기 · 통과 기준 4개 · 제출 산출물 app/, README.md, .env.example, screenshots/, prompts_log.md)

```
3단계 구현하자. 여태 해왔던 대로 해. Keepy1_copy는 나중에 따로 복사할 예정이니 Keepy1만 작업해.
3단계 구현 시 절대 기존 작업과 충돌하지 않고, 실행할 때 오류가 생기지 않고, 전체적인 완성도 잘 다듬어서
정확하게 끝내도록 해. 마지막에 3단계에 해당하는 실행 메뉴얼이 담긴 md 파일, 전에 했던 1&2단계 포함하여
단계별로 내용 및 구조 정리한 md 파일, 구현하는 데 쓰인 프롬포트 파일 준비해.
```

## B. 요청 해석 → 설계 결정

| 요청 문구 | 해석 | 결정 |
|---|---|---|
| "기존 작업과 충돌하지 않고" | 1·2단계 동작·테스트를 그대로 유지 | 기기 저장은 그대로 두고 **동기화를 옆에 붙임**. `TaskStore` 에는 `applyRemote` 하나만 추가. 동기화를 안 넘기면 '꺼짐' 컨트롤러 → 기존 위젯 테스트 수정 불필요 |
| "실행할 때 오류가 생기지 않고" | 빌드·플랫폼 설정이 깨질 위험 최소화, 키가 없어도 실행 | 공식 SDK 대신 **REST + `http` 하나**. 키가 없으면 동기화만 꺼진 채 실행. 새 형식 키는 `apikey` 헤더에만(공식 문서로 확인). 안드로이드 인터넷 권한은 설정 스크립트가 추가 |
| "완성도" | 상태가 눈에 보이고, 실패해도 안내가 있음 | 메인 ☁ 배지, 계정 시트(마지막 동기화·올릴 변경 수·지금 동기화), 한국어 오류 문구, 로그아웃 확인 |
| "정확하게" | 통과 기준 4개를 증거와 함께 | 가짜 서버 동기화 테스트 11개, SQL 은 PostgreSQL 에서 실행 검증, README 8절 자체 점검표 |
| 사진의 통과 기준 1 | '새로고침 후 표시' | 실시간 구독 없이 앱 시작·복귀·20초 주기·'지금 동기화' |
| 사진의 통과 기준 2 | 오프라인 작성 → 복귀 시 반영 | 기기에 저장되는 **동기화 장부(대기열)**, 오프라인이면 10초마다 재시도 |
| 사진의 통과 기준 3 | 충돌 처리 방침 | 할 일 단위 **마지막 수정 우선** + **삭제 표시** + 로그인 시 수정 시각 기준 합치기, 서버 트리거로도 강제 |
| 사진의 통과 기준 4 | 키 분리 | `--dart-define-from-file=.env` → `String.fromEnvironment`, `.env` gitignore, `.env.example` 만 |
| "md 파일 3개" | 실행 매뉴얼 / 단계별 정리 / 프롬프트 | `docs/MP3_실행_매뉴얼.md`, `docs/단계별_정리_MP1-MP3.md`, 이 파일 |

---

## C. 마스터 프롬프트 (2단계 Keepy → 3단계, 복사해서 그대로 사용)

```
C:\Keepy1 의 Flutter 할 일 앱 Keepy(2단계 완료, 기기 저장 shared_preferences)에 미니프로젝트 3단계
'백엔드 서비스로 동기화하기'를 구현해 줘. 앱 소스는 app/. 먼저 README_KEEPY.md, docs/IMPLEMENTATION.md,
docs/MODIFY_GUIDE.md 를 읽고 기존 구조·디자인 규칙을 지켜.

[원칙]
- 1·2단계 동작과 테스트를 깨지 않는다. 기기 저장은 그대로 두고 동기화를 '옆에' 붙인다.
- 설정 키가 없으면 동기화만 꺼진 채 오류 없이 실행된다 (2단계와 같은 동작).
- 키는 코드에 넣지 않는다: app/.env (gitignore) → flutter run --dart-define-from-file=.env → String.fromEnvironment.
  app/.env.example 에는 SUPABASE_URL=, SUPABASE_ANON_KEY= 이름만.

[백엔드: Supabase, 공식 SDK 대신 REST 를 http 패키지로]
- 인증: /auth/v1/signup, /auth/v1/token?grant_type=password, refresh_token. 이메일+비밀번호.
  프로젝트 키는 apikey 헤더에만 (새 형식 sb_publishable_ 키는 Authorization 에 넣으면 거절됨),
  Authorization 에는 로그인한 사용자 토큰만. 토큰 만료 1분 전 갱신, 401 이면 한 번 갱신 후 재시도.
- 표 keepy_tasks(user_id uuid default auth.uid(), id text, data jsonb, deleted bool, updated_at bigint, synced_at bigint,
  PK(user_id,id)). RLS: 자기 줄만 select/insert/update, DELETE 정책 없음.
  트리거: UPDATE 때 new.updated_at < old.updated_at 이면 무시(return null), 아니면 synced_at = 지금(ms).
  app/supabase/schema.sql 한 파일, 여러 번 실행해도 안전하게.

[동기화 SyncController]
- TaskStore 변경을 지켜보다가 할 일별 JSON 을 장부와 비교 → 새로 생김·바뀜·사라짐(삭제 표시)을 dirty 로.
  장부(할 일별 updatedAt·dirty·deleted·json + 서버 커서)는 기기에 저장 = 오프라인 대기열.
- syncNow: 당겨오기(synced_at > 커서-3초, 오름차순, 500개씩) → 올리기(on_conflict=user_id,id, merge-duplicates).
  받을 때: 내 dirty 가 더 최신이면 건너뜀, 같은 버전이면 건너뜀, 아니면 반영. 받은 변경은 다시 올리지 않음
  (TaskStore.applyRemote 한 곳으로 넣고, 그동안은 변경 감지를 멈춤). 올리는 도중 또 바뀐 것은 대기열에 남김.
- 언제: 앱 시작, 앱 복귀, 변경 1.2초 뒤, 20초마다, '지금 동기화'. 오프라인이면 10초마다 재시도.
- 로그인할 때 기기에 있던 할 일은 계정에 합치되, 기준 시각은 할 일의 updatedAt(없으면 createdAt).
- 로그아웃: 할 일은 기기에 남기고 로그인 정보·장부만 지움. 도중 로그아웃이면 그 회차는 조용히 중단.
- 상태: 꺼짐 / 로그인 전 / 맞춰짐 / 동기화 중 / 오프라인 / 오류 + 올릴 변경 수 + 마지막 동기화.

[화면]
- 설정 > 계정 줄 → '계정 · 동기화' 시트: 로그인/회원가입 탭, 이메일·비밀번호, 한국어 오류 안내,
  로그인 후 상태·마지막 동기화·올릴 변경 수·지금 동기화·로그아웃(대기열 있으면 경고).
  설정이 없으면 켜는 방법 안내.
- 메인 머리 오른쪽에 로그인했을 때만 ☁ 배지(✓ / ↻ / ↑N / 오프라인 / 오류), 누르면 같은 시트.
- 다크 모드 색은 const 에 넣지 않기, 기존 KeepyColors/KeepyText/PressScale/GradientButton 사용.

[검증·문서]
- test/sync_test.dart: 실서버와 같은 규칙의 가짜 서버로 두 기기, 오프라인 → 복귀, 앱 재시작 후 대기열 유지,
  수정·완료·삭제 전파, LWW 충돌, 삭제 vs 나중 수정, 재전송 없음, 로그인 합치기, 비밀번호 오류, 로그아웃, 설정 없음.
- 설정 스크립트에 안드로이드 인터넷 권한 추가(정식 빌드용).
- README.md 를 3단계 제출용으로: 선택한 BaaS 와 이유(Firebase 비교), 동기화 충돌 처리 방침, 백엔드 설정 절차,
  실행 절차, 키 관리, 통과 기준 자체 점검, 스크린샷 목록(mp3_01~05). 2단계 저장 방식 비교는 남겨 둔다.
- docs/MP3_실행_매뉴얼.md(PowerShell 단계별), docs/단계별_정리_MP1-MP3.md, docs/MP3_프롬프트.md,
  CHANGELOG·IMPLEMENTATION·MODIFY_GUIDE·README_KEEPY·prompts_log 갱신. 버전 0.6.0.
```

---

## D. 확인·수정용 짧은 프롬프트

**실행 확인 후 결과 보고**
```
docs/MP3_실행_매뉴얼.md 5단계까지 했어. flutter analyze / flutter test 결과를 붙일게. 문제 있으면 고쳐 줘.
<결과 전체 붙여넣기>
```

**오류 해결용**
```
flutter run -d web-server --web-port 8080 --dart-define-from-file=.env 실행 중 아래 오류가 났어.
원인을 찾아 기존 1·2단계 기능은 건드리지 말고 고쳐 줘.
<오류 전체 붙여넣기>
```

**동기화가 안 될 때 (화면에 보이는 문구와 함께)**
```
기기 A 에서 추가한 할 일이 기기 B 에 안 보여. 계정 시트 상태 문구는 "<문구>", 메인 ☁ 배지는 "<모양>" 이야.
Supabase Table Editor 의 keepy_tasks 에는 <몇 줄 / 안 보임>. 원인과 해결 순서를 알려 줘.
```

**스크린샷 점검**
```
screenshots/ 의 mp3_01~mp3_05 를 첨부할게. 과제 통과 기준(기기 A 추가, 기기 B 동기화, 오프라인→온라인, 백엔드 콘솔)에
맞게 찍혔는지, 이메일·키·프로젝트 주소가 노출되지 않았는지 확인해 줘.
```

**충돌 처리 바꾸기 (예시)**
```
지금은 할 일 단위 마지막 수정 우선이야. 제목과 완료 여부를 따로 병합하도록(필드 단위 LWW) 바꾸고 싶어.
sync_controller.dart 와 schema.sql 을 어떻게 바꿔야 하는지, 테스트(sync_test.dart)까지 함께 고쳐 줘.
README 4절도 맞춰 줘.
```

**prompts_log 기록용**
```
이번 3단계 수정 내용을 prompts_log.md 에 같은 형식(프롬프트 / AI 응답 / 판단)으로 추가할 초안을 써 줘.
'판단' 칸은 내가 채울 테니 비워 둬.
```
