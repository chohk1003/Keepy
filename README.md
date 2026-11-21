# Keepy — Flutter 할 일 관리 앱

Flutter를 기반으로 개발한 할 일 관리 애플리케이션이다. 4인 팀 프로젝트의 개인 구현 버전이며, Riverpod, go_router, Repository 패턴을 적용하여 화면, 상태 관리, 데이터 저장 기능을 분리하였다.

본 프로젝트는  미니프로젝트 세트에 따라 단계별로 기능을 확장하고 있다.

MP1의 기본 화면과 상태 관리 기능, MP2의 로컬 저장·CRUD·필터, MP3의 Firebase 인증과 동기화를 구현하였다. 기본 실행 모드에서는 Firebase 계정 없이 사용할 수 있으며, `shared_preferences`를 통해 앱을 종료한 뒤에도 할 일 데이터를 유지한다.

웹과 Android·iOS가 같은 Flutter 코드와 Firebase 프로젝트를 사용하도록 구성했다. MP4 온디바이스 OCR은 후속 개발 범위다.

## 1. 개발 환경 및 기술 스택

| 항목 | 기술 |
|---|---|
| 개발 프레임워크 | Flutter 3.47.9 |
| 개발 언어 | Dart 3.13.7 |
| 상태 관리 | Riverpod |
| 화면 라우팅 | go_router |
| 아키텍처 | Repository 패턴 |
| 로컬 데이터 저장 | shared_preferences |
| 백엔드 확장 | Firebase Authentication, Cloud Firestore |
| 개발 환경 | Windows, VS Code, Android Studio |
| 테스트 환경 | Chrome, Flutter Test |

## 2. 구현 기능

### MP1 — 할 일 앱 화면 만들기

목록, 입력, 상태 변화 등 할 일 관리 앱의 기본 기능을 구현하였다.

| 기능 | 설명 |
|---|---|
| 할 일 목록 | 등록된 태스크 목록 표시 |
| 할 일 추가 | 새로운 태스크 입력 및 등록 |
| 완료 토글 | 체크박스를 통해 완료 상태 변경 |
| 상태 반영 | 데이터 변경 시 화면 즉시 갱신 |
| 빈 상태 안내 | 등록된 태스크가 없을 때 안내 화면 표시 |

### MP2 — 저장되는 앱으로 만들기

MP1에서 구현한 앱에 로컬 영구 저장 기능을 추가하고, 수정·삭제·필터 기능을 통해 CRUD를 완성하였다.

| 기능 | 설명 |
|---|---|
| 로컬 저장 | shared_preferences를 이용한 태스크 데이터 저장 |
| 데이터 복원 | 앱 종료 후 재실행 시 기존 태스크 목록 복원 |
| 수정(Update) | 기존 태스크의 내용 수정 |
| 삭제(Delete) | 등록된 태스크 삭제 |
| 전체 필터 | 모든 태스크 표시 |
| 미완료 필터 | 완료되지 않은 태스크만 표시 |
| 완료 필터 | 완료한 태스크만 표시 |
| 상태 저장 | 태스크 내용과 완료 상태의 변경 사항 유지 |

### MP3 — 백엔드 서비스로 동기화하기

MP2에서 구현한 로컬 저장 기능을 Firebase와 연동하여 여러 기기에서 동일한 태스크 목록을 사용할 수 있도록 확장하였다. Firebase Authentication을 이용한 사용자 인증과 Cloud Firestore 기반 데이터 동기화를 구현하고, 오프라인 환경에서도 태스크를 관리할 수 있도록 구성하였다.

