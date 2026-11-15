# Keepy — Flutter 할 일 관리 앱

Flutter를 기반으로 개발한 할 일 관리 애플리케이션이다. 4인 팀 프로젝트의 개인 구현 버전이며, Riverpod, go_router, Repository 패턴을 적용하여 화면, 상태 관리, 데이터 저장 기능을 분리하였다.

본 프로젝트는  미니프로젝트 세트에 따라 단계별로 기능을 확장하고 있다.

현재 MP1의 기본 화면 및 상태 관리 기능과 MP2의 로컬 저장·CRUD·필터 기능을 구현하였다. 기본 실행 모드에서는 Firebase 계정 없이 사용할 수 있으며, `shared_preferences`를 통해 앱을 종료한 뒤에도 할 일 데이터를 유지한다.

향후 MP3에서는 Firebase 기반 동기화, MP4에서는 온디바이스 OCR 기능을 확장할 예정이다.

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

### 기존 프로토타입의 추가 기능

MP1·MP2의 필수 기능 외에도 기존 프로토타입에서 다음 화면 및 기능을 제공한다.

| 화면 | 기능 | 구현 범위 |
|---|---|---|
| 태스크 | 추가·수정·삭제·완료 토글·필터·완료율 | MP1·MP2 구현 |
| 날짜 | 날짜 선택, 날짜별 태스크 및 완료율 조회 | 독립 일정 등록 미구현 |
| OCR | 텍스트 입력 → 후보 추출 → 태스크 등록 | 실제 이미지 OCR 엔진은 모의 구현 |
| 설정 | 알림 시점·시간·달력 행 수 설정 | UI 상태 변경, 실제 알림 예약 미구현 |
| 인증 | 데모 로그인·로그아웃 | 실제 계정 로그인 UI 미구현 |
| Firebase | Firestore 저장소 및 익명 인증 | 별도 설정 후 선택 가능한 확장 코드 |

이번 주차의 개발 및 평가 범위는 MP2까지이며, OCR·Firebase 관련 기능은 기존 프로토타입의 확장 기능으로 구분한다.

## 3. 실행 방법

### 3.1. 사전 준비

Flutter SDK 및 개발 환경이 설치되어 있어야 한다.

```powershell
flutter --version
flutter doctor
```

프로젝트는 Flutter 3.47.9 버전을 기준으로 개발하였다.

### 3.2. 프로젝트 실행

Windows PowerShell에서 Flutter 프로젝트의 루트 폴더(`pubspec.yaml`이 있는 폴더)로 이동한다.

```powershell
cd C:\Users\dhlee\git\Keepy

flutter pub get

flutter run -d chrome --web-port 8080
```

실행 후 Chrome에서 `http://localhost:8080`으로 접속하여 앱을 사용할 수 있다.

**웹 실행 시 포트 고정**

Chrome의 로컬 저장소는 접속 주소와 포트별로 구분된다. `flutter run -d chrome`을 실행할 때 포트가 변경되면 이전 실행에서 저장한 데이터가 표시되지 않을 수 있다.

따라서 로컬 저장 기능 검증 시에는 `--web-port 8080` 옵션을 사용하여 동일한 주소로 실행한다.

### 3.3. Android 실행

```powershell
flutter devices
flutter run -d <기기ID>
```

Android 에뮬레이터 또는 연결된 실기기에서 실행할 수 있다.

### 3.4. 코드 검사

```powershell
flutter analyze
flutter test
```

정적 분석과 자동 테스트를 통해 코드 및 주요 기능을 점검한다.

## 4. 프로젝트 구조

프로젝트는 화면, 상태 관리, 데이터 모델, 저장소를 분리한 구조로 설계하였다.

```text
lib/
├── main.dart
├── app/
│   ├── keepy_app.dart
│   ├── router.dart
│   └── app_shell.dart
├── core/
│   ├── models/
│   │   └── task.dart
│   ├── repositories/
│   │   ├── task_repository.dart
│   │   └── in_memory_task_repository.dart
│   ├── services/
│   │   └── firebase/
│   │       └── firestore_task_repository.dart
│   ├── utils/
│   │   └── date_helpers.dart
│   └── widgets/
│       ├── task_tile.dart
│       └── empty_state.dart
└── features/
    ├── task/
    ├── calendar/
    ├── ocr/
    ├── auth/
    └── settings/
```

