# MP3 따라하기 — Firebase 설정부터 검증까지

> 처음 MP3를 돌려 보는 사람이 **위에서 아래로 그대로 따라 하면 되는** 순서.
> 구조·설계 이유는 [firebase.md](firebase.md) · [auth.md](auth.md), 코드 전체 그림은 [FIREBASE_구조_보고서.md](FIREBASE_구조_보고서.md).

`.env` 없이도 앱은 **로컬 전용 게스트 모드**로 돈다. 아래 설정은 "두 기기에서 같은 목록"(FR-11)과 오프라인 복귀(FR-12)를 확인하려면 필요하다.

```mermaid
flowchart LR
    A["1. 콘솔<br/>프로젝트·앱 등록"] --> B["2. .env<br/>키 4개"]
    B --> C["3. 로그인 켜기<br/>Authentication"]
    C --> D["4. Firestore<br/>DB 생성 + 규칙 게시"]
    D --> E["5. 실행·로그인"]
    E --> F["6. 두 기기 확인<br/>NFR-03"]
    F --> G["7. 오프라인 확인<br/>NFR-04"]
    G --> H["8. 기록<br/>README·스크린샷"]

    classDef user fill:#0A84FF,stroke:#0060df,color:#fff
    class A,C,D user
```

파랑 = Firebase 콘솔(웹)에서 하는 일, 나머지 = 이 저장소에서 하는 일.

---

## 1. Firebase 프로젝트와 앱 등록

1. <https://console.firebase.google.com> → **프로젝트 추가**
   - 이름은 아무거나 (예: `keepy-mp3`). **Google 애널리틱스는 끈다** (필요 없고 설정만 길어진다)
   - 요금제는 **Spark(무료)** 그대로. 카드 등록이 필요 없다
2. 프로젝트 개요에서 **Android 아이콘**을 눌러 앱 등록
   - **Android 패키지 이름**: `kr.ac.hansung.keepy` ← `android/app/build.gradle.kts`의 `applicationId`와 **글자 하나까지 같아야 한다**
   - 앱 닉네임·디버그 서명 인증서(SHA-1)는 비워도 된다 (이메일/비밀번호 로그인에는 불필요)
3. **`google-services.json` 다운로드** — 파일을 프로젝트에 넣지는 않는다. 다음 단계에서 값 4개만 꺼내 쓴다

> iOS는 지금 범위가 아니다. MP3 시연은 Android 에뮬레이터 2대로 잡는다.

## 2. `.env` 만들기

`.env.example`을 복사해 같은 폴더에 `.env`로 저장하고, 1단계에서 받은 `google-services.json`에서 값을 옮긴다.

```bash
cp .env.example .env
```

| `.env` 키 | `google-services.json`의 위치 |
|---|---|
| `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
| `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
| `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` |

```
FIREBASE_API_KEY=AIza...
FIREBASE_APP_ID=1:123456789012:android:abcd1234
FIREBASE_MESSAGING_SENDER_ID=123456789012
FIREBASE_PROJECT_ID=keepy-mp3
```

- **따옴표 없이**, `=` 뒤에 바로 붙여 쓴다
- `.env`는 `.gitignore`에 들어 있다. **절대 커밋하지 않는다** (NFR-06, CST-04)
- 네 개 중 하나라도 비면 `FirebaseEnv.configured`가 false가 되어 게스트 모드로 돈다

## 3. 이메일/비밀번호 로그인 켜기

콘솔 → **Authentication** → 시작하기 → **이메일/비밀번호** → 사용 설정 → 저장.

안 켜면 로그인할 때 `Firebase 콘솔에서 이메일/비밀번호 로그인을 켜 주세요.`가 뜬다.

> 테스트 계정은 `test1@keepy.dev` / `test2@keepy.dev` 처럼 **가짜 주소**를 쓴다. Firebase는 메일 존재 여부를 확인하지 않는다. 비밀번호는 6자 이상.

## 4. Firestore 만들고 보안 규칙 게시

1. 콘솔 → **Firestore Database** → 데이터베이스 만들기
   - 위치: `asia-northeast3`(서울) 권장
   - 모드: 아무거나 골라도 된다. **바로 다음 단계에서 규칙을 덮어쓴다**
2. **규칙(Rules)** 탭 → 저장소 루트의 [`firestore.rules`](../app/firestore.rules) 내용을 **전부 복사해 붙여넣고 [게시]**

