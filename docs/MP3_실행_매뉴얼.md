# Keepy 3단계(MP3) 실행 매뉴얼 — Supabase 동기화

이 순서대로 하면 **두 기기 동기화 → 오프라인→온라인 반영 → 백엔드 콘솔 확인 → 제출 스크린샷**까지 끝납니다.
모든 명령은 **Windows PowerShell** 기준입니다. 폴더는 `C:\Keepy1` 로 적었습니다. 복사본(`C:\Keepy1_copy` 등)에서
할 때는 경로 앞부분만 바꾸면 됩니다.

| 단계 | 할 일 | 걸리는 시간 |
|---|---|---|
| 1 | Supabase 프로젝트 만들기 | 5분 |
| 2 | SQL 실행 (테이블·보안 규칙·충돌 처리) | 1분 |
| 3 | 로그인 설정 (메일 확인 끄기) | 1분 |
| 4 | 주소·공개 키 복사 → `app\.env` | 2분 |
| 5 | 검사 (`flutter analyze`, `flutter test`) | 2분 |
| 6 | 실행 + 두 기기 열기 | 3분 |
| 7 | 통과 기준 확인 + 스크린샷 5장 | 10분 |
| 8 | 제출 전 점검 | 2분 |

---

## 1. Supabase 프로젝트 만들기

1. https://supabase.com 접속 → **Start your project** → GitHub 계정 등으로 가입.
2. **New project** 클릭.
   - Name: `keepy` (아무거나)
   - Database Password: **Generate a password** → 메모장에 따로 보관 (앱에는 쓰지 않음)
   - Region: **Northeast Asia (Seoul)**
   - Plan: **Free**
3. **Create new project** → 1~2분 기다리면 대시보드가 열립니다.

> 무료 프로젝트는 **일주일 동안 쓰지 않으면 일시 정지**됩니다. 시연 전날 대시보드에 들어가 **Restore** 가 보이면 눌러 주세요.

## 2. SQL 실행

1. 왼쪽 메뉴 **SQL Editor** → **New query**.
2. `C:\Keepy1\app\supabase\schema.sql` 을 메모장으로 열어 **전체 복사** → 붙여 넣기 → 오른쪽 아래 **Run**.
3. 아래에 `Success. No rows returned` 가 나오면 끝. (여러 번 실행해도 안전합니다.)
4. 확인: 왼쪽 **Table Editor** 에 `keepy_tasks` 표가 보이고, 표 이름 옆에 **RLS enabled**(또는 자물쇠)가 보이면 정상.

만들어지는 것

| 이름 | 하는 일 |
|---|---|
| `keepy_tasks` 표 | 사용자 한 명의 할 일 한 줄. `data` 에 할 일 JSON, `deleted`(삭제 표시), `updated_at`(기기에서 고친 시각), `synced_at`(서버가 받은 시각) |
| RLS 정책 3개 | 로그인한 사용자는 **자기 줄만** 읽고 쓴다. 실제 삭제(DELETE)는 막음 |
| 트리거 `keepy_tasks_lww` | `updated_at` 이 **더 오래된 쓰기는 무시** (마지막 수정 우선) |

## 3. 로그인 설정

1. 왼쪽 **Authentication** → **Sign In / Providers** → **Email** 펼치기.
2. **Enable Email provider**(이메일 로그인) 켜짐 확인.
3. **Confirm email** 끄기 → **Save**.
   - 켜 두면 가입할 때 메일의 확인 링크를 눌러야 로그인됩니다. 앱도 그 경우 "확인 메일을 보냈어요" 라고 안내하지만,
     시연에는 끄는 쪽이 빠릅니다.

## 4. 주소·공개 키 → `app\.env`

1. 대시보드 왼쪽 아래 **Project Settings**(톱니바퀴) → **API Keys** (메뉴 이름이 **Data API** 일 수도 있음).
2. 두 가지를 복사합니다.
   - **Project URL**: `https://영문숫자.supabase.co` (Data API 또는 Settings > General 에 있음)
   - **Publishable key**: `sb_publishable_…` — 없으면 **Legacy API Keys** 탭의 `anon` `public` 키(`eyJ…`)
   - ⚠️ **Secret key / `service_role` 키는 절대 쓰지 않습니다.**
3. PowerShell:

```powershell
cd C:\Keepy1\app
Copy-Item .env.example .env
notepad .env
```

4. 메모장에서 두 줄을 채우고 저장합니다. 따옴표·공백 없이 `=` 뒤에 바로 붙여 넣습니다.

```
SUPABASE_URL=https://프로젝트주소.supabase.co
SUPABASE_ANON_KEY=sb_publishable_여기에_붙여넣기
```

5. `.env` 는 `.gitignore` 로 제외되어 GitHub 에 올라가지 않습니다. 팀원과 키를 나눌 때는 채팅·문서에 붙이지 말고
   각자 대시보드에서 복사하거나, 각자 자기 Supabase 프로젝트를 만들어 쓰세요.

## 5. 검사