MP2에서는 기존 구조를 유지하면서 `shared_preferences` 기반 로컬 저장 기능을 추가하였다.

### 주요 구성 요소

- **Task 모델:** 할 일의 데이터 구조를 정의한다.
- **TaskRepository:** 데이터 접근을 위한 공통 인터페이스를 제공한다.
- **InMemoryTaskRepository:** 메모리 기반 저장소 구현체이다.
- **로컬 영구 저장 구현체:** 태스크 변경 내용을 기기에 저장하고 재실행 시 복원한다.
- **FirestoreTaskRepository:** 향후 클라우드 저장 기능을 위한 Firestore 구현체이다.
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
         저장소 구현체 선택
          /      |      \
         v       v       v
     InMemory   Local  Firestore
       저장소    저장소    저장소
                 |
                 v
          shared_preferences
```

화면이 저장소의 구체적인 구현 방식을 직접 처리하지 않도록 설계하였다.

이를 통해 기존 메모리 저장 방식을 로컬 영구 저장 방식으로 확장하고, 향후 Firebase 동기화 기능을 추가할 수 있도록 하였다.

## 5. MP2 로컬 저장 기능

### 5.1. 기존 MP1의 한계

MP1에서는 `InMemoryTaskRepository`를 사용하여 실행 중인 메모리에서 태스크를 관리하였다.

이 방식은 별도의 저장소 설정 없이 목록·입력·완료 토글 기능을 구현하기에 적합하지만, 앱을 종료하면 데이터가 초기화되는 문제가 있었다.

### 5.2. MP2에서 개선한 내용

MP2에서는 `shared_preferences`를 사용하여 태스크 데이터를 로컬 저장소에 기록하도록 확장하였다.

기본적인 데이터 처리 과정은 다음과 같다.

1. 앱 실행 시 저장된 태스크 데이터를 불러온다.
2. 불러온 데이터를 상태 관리 계층에 반영한다.
3. 사용자가 태스크를 추가·수정·삭제하거나 완료 상태를 변경한다.
4. 변경된 데이터를 로컬 저장소에 기록한다.
5. 앱을 다시 실행하면 저장된 데이터를 복원한다.

이를 통해 기존 MP1의 화면과 상태 관리 구조를 유지하면서 데이터 영속성을 추가하였다.

### 5.3. 로컬 저장 방식 선택 이유

MP2의 저장소로 `shared_preferences`를 선택하였다.

| 저장 방식 | 장점 | 단점 |
|---|---|---|
| **shared_preferences** | 사용이 간단하고 Flutter 웹·모바일에서 지원됨 | 대량 데이터 검색 및 복잡한 쿼리에 부적합 |
| SQLite | 관계형 데이터 관리, SQL 검색·정렬 지원 | 테이블 설계 및 데이터베이스 관리 필요 |
| Hive | 객체 기반 로컬 데이터 관리에 활용 가능 | 별도 패키지 및 데이터 모델 관리 필요 |

현재 Keepy의 저장 대상은 태스크 목록과 각 태스크의 상태 등 비교적 단순한 데이터이다.

따라서 복잡한 데이터베이스 기능을 도입하기보다 `shared_preferences`를 사용하여 저장·복원 기능을 간단하게 구현하는 것이 적합하다고 판단하였다.

또한 기존 Repository 패턴을 유지함으로써 저장 방식이 변경되더라도 화면 코드를 대규모로 수정하지 않도록 설계하였다.

## 6. 구현 기능 검증

### 6.1. MP1 검증 항목

| 검증 항목 | 확인 방법 |
|---|---|
| 할 일 추가 | 새로운 태스크를 입력하고 목록에 표시되는지 확인 |
| 완료 토글 | 체크박스를 누르고 상태가 변경되는지 확인 |
| 빈 상태 | 태스크가 없을 때 안내 화면 표시 여부 확인 |

### 6.2. MP2 검증 항목

| 검증 항목 | 확인 방법 |
|---|---|
| 수정 | 태스크 제목 변경 후 목록 반영 확인 |
| 삭제 | 태스크 삭제 후 목록에서 제거되는지 확인 |
| 전체 필터 | 완료·미완료 태스크 전체 표시 확인 |
| 미완료 필터 | 미완료 태스크만 표시되는지 확인 |
| 완료 필터 | 완료 태스크만 표시되는지 확인 |
| 재시작 후 데이터 유지 | 앱을 종료하고 동일한 주소로 재실행한 뒤 데이터 복원 확인 |

### 6.3. 로컬 영구 저장 검증

Chrome에서 다음 과정을 통해 데이터 유지 기능을 확인하였다.

1. `flutter run -d chrome --web-port 8080`으로 앱 실행
2. 새로운 할 일 추가
3. Chrome 새로고침 후 기존 데이터 유지 확인
4. 앱 및 개발 서버 종료
5. 동일한 명령어로 재실행
6. 기존 할 일 데이터가 유지되는 것을 확인

**검증 결과:** Chrome에서 동일한 포트를 사용하여 재실행했을 때 기존 태스크가 정상적으로 복원되었다.

그 외 CRUD·필터의 개별 테스트 결과와 `flutter analyze`, `flutter test` 실행 결과는 최종 검증 후 기록한다.

## 7. Firebase 저장소 (향후 MP3 확장)

기존 프로토타입에는 Firebase 저장소 구현이 별도로 포함되어 있다.

현재 MP2의 기본 실행은 Firebase를 사용하지 않는 로컬 모드로 진행한다.

Firebase 모드를 사용하려면 Firebase 프로젝트에서 Authentication의 Anonymous 로그인과 Cloud Firestore를 설정해야 한다.

웹 환경에서는 필요한 설정값을 다음과 같이 전달할 수 있다.

```powershell
flutter run -d chrome --web-port 8080 `
  --dart-define=USE_FIREBASE=true `
  --dart-define=FIREBASE_API_KEY=YOUR_API_KEY `
  --dart-define=FIREBASE_APP_ID=YOUR_APP_ID `
  --dart-define=FIREBASE_SENDER_ID=YOUR_MESSAGING_SENDER_ID `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
```