| 기능 | 설명 |
|---|---|
| Firebase 연동 | Firebase Authentication 및 Cloud Firestore 연결 |
| 회원가입 | 이메일과 비밀번호를 이용한 계정 생성 |
| 로그인·로그아웃 | Firebase Authentication 기반 사용자 인증 |
| 인증 상태 유지 | 앱 재실행 후에도 기존 로그인 상태 유지 |
| 클라우드 저장 | Firestore에 태스크 데이터 저장 및 관리 |
| 사용자별 데이터 분리 | 사용자 UID를 기준으로 태스크 데이터 구분 |
| 기기 간 동기화 | 동일 계정으로 로그인한 여러 기기에서 태스크 목록 공유 |
| 실시간 동기화 | Firestore 데이터 변경 사항을 다른 기기에 반영 |
| 오프라인 저장 | 네트워크 연결이 없는 상태에서도 태스크 작성 및 관리 |
| 온라인 복귀 동기화 | 인터넷 연결 복구 시 오프라인 변경 사항을 서버에 반영 |
| 충돌 처리 | 여러 기기의 데이터 변경 시 일관성을 유지하도록 충돌 처리 |
| 멀티플랫폼 지원 | 기존 Web 앱에 Android 및 iOS 프로젝트 구성 추가 |


### 기존 프로토타입의 추가 기능

MP1·MP2의 필수 기능 외에도  다음 화면 및 기능을 제공한다.

| 화면 | 기능 | 구현 범위 |
|---|---|---|
| 태스크 | 추가·수정·삭제·완료 토글·필터·완료율 | MP1·MP2 구현 |
| 날짜 | 날짜 선택, 날짜별 태스크 및 완료율 조회 | 독립 일정 등록 미구현 |
| OCR | 텍스트 입력 → 후보 추출 → 태스크 등록 | 실제 이미지 OCR 엔진은 모의 구현 |
| 설정 | 알림 시점·시간·달력 행 수 설정 | UI 상태 변경, 실제 알림 예약 미구현 |
| 인증 | 데모 로그인·로그아웃 | 실제 계정 로그인 UI 미구현 |
| Firebase | 이메일/비밀번호 로그인, Firestore 실시간 동기화 | 환경 변수를 제공한 경우 사용 |

OCR 화면의 텍스트 후보 추출은 기존 모의 구현이다.

## 3. 실행 방법

### 3.1. 사전 준비

Flutter SDK 및 개발 환경이 설치되어 있어야 한다.

```powershell
flutter --version
flutter doctor
```

프로젝트는 Flutter 3.47.9 버전을 기준으로 개발하였다.

### 3.2. 프로젝트 실행

VS Code에서 Keepy 프로젝트 폴더(`pubspec.yaml`이 있는 폴더)를 연다.

1. VS Code 왼쪽 메뉴에서 **Run and Debug(실행 및 디버그)**를 선택한다.
2. 실행 구성에서 **Chrome(Web)**을 선택한다.
3. **Start Debugging(F5)** 버튼을 눌러 앱을 실행한다.
4. Chrome 브라우저가 자동으로 실행되며 Keepy 앱을 사용할 수 있다.

Firebase 연결에 필요한 설정은 VS Code의 실행 구성(`.vscode/launch.json`)을 통해 적용되므로, 별도의 PowerShell 명령어를 입력하지 않아도 된다.


### 3.3. Android 실행

Android Studio에서 Android 에뮬레이터를 실행한 후, VS Code에서 Keepy 앱을 실행한다.

1. Android Studio의 **Device Manager**에서 사용할 Android 에뮬레이터를 실행한다.
2. VS Code에서 Keepy 프로젝트를 연다.
3. VS Code 하단의 기기 선택 메뉴에서 실행 중인 Android 에뮬레이터를 선택한다.
4. **Run and Debug(실행 및 디버그)**에서 **Start Debugging(F5)**을 눌러 앱을 실행한다.

실행이 완료되면 Android 에뮬레이터에서 Keepy 앱을 사용할 수 있다.

### 3.4. 코드 검사

```powershell
flutter analyze
flutter test
```

정적 분석과 자동 테스트를 통해 코드 및 주요 기능을 점검한다.

## 4. 프로젝트 구조

프로젝트는 화면, 상태 관리, 데이터 모델, 저장소를 분리한 구조로 설계하였다.