```powershell
cd C:\Keepy1\app

# 처음 한 번 (복사본도 처음엔 한 번): 플랫폼 폴더 + 패키지 + 안드로이드 인터넷 권한
powershell -ExecutionPolicy Bypass -File tool\setup_platforms.ps1
#  웹만 볼 거라면 대신:  flutter create . --project-name keepy --platforms=web ;  flutter pub get

flutter pub get
flutter analyze
flutter test
```

- `flutter analyze`: `error` 로 시작하는 줄이 없으면 됩니다 (`info`·`warning` 은 실행에 지장 없음).
- `flutter test`: 마지막에 `All tests passed!` 가 나오면 됩니다. 동기화 테스트(`sync_test.dart`) 11개는
  실제 서버 없이 같은 규칙의 가짜 서버로 두 기기·오프라인·충돌을 검사합니다.
- 오류가 나면 출력 전체를 복사해 AI 에게 보내면 됩니다 (`docs/MP3_프롬프트.md` 의 '오류 해결용').

## 6. 실행 + 두 기기 열기

### 방법 A — 브라우저 두 개 = 기기 두 대 (가장 빠름, 권장)

```powershell
cd C:\Keepy1\app
flutter run -d web-server --web-port 8080 --dart-define-from-file=.env
```

`lib\main.dart is being served at http://localhost:8080` 가 나오면:

| 기기 | 여는 방법 |
|---|---|
| **기기 A** | Chrome 에서 `http://localhost:8080` |
| **기기 B** | **Edge**(또는 Chrome 의 **시크릿 창** Ctrl+Shift+N)에서 `http://localhost:8080` |

브라우저마다 저장소가 따로라서 서로 다른 기기처럼 동작합니다. F12 → 왼쪽 위 휴대폰 아이콘(Ctrl+Shift+M)을 누르면 휴대폰 크기로 보입니다.

### 방법 B — Chrome 한 대 + 안드로이드 에뮬레이터

```powershell
# 창 1 (기기 A)
flutter run -d chrome --dart-define-from-file=.env
# 창 2 (기기 B) — Android Studio 에서 에뮬레이터를 먼저 켠 뒤
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=.env
```

> ⚠️ `--dart-define-from-file=.env` 를 빼면 앱은 **동기화가 꺼진 채**(2단계와 같음) 실행됩니다.
> 설정 > 계정을 눌러 "서버 동기화가 꺼져 있어요" 가 보이면 이 옵션을 빠뜨린 것입니다.

### 로그인

1. **기기 A**: 설정(왼쪽 화면) → **계정** → **회원가입** 탭 → 이메일·비밀번호(6자 이상) → **가입하고 동기화 시작**.
   - 시연용 이메일은 실제 받을 수 있는 주소가 아니어도 됩니다 (3단계에서 메일 확인을 껐다면). 예: `keepy.demo@example.com`
   - 개인 이메일은 스크린샷에 나오지 않게 시연용 주소를 권장합니다.
2. **기기 B**: 같은 이메일·비밀번호로 **로그인**.
3. 메인 화면 오른쪽 위에 **☁ ✓** 배지가 보이면 동기화 중입니다.

| 배지 | 뜻 |
|---|---|
| ☁ ✓ | 다 맞춰짐 |
| ☁ ↻ | 서버와 주고받는 중 |
| ☁ ↑ N | 서버에 올릴 변경 N개 (곧 올라감) |
| ☁ 📶✕ N | **오프라인** — 변경 N개를 기기에 모아 두는 중 |
| ☁ ! | 서버 오류 (계정 시트에 이유 표시) |

## 7. 통과 기준 확인 + 스크린샷