규칙이 하는 일 세 가지 ([firebase.md](firebase.md#보안-규칙-firestorerules)):

- 로그인한 본인 문서(`users/{내 uid}/tasks/...`)만 읽고 쓸 수 있다
- **서버에 있는 것보다 오래된 버전으로 덮어쓰기를 거절한다** (LWW를 서버에서도 강제)
- `delete`를 막는다 — 삭제는 `deleted: true` 표식(tombstone)으로만

> 게시를 빼먹으면 기본 규칙(전체 거부 또는 30일 테스트 모드)이 남아 업로드가 조용히 실패한다. 콘솔 로그에 `PERMISSION_DENIED`가 보이면 이 단계다.

## 5. 실행하고 로그인

```bash
flutter run --dart-define-from-file=.env
```

```bash
flutter run
```

위가 동기화 모드, 아래가 `.env`를 안 읽는 로컬 전용 모드다. `--dart-define-from-file`을 빠뜨리면 `.env`가 있어도 게스트로 돈다.

앱에서: **설정 탭 → 맨 위 계정 행 → "계정이 없어요 → 회원가입"** → 이메일·비밀번호 입력 → 가입하고 로그인.

| 계정 행에 보이는 것 | 뜻 |
|---|---|
| `게스트 / 이 기기에만 저장 · 동기화 꺼짐` | `.env`가 없음 (눌러도 토스트만) |
| `게스트 / 로그인하면 기기 간 동기화` | 설정은 됐고 아직 로그인 안 함 |
| `이메일 / 동기화 켜짐` | 동기화 중 |

로그인하면 그 전에 게스트로 쓴 할 일이 서버와 병합돼 올라간다. 콘솔 → Firestore Database → `users/{uid}/tasks`에서 문서가 보이면 성공이다.

## 6. 두 기기 동기화 확인 (FR-11 · NFR-03)

에뮬레이터 2대면 된다.

```bash
flutter emulators
```

```bash
flutter devices
```

```bash
flutter run --dart-define-from-file=.env -d emulator-5554
```

1. 두 기기 모두 **같은 계정**으로 로그인
2. 기기 A에서 할 일 추가 → 기기 B 화면에 뜰 때까지 시간을 잰다 (**3초 이내 = NFR-03**)
3. 반대 방향, 완료 토글, 삭제도 같이 확인한다 — **삭제는 B에서도 사라져야 한다** (tombstone 전파)
4. 같은 할 일을 양쪽에서 다르게 고쳐 본다 → **나중에 고친 쪽이 이긴다** (LWW)

## 7. 오프라인 → 복귀 확인 (FR-12 · NFR-04)

1. 기기 A를 **비행기 모드**로 (에뮬레이터는 설정 → 네트워크 또는 상단 빠른 설정)
2. 할 일 2~3개 추가·수정 → **화면에는 즉시 반영돼야 한다** (로컬 우선)
3. 앱을 완전히 종료하고 다시 켠다 → 추가한 항목이 그대로 있어야 한다 (Firestore SDK가 쓰기를 기기에 보관)
4. 비행기 모드 해제 → 기기 B와 콘솔에 반영될 때까지 시간을 잰다 (**5초 이내 = NFR-04**)

## 8. 기록 (제출용)

- [ ] 측정값을 루트 [README.md](../README.md) "측정값 (NFR-03 · NFR-04)" 표에 적는다
- [ ] 스크린샷 4장: 기기 A 추가 · 기기 B 동기화 · 오프라인→온라인 · Firestore 콘솔 문서 목록 → `screenshots/`

---

## 막혔을 때

| 증상 | 원인·해결 |
|---|---|
| 로그에 `[sync] .env 설정이 없어 로컬 전용(게스트)으로 실행합니다.` | `--dart-define-from-file=.env`를 빼먹었거나 키 값이 비었다 |
| 로그에 `[sync] Firebase 초기화 실패 → 로컬 전용으로 실행` | `.env` 값 오타. 특히 `FIREBASE_APP_ID`(`1:...:android:...` 전체) |
| `Firebase 콘솔에서 이메일/비밀번호 로그인을 켜 주세요.` | 3단계 안 함 |
| `비밀번호는 6자 이상이어야 해요.` | Firebase 규칙. 6자 이상으로 |
| 로그에 `[sync] 업로드 거절/실패 (...): PERMISSION_DENIED` | 4단계 규칙 게시 안 함, 또는 다른 계정 문서에 쓰려고 함 |
| 로그에 `[sync] 업로드 거절/실패` 인데 규칙은 맞다 | 옛 버전으로 덮어쓰려 한 것 — **정상 동작**이다. 규칙이 최신 수정을 지키고 있다 |
| 콘솔에 문서가 안 보인다 | 로그인했는지, `users/{uid}`의 uid가 Authentication의 사용자 UID와 같은지 확인 |
| 두 기기 목록이 다르다 | 같은 계정인지 먼저 확인. 한쪽이 게스트면 동기화하지 않는다 |
| 지운 항목이 다른 기기에 남아 있다 | `deleted: true` 문서가 올라갔는지 콘솔에서 확인 (문서는 지워지지 않는 게 정상) |
| 빌드 실패 `minSdk` | `android/app/build.gradle.kts`의 `minSdk = maxOf(flutter.minSdkVersion, 23)` 확인. Firestore는 21+ |

로그는 `flutter run` 터미널에 `[sync]` 접두사로 나온다.

## 콘솔에서 보면 좋은 것

| 위치 | 확인할 것 |
|---|---|
| Authentication → Users | 가입한 계정, **User UID** (Firestore 경로의 `{uid}`) |
| Firestore Database → `users/{uid}/tasks` | 문서 하나당 할 일 하나. `updatedAt`·`updatedAtMs`·`deleted`·`serverUpdatedAt` |
| Firestore Database → 사용량 | 읽기·쓰기 횟수. 무료 한도(일 5만 읽기 / 2만 쓰기)에 한참 못 미친다 |