```text
|   firebase_options.dart
|   main.dart
|   
+---app
|       app_shell.dart
|       keepy_app.dart
|       router.dart
|       
+---core
|   +---models
|   |       task.dart
|   |       
|   +---repositories
|   |       in_memory_task_repository.dart
|   |       shared_preferences_task_repository.dart
|   |       task_repository.dart
|   |       
|   +---services
|   |   \---firebase
|   |           firebase_config.dart
|   |           firestore_task_repository.dart
|   |           
|   +---utils
|   |       date_helpers.dart
|   |       
|   \---widgets
|           empty_state.dart
|           task_tile.dart
|           
\---features
    +---auth
    |   +---viewmodels
    |   |       auth_view_model.dart
    |   |       
    |   \---views
    |           login_screen.dart
    |           
    +---calendar
    |   \---views
    |           calendar_screen.dart
    |           
    +---ocr
    |   +---viewmodels
    |   |       ocr_view_model.dart
    |   |       
    |   \---views
    |           ocr_screen.dart
    |           
    +---settings
    |   +---viewmodels
    |   |       settings_view_model.dart
    |   |       
    |   \---views
    |           settings_screen.dart
    |           
    \---task
        +---viewmodels
        |       task_view_model.dart
        |       
        \---views
                task_form_dialog.dart
                task_screen.dart
```

MP2에서는 기존 구조를 유지하면서 `shared_preferences` 기반 로컬 저장 기능을 추가하였다.

### 주요 구성 요소

- **Task 모델:** 할 일의 데이터 구조를 정의한다.
- **TaskRepository:** 데이터 접근을 위한 공통 인터페이스를 제공한다.
- **InMemoryTaskRepository:** 메모리 기반 저장소 구현체이다.
- **로컬 영구 저장 구현체:** 태스크 변경 내용을 기기에 저장하고 재실행 시 복원한다.
- **FirestoreTaskRepository:** 로그인 UID의 태스크를 실시간으로 구독하고 변경하는 Firestore 구현체이다.
- **TaskViewModel:** 태스크 상태 관리 및 화면 갱신을 담당한다.
- **Riverpod Provider:** 화면과 데이터 저장소 사이의 의존성을 연결한다.

### 데이터 처리 구조

```text
[태스크 화면 / 날짜 화면 / OCR 화면]
                |
                v
         [TaskViewModel]
                |
                v
         [TaskRepository]
                |
                v
    [FirestoreTaskRepository]
                |
                v
        [Cloud Firestore]
                ^
                |
      [Firebase Authentication]
        사용자 UID 기반 데이터 분리
```
앱은 Riverpod의 TaskViewModel과 TaskRepository를 통해 태스크 데이터를 관리한다. MP3에서는 FirestoreTaskRepository를 사용하여 Cloud Firestore에 태스크 데이터를 저장하고 조회한다.

Firebase Authentication으로 로그인한 사용자의 UID를 기준으로 데이터를 구분하며, 동일 계정으로 로그인한 여러 기기에서 태스크 목록을 공유할 수 있도록 구성하였다.


## 5. 구현 기능 검증

### 5.1. MP1 검증 항목

| 검증 항목 | 확인 방법 |
|---|---|
| 할 일 추가 | 새로운 태스크를 입력하고 목록에 표시되는지 확인 |
| 완료 토글 | 체크박스를 누르고 상태가 변경되는지 확인 |
| 빈 상태 | 태스크가 없을 때 안내 화면 표시 여부 확인 |

### 5.2. MP2 검증 항목

| 검증 항목 | 확인 방법 |
|---|---|
| CRUD 기능 | 태스크 추가·조회·수정·삭제 정상 동작 확인 |
| 필터 기능 | 전체·완료·미완료 필터별 목록 표시 확인 |
| 데이터 영속성 | 앱 종료 후 재실행 시 기존 태스크 및 완료 상태 유지 확인 |

### 5.3. MP3 검증 항목

