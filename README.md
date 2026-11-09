# Keepy — Flutter 4인 팀 개발 프로토타입

Flutter + Riverpod + go_router + Repository 패턴을 적용한 **실행용 학습 프로토타입**이다. 기본 모드는 Firebase 계정 없이 작동하며, Firestore 저장소 구현도 별도로 포함되어 있다.

## 포함된 기능

| 탭       | 가능한 동작                                    | 구현 범위                           |
| -------- | ---------------------------------------------- | ----------------------------------- |
| 태스크   | 추가 / 수정 / 삭제 / 완료 토글 / 필터 / 완료율 | 동작                                |
| 날짜     | 날짜 선택, 해당 날짜의 태스크와 완료율 조회    | 동작 (독립 일정 등록은 미구현)      |
| OCR      | 텍스트 입력 → 후보 추출 → 태스크 등록          | **OCR 인식 엔진은 모의 구현**       |
| 설정     | 알림 시점·시간·달력 행 수 설정, 데모 로그아웃  | 화면 상태만 변경 (알림 예약 미구현) |
| 인증     | 데모 로그인/로그아웃 화면                      | **실제 로그인 UI 미구현**           |
| Firebase | Firestore 실시간 태스크 저장소, 익명 인증      | 별도 설정 후 선택 가능              |

기본 저장소(`InMemoryTaskRepository`)는 **앱을 종료하면 데이터가 초기화**된다. Firebase 모드에서는 Firestore에 저장된다.

## 1. 실행 방법 (Windows PowerShell 기준)

1. [Flutter SDK](https://docs.flutter.dev/get-started/install)를 설치하고 `flutter doctor`로 점검한다.
2. 이 ZIP을 풀어 생성된 `keepy_flutter_prototype` 폴더에서 터미널을 연다.
3. 다음 명령어를 순서대로 실행한다.

```powershell
cd keepy_flutter_prototype
flutter create --project-name keepy_prototype --platforms=android,web .
flutter pub get
flutter run -d chrome
```

이미 `keepy_flutter_prototype` 폴더 안에 터미널이 열려 있다면 첫 번째 `cd`는 생략한다.


```powershell
flutter test
```

Android 에뮬레이터 또는 실제 기기에서 실행하려면 `flutter devices`로 기기를 확인한 뒤 `flutter run -d <기기ID>`를 사용한다.

## 2. 프로젝트 구조

```text
lib/
├── main.dart
├── app/
│   ├── keepy_app.dart                 # MaterialApp 및 테마
│   ├── router.dart                    # go_router 라우팅
│   └── app_shell.dart                 # 하단 탭 네비게이션
├── core/
│   ├── models/task.dart               # 공통 Task 모델
│   ├── repositories/
│   │   ├── task_repository.dart       # 데이터 접근 인터페이스
│   │   └── in_memory_task_repository.dart
│   ├── services/firebase/
│   │   └── firestore_task_repository.dart
│   ├── utils/date_helpers.dart
│   └── widgets/
│       ├── task_tile.dart
│       └── empty_state.dart
└── features/
    ├── task/views + viewmodels
    ├── calendar/views
    ├── ocr/views + viewmodels
    ├── auth/views + viewmodels
    └── settings/views + viewmodels
```

### 호출 관계

```text
[태스크 화면 / 달력 / OCR 화면]
               |
               v
       [TaskViewModel]
               |
               v
      [TaskRepository]  <--- 구현체 교체 가능
          /        \
 [InMemory 저장소]  [Firestore 저장소]
```

`taskRepositoryProvider`는 저장소에 대한 공통 인터페이스를 제공한다. 각 화면은 Firebase를 직접 호출하지 않으므로, InMemory와 Firestore 구현을 교체해도 UI 코드를 수정할 필요가 없다.


## 3. 실제 Firebase 저장소 사용 (선택 사항)

현재 기본값은 **Firebase 비활성**이다. Firebase에 연결하려면 Firebase 콘솔에서 프로젝트를 생성하고, Firebase Authentication에서 **Anonymous 로그인**을 활성화하고, Firestore 데이터베이스를 생성한다. 또한 아래 `firestore.rules`에 해당하는 접근 규칙을 배포한다.

Web 환경에서는 Firebase 프로젝트의 웹 앱 설정에서 아래 4가지 값을 확인한 후 명령어로 전달할 수 있다.

```powershell
flutter run -d chrome `
  --dart-define=USE_FIREBASE=true `
  --dart-define=FIREBASE_API_KEY=YOUR_API_KEY `
  --dart-define=FIREBASE_APP_ID=YOUR_APP_ID `
  --dart-define=FIREBASE_SENDER_ID=YOUR_MESSAGING_SENDER_ID `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
```

실제 값을 바꾸어 넣어야 한다. 

`main.dart`는 Firebase 초기화 후 익명 인증을 수행하고 `FirestoreTaskRepository`를 주입한다. 익명 사용자의 UID에 따라 `users/{uid}/tasks/{taskId}`에 데이터가 저장된다. 이 모드는 실제 이메일 계정 로그인 기능이 아니며, 설정 화면의 데모 로그아웃은 UI 상태만 변경한다.