`main.dart`에서 Firebase 초기화 및 익명 인증을 수행하고 `FirestoreTaskRepository`를 주입하는 방식이다.

데이터는 익명 사용자의 UID를 기준으로 `users/{uid}/tasks/{taskId}`에 저장하도록 구성되어 있다.

이는 기존 프로토타입에 포함된 선택적 저장소 기능이며, MP3의 통과 기준인 다중 기기 동기화 및 오프라인 복귀 처리까지 완료했다는 의미는 아니다.

## 8. 제출 산출물

교수의 MP1·MP2 제출 기준에 따라 다음 산출물을 준비한다.

```text
Keepy/
├── app/                # Flutter 앱 소스
├── README.md           # 프로젝트 설명 및 구현 내용
├── prompts_log.md      # AI 활용 및 채택·수정 기록
└── screenshots/        # MP1·MP2 실행 화면
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

실제 프로젝트에서 Flutter 소스가 저장소 루트에 위치하는 경우, 최종 제출 시 요구되는 `app/` 구조를 별도로 정리한다.

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
| MP3 | Firebase 기반 동기화 및 오프라인 복귀 처리 | 향후 개발 |
| MP4 | 카메라 및 온디바이스 OCR | 모의 구현에서 실제 인식 기능으로 확장 예정 |

MP3에서는 기존 Repository 구조를 활용하여 클라우드 데이터 저장 및 여러 기기 간 동기화를 구현하고, MP4에서는 실제 이미지에서 텍스트를 추출하여 태스크로 변환하는 기능을 추가할 예정이다.