| 검증 항목 | 확인 방법 |
|---|---|
| 사용자 인증 | 이메일 회원가입·로그인·로그아웃 및 인증 상태 유지 확인 |
| 기기 간 동기화 | 동일 계정으로 브라우저 A와 B에 로그인하여 태스크 변경 사항 반영 확인 |
| 오프라인 동기화 | 인터넷 연결 해제 후 태스크를 추가하고, 온라인 복귀 시 Firestore 반영 확인 |
| 사용자별 데이터 분리 | 서로 다른 계정으로 로그인했을 때 다른 사용자의 태스크가 표시되지 않는지 확인 |
| 데이터 충돌 처리 | 여러 기기에서 같은 태스크를 수정·삭제할 때 동기화 결과 확인 |
| 기존 기능 유지 | Firebase 연동 후에도 MP2의 CRUD 및 필터 기능이 정상 작동하는지 확인 |


## 7. MP3 Firebase 동기화

MP3는 Firebase Authentication과 Cloud Firestore를 사용한다. 이메일 계정이 기기마다 동일한 UID를 제공하고, Firestore SDK가 문서 변경 구독·로컬 캐시·보류 중인 쓰기 재전송을 제공한다. 기존 `TaskRepository`와 `Task` JSON 구조를 재사용한다.

| 플랫폼 | 앱 식별자 및 실행 조건 |
|---|---|
| Web | 기존 Firebase 웹 앱, Chrome 계열 브라우저 |
| Android | `kr.ac.hansung.keepy.dohyeon`, 최소 API 24, 빌드 SDK 36, Flutter 템플릿 NDK 28.2.13676358 |
| iOS | `kr.ac.hansung.keepy.dohyeon`, iOS 15 이상, macOS와 Xcode 필요 |

### 7.1. 원격 프로젝트 및 계정 설정

1. 기존 `keepy-mp3` 프로젝트의 Authentication → Sign-in method에서 **Email/Password**를 활성화한다. 기존 익명 세션을 이메일에 연결하려는 사용자는 기존 브라우저 프로필과 주소를 유지한다.
2. 프로젝트 설정 → 내 앱에서 기존 Web 앱을 사용하고, Android 패키지 이름과 iOS 번들 ID를 위 표와 일치시켜 앱을 각각 등록한다. 이메일/비밀번호 흐름은 Google 로그인용 OAuth 설정을 사용하지 않는다.
3. Firestore의 기본 데이터베이스가 준비되어 있는지 확인한다. 검토·승인한 뒤 저장소 루트에서 `firebase deploy --only firestore:rules --project keepy-mp3`로 본인 UID만 허용하는 규칙을 적용한다.
4. `.env.example`을 `.env`로 복사하고 콘솔에서 해당 플랫폼 값을 채운다. 웹 SDK 구성에서 `apiKey`, `appId`, `authDomain`, `messagingSenderId`, `projectId`를 확인한다. Android의 `google-services.json`에서 해당 패키지의 `mobilesdk_app_id`와 `current_key`, iOS의 `GoogleService-Info.plist`에서 `GOOGLE_APP_ID`와 `API_KEY`를 복사한다. 두 파일은 설정값 확인용으로 사용한다.
5. 프로젝트 번호 및 ID는 공통이며 키와 앱 ID는 각 등록 플랫폼 값으로 채운다. `FIREBASE_IOS_BUNDLE_ID`는 Xcode 및 콘솔의 번들 ID와 일치시킨다. 실행할 플랫폼의 값만 필요하다.