스크린샷은 `C:\Keepy1\screenshots\` 에 아래 이름으로 저장합니다 (Win+Shift+S → 붙여 넣기 → 저장, 또는 F12 → Ctrl+Shift+P → "screenshot").

### 기준 1 — 기기 A 에서 추가한 할 일이 기기 B 새로고침 후 표시

1. **기기 A** 메인 화면 입력 바에 `MP3 동기화 확인` 입력 → 전송. 배지가 ↻ → ✓ 로 바뀜.
   → 📸 `mp3_01_deviceA_add.png`
2. **기기 B**: 브라우저 **새로고침(F5)** 또는 ☁ 배지 → **지금 동기화**. (가만히 둬도 20초 안에 받아 옵니다.)
   → 같은 할 일이 보이면 통과. 📸 `mp3_02_deviceB_synced.png`

### 기준 2 — 오프라인 작성 항목이 온라인 복귀 후 서버에 반영

1. **기기 A** 에서 F12 → **Network(네트워크)** 탭 → 위쪽 **No throttling**(제한 없음) 드롭다운 → **Offline**.
   (에뮬레이터라면 위에서 끌어내려 **비행기 모드** 켜기)
2. 기기 A 에서 `오프라인에서 쓴 할 일` 추가 → 배지가 **📶✕ 1**, 설정 > 계정에 **"오프라인 · 올릴 변경 1개"**.
   → 📸 `mp3_03_offline_pending.png` (계정 시트가 보이게)
3. 드롭다운을 다시 **No throttling** 으로 (비행기 모드 끄기).
   10초 안에 자동으로 올라가고 배지가 **✓**, 계정 시트의 '서버에 올릴 변경' 이 **0개**. (바로 하려면 '지금 동기화')
4. **기기 B** 새로고침 → `오프라인에서 쓴 할 일` 이 보이면 통과.
   → 📸 `mp3_04_online_synced.png` (기기 B 화면, 또는 A·B 를 나란히)

> 오프라인인 채로 기기 A 브라우저를 닫았다가 다시 열어도 대기열은 남아 있습니다 (기기에 저장). 온라인이 되면 올라갑니다.

### 백엔드 콘솔

1. Supabase 대시보드 → **Table Editor** → `keepy_tasks`.
2. 방금 만든 할 일들이 줄로 보입니다. `data` 칸을 누르면 제목(`title`)·완료(`done`) 등이 보입니다.
   지운 할 일은 `deleted` 가 `true` 로 남습니다.
   → 📸 `mp3_05_supabase_console.png` (주소창의 프로젝트 주소·키가 찍히지 않게 표 부분만)

### (선택) 충돌 처리 직접 보기

1. 기기 A·B 둘 다 Offline 으로 바꿈.
2. 같은 할 일을 기기 A 에서 `발표 (A안)` 으로, **그다음** 기기 B 에서 `발표 (B안)` 으로 수정.
3. 기기 A 를 먼저 온라인 → 동기화, 그다음 기기 B 온라인 → 동기화, 다시 기기 A 동기화.
4. 두 기기 모두 **나중에 고친 `발표 (B안)`** 으로 맞춰지면 정상 (README 4절 '마지막 수정 우선').

## 8. 제출 전 점검

```powershell
cd C:\Keepy1
git status
```

- [ ] `git status` 목록에 **`.env` 가 없다** (`.env.example` 은 있어도 됨)
- [ ] 실제 키가 파일에 들어가 있지 않다 (`.env` 제외하고 검색):
  ```powershell
  Get-ChildItem -Recurse -File -Exclude .env,*.png | Where-Object { $_.FullName -notmatch '\\(build|\.dart_tool|\.git)\\' } | Select-String -Pattern 'sb_publishable_[A-Za-z0-9]{10,}','sb_secret_[A-Za-z0-9]{10,}','eyJhbGci[A-Za-z0-9_-]{20,}'
  ```
  아무것도 안 나오면 OK. (문서 속 예시 `sb_publishable_여기에_붙여넣기` 같은 글자는 걸리지 않습니다.)
- [ ] `screenshots\` 에 `mp3_01` ~ `mp3_05` 5장
- [ ] README.md 8절 표의 ⏳ 를 ✅ 로 바꿈
- [ ] 스크린샷에 개인 이메일·키·프로젝트 주소가 보이지 않음

## 문제 해결

| 증상 | 원인 → 해결 |
|---|---|
| 계정 시트에 "서버 동기화가 꺼져 있어요" | 실행 명령에 `--dart-define-from-file=.env` 빠짐, 또는 `.env` 값이 비었음. `.env` 가 `app` 폴더에 있는지 확인 |
| "서버에 keepy_tasks 테이블이 없어요" | 2단계 SQL 을 실행하지 않았거나 다른 프로젝트에 실행함. URL 의 프로젝트와 같은지 확인 |
| "서버 권한 설정(RLS)을 확인해 주세요" | SQL 일부만 실행됨 → schema.sql 전체를 다시 Run |
| "이메일 또는 비밀번호가 맞지 않아요" | 가입한 적 없는 이메일이거나 오타. 회원가입 탭으로 먼저 가입 |
| "확인 메일을 보냈어요…" | 3단계 Confirm email 이 켜져 있음 → 끄거나 메일의 링크를 누른 뒤 로그인 |
| "잠시 후 다시 시도해 주세요 (요청이 너무 많아요)" | 짧은 시간에 가입 시도가 많음 → 1분 뒤 다시 |
| 계속 "오프라인" | DevTools 의 Offline 이 켜져 있음, 또는 프로젝트가 일시 정지됨(1단계 참고) |
| 기기 B 에 안 보임 | 기기 B 가 **같은 계정**인지(설정 > 계정의 이메일) 확인 → '지금 동기화' |
| 웹에서 `Invalid JWT` / 401 | `SUPABASE_ANON_KEY` 에 Secret key 를 넣었거나 오타. Publishable(또는 anon public) 키로 바꾸기 |
| `flutter run` 이 `.env` 형식 오류 | `.env` 에 따옴표·공백이 없는지, 한 줄에 `이름=값` 하나인지 확인 |

---

관련 문서: [README.md](../README.md) (선택 이유·충돌 처리 방침) · [단계별 정리](단계별_정리_MP1-MP3.md) · [3단계 프롬프트](MP3_프롬프트.md)