앱은 `firebase_config.dart`가 만든 `FirebaseOptions`로 초기화한다. FlutterFire 생성 파일과 네이티브 설정 파일은 빌드 입력에서 제외한다. Firebase 클라이언트 API 키와 앱 ID는 클라이언트에 포함되는 식별 정보다. Authentication과 Firestore 규칙이 데이터 접근을 제어한다. 서비스 계정 JSON, 비밀번호, 로그인 토큰과 같은 비밀은 앱에 전달하지 않는다. 과제 제출에는 변수명과 예시만 제공한다. [Firebase Flutter 설정](https://firebase.google.com/docs/flutter/setup) · [이메일/비밀번호 인증](https://firebase.google.com/docs/auth/flutter/password-auth)

### 7.2. 실행 방법

```powershell
flutter pub get
flutter run -d chrome --web-port 7358 --dart-define-from-file=.env
flutter devices
flutter run -d <android-device-id> --dart-define-from-file=.env
flutter build apk --debug --dart-define-from-file=.env
```

웹의 저장 공간은 주소와 포트별로 분리되므로 검증 중에는 고정 포트를 쓴다. 로컬 모드는 같은 명령에서 `--dart-define-from-file=.env`를 빼고 실행한다. Firebase 초기화가 실패한 경우 시작 화면에서도 로컬 모드를 열 수 있다.

Mac에서는 같은 Flutter 버전과 Xcode로 `flutter doctor -v`를 실행하고, 시뮬레이터를 시작한 뒤 `flutter run -d <ios-simulator-id> --dart-define-from-file=.env`를 실행한다. `flutter build ios --simulator --dart-define-from-file=.env`로 시뮬레이터 빌드를 검증한다. 실기기는 Xcode `ios/Runner.xcworkspace`의 Runner에 서명 팀을 설정하고 동일한 번들 ID를 확인한 뒤 실행한다.

### 7.3. 동기화, 오프라인, 충돌

- Firestore의 `users/{uid}/tasks/{taskId}`를 구독한다. 같은 계정은 같은 목록을 읽고, 다른 UID의 문서는 규칙에서 읽기·쓰기를 차단한다.
- Firebase 모드에서 Firestore가 캐시와 보류 쓰기를 소유한다. Android/iOS는 기본으로 영구 캐시를 사용하며, Web은 앱 시작 시 IndexedDB 영구 캐시와 멀티탭 관리를 활성화한다. 같은 브라우저 프로필과 웹 주소에서 기존 캐시를 사용한다. 인터넷 없이 앱 자체를 처음 로드하려면 웹 정적 파일도 접근 가능해야 한다. 이번 웹 재시작 검증에서는 앱 파일은 로컬에서 계속 제공하고 Firestore 연결만 차단했다.
- 오프라인 추가·수정·삭제는 SDK 스냅샷에 먼저 반영되고 온라인 복귀 시 전송된다. 화면은 캐시, 서버 동기화 대기, 동기화 완료를 구분한다. 목록 변경은 서버가 거절할 경우 롤백될 수 있으며, 현재 실행 중에는 오류를 표시한다.
- 같은 문서의 두 수정에는 서버가 최종 수락한 쓰기가 적용된다. 기기에서 기록한 `updatedAt`을 우선순위로 사용하지 않으므로, 오프라인에서 만든 수정이 늦게 서버에 도착하면 앞선 수정을 덮을 수 있다. 삭제 이후 늦게 도착한 수정은 기존 문서만 변경하는 `update()`로 전송되어 실패한다. 새 태스크에는 새 ID를 발급한다.
- MP2 데이터는 기존 기기의 로컬 모드에 그대로 남는다. 클라우드로 자동 복사하거나 기존 계정과 병합하지 않는다. 기존 **Firebase 익명 세션**은 설정에서 새 이메일 계정에 연결하면 UID와 Firestore 문서가 유지된다. 이미 등록된 이메일과의 계정 병합은 지원하지 않는다. 연결 기능의 원격 검증은 배포 후 진행한다.

[Firestore 오프라인 데이터](https://firebase.google.com/docs/firestore/manage-data/enable-offline)

### 7.4. 검증과 증빙

Firebase CLI에서 `firebase emulators:start --only auth,firestore --project demo-keepy-mp3`를 실행하고, 별도의 로컬 설정 파일에 `FIREBASE_PROJECT_ID=demo-keepy-mp3`, `FIREBASE_EMULATOR_HOST=127.0.0.1`, 더미 API 키·앱 ID·프로젝트 번호·웹 도메인을 넣는다. 에뮬레이터는 Auth 9099, Firestore 8080, 콘솔 4000을 사용하므로 Web 앱은 7358 등 다른 포트로 실행한다. `node tool/verify_firestore_rules.cjs`로 규칙을 로컬에서 재검증할 수 있다.

| 검증 | 2026-11-21 결과 |
|---|---|
| MP2 회귀 | 자동 테스트 10개 통과. 웹 로컬 모드에서 새 태스크 추가 후 다시 로드해 복원 확인 |
| MP3 웹 A/B | 에뮬레이터 회원가입·로그인, A의 추가 → B 조회, B의 완료 → A 반영, 로그아웃·계정 격리 확인 |
| MP3 오프라인 | Firestore 연결을 차단한 채 태스크 작성 및 앱 다시 로드, 재연결 후 B와 에뮬레이터 콘솔 반영 확인 |
| Firestore 규칙 | 에뮬레이터 검사 12개 통과. 본인 접근, 다른 UID와 미인증 접근 거절, 삭제 후 수정 거절 |
| 정적 분석 | `dart analyze` 문제 없음. `flutter analyze`의 Windows 하위 프로세스 비정상 종료 |
| Web 빌드 | `flutter build web`은 Windows 하위 프로세스 오류. 같은 Flutter SDK의 Dart2JS를 직접 실행하고 Flutter 웹 파일 및 에셋과 함께 실제 실행 확인 |
| iOS | Runner 설정과 iOS 15 대상을 정적으로 확인. Windows에서 빌드·실행 미검증 |
| Android | Android Studio 에뮬레이터에서 Keepy 앱 실행 및 동작 확인 완료 |
| 실제 Firebase | Firebase 프로젝트 등록 및 설정 완료. Firebase Authentication과 Cloud Firestore 연동 및 실제 데이터 저장·동기화 확인 |


## 8. 제출 산출물

MP1~MP3 제출물은 저장소 루트의 프로젝트에서 아래 구조로 구성한다.

```text
Keepy/
├── app/                # Flutter 앱 소스
├── README.md           # 프로젝트 설명 및 구현 내용
├── prompts_log.md      # AI 활용 및 채택·수정 기록
└── screenshots/        # MP1·MP2 및 MP3 실행 화면
    ├── mp1_list.png
    ├── mp1_add.png
    ├── mp1_complete.png
    ├── mp1_empty.png
    ├── mp2_edit.png
    ├── mp2_delete.png
    ├── mp2_filter.png
    ├── mp2_before.png
    └── mp2_after.png
```

제출 ZIP의 `Keepy/app/`에는 `lib/`, `test/`, `tool/`, `web/`, `android/`, `ios/`, Flutter 의존성·설정, `.env.example`, `firebase.json`, `firestore.rules`를 넣는다. 루트의 README, AI 기록, 스크린샷을 함께 묶고 실제 설정, 캐시, 빌드 결과, 로그 및 서명 파일은 제외한다. ZIP을 푼 뒤 `app/`에서 명령을 실행한다.

### 스크린샷

MP1에서는 목록, 추가, 완료, 빈 상태 화면을 기록한다.

MP2에서는 수정, 삭제, 필터 기능과 앱 재시작 전후의 데이터 유지 상태를 기록한다.

### AI 활용 기록

`prompts_log.md`에 개발 과정에서 사용한 주요 AI 프롬프트, 제안된 해결 방법, 실제 채택·수정 내용과 그 이유를 기록한다.

AI 도구의 제안을 기존 프로젝트에 적용하면서 발생한 문제와 해결 과정도 포함한다.

## 9. 향후 개발 계획

| 단계 | 개발 목표 | 진행 상태 |
|---|---|---|
| MP1 | 할 일 목록·입력·상태 관리 | 구현 완료 |
| MP2 | 로컬 저장·CRUD·필터 | 구현 완료, 최종 검증·제출 자료 정리 |
| MP3 | Firebase 기반 동기화 및 오프라인 복귀 처리 | 모바일 에뮬레이터|
| MP4 | 카메라 및 온디바이스 OCR | 모의 구현에서 실제 인식 기능으로 확장 예정 |

MP4에서는 실제 이미지에서 텍스트를 추출하여 태스크로 변환할 예정이다.