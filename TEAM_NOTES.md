# Keepy 팀 공유 사항

최종 수정: 2026-11-03 · 대상: 유희일 · 홍서윤 · 조현규 · 이도현

---

## 1. 개발 환경 — 전원 통일 (필수)

| 항목 | 버전 |
|---|---|
| Flutter | **3.47.9 stable** |
| Dart | 3.13.7 (Flutter에 포함) |

- 터미널에서 `flutter --version` → `Flutter 3.47.9 • channel stable` 이 나와야 함.
- 예전에 받아 둔 다른 Flutter가 PATH에 먼저 잡혀 있으면 그쪽으로 빌드됨.
  `where flutter` (Windows) 로 경로 확인하고, 시스템 환경 변수 PATH에는 3.47.9의 `flutter\bin` 하나만 남길 것.
- SDK는 공백·한글 없는 경로에 둘 것 (예: `C:\Dev\...`).
- **Windows 개발자 모드 필수**: 플러그인(shared_preferences 등)이 있는 프로젝트는 심볼릭 링크가 필요함.
  `start ms-settings:developers` → **개발자 모드** 켜기. 안 켜면 `pub get` 때 경고가 나오고 `flutter run -d windows` 빌드가 실패함.
- IDE의 Flutter SDK 경로도 따로 바꿀 것 (IntelliJ: Settings → Languages & Frameworks → Flutter → SDK path, VS Code: `Flutter: Change SDK`).
- 버전이 다르면 `pubspec.lock` 충돌·빌드 결과 차이가 생김.

## 2. 처음 받기 / 실행

```powershell
git clone https://github.com/chohk1003/Keepy.git
cd Keepy
git checkout <본인 브랜치>   # 희일 / 현규 / 도현 / 서윤
flutter pub get
flutter run -d windows      # 또는 -d chrome / 안드로이드 에뮬레이터
```

작업 후 반드시:

```powershell
flutter analyze             # 0건 유지
flutter test                # 전부 통과 유지
```

## 3. 브랜치 규칙 — 개인 구현 후 비교·선정

```
main  ← 비교 후 '선정된 결과'만 올림
 ├ 희일   ┐
 ├ 현규   │ 각자 독립적으로 구현
 ├ 도현   │ (서로의 브랜치에 병합·푸시 금지)
 └ 서윤   ┘
```

- 각자 **본인 브랜치에서만** 작업하고 커밋·푸시함.
- 단계(MP)마다 각자의 결과를 비교 → 팀이 하나를 선정 → **선정된 내용만 `main`에 올림**.
- `dev` 브랜치는 현재 쓰지 않음.
- 이 문서와 여기 적힌 개발 내역은 **`희일` 브랜치 기준**임. 다른 브랜치에는 없음.
- `pubspec.lock`은 커밋함 (앱 프로젝트이므로 버전 고정 목적).
- `희일` 브랜치에 남아 있는 테스트용 커밋 파일(`만튼 파일.txt`, `만든 폴더/`)은 비교 전에 정리. (`main`에는 `README.md`만 있음)

## 4. 코드 구조와 단계별 확장 지점

```
lib/
  main.dart                 앱 시작, 로컬 저장소 열기
  theme.dart                색·그라데이션·모션·글꼴 토큰 (디자인 값은 여기만 수정)
  data/local_store.dart     로컬 저장 (shared_preferences, JSON)
  models/task.dart          Task / TaskTag / DoneEvent + JSON 변환
  state/app_state.dart      상태·설정, 변경 시 0.25초 뒤 자동 저장
  pages/                    home_shell(3단 스와이프), main, date, settings, ocr
  widgets/                  task_tile(스와이프 제스처), square_check, quick_input_bar,
                            week_calendar, task_editor, diff_sliver_list, glass_tab_bar, fx
test/widget_test.dart       위젯 테스트
assets/fonts/               Pretendard (SIL OFL 1.1 — 라이선스 파일 함께 배포)
```

| 단계 | 할 일 | 손댈 곳 |
|---|---|---|
| MP2 | 완료 (로컬 저장·수정·삭제·필터) — 문서·스크린샷만 남음 | README, screenshots/ |
| MP3 | Firebase Auth + Firestore 동기화, 오프라인 후 재연결 병합 | `lib/data/`에 동기화 계층 추가, `AppState.flush()` 뒤에 연결. 설정 화면 '게스트' 행이 로그인 진입점 |
| MP4 | 카메라 + ML Kit 텍스트 인식 | `lib/pages/ocr_pages.dart`의 `recognizeLines()` 하나만 교체 (지금은 샘플 5줄 반환). 검토 화면·일괄 추가는 완성됨 |

## 5. 데이터 형식 (Firestore 문서 설계 시 그대로 사용)

```json
{
  "id": "m3x9k2p0",
  "title": "운영체제 과제",
  "done": false,
  "due": "2026-11-03T00:00:00.000",
  "tags": ["assignment", "team"],
  "createdAt": "2026-11-02T21:40:12.000"
}
```

- `tags` 값: `assignment`(과제) · `lecture`(수업) · `team`(팀 프로젝트) · `personal`(개인)
- 로컬 저장 키: `keepy.tasks.v1`, `keepy.doneLog.v1`, `keepy.settings.v1`
  (구조를 바꾸면 키 버전을 `v2`로 올리고 변환 코드 작성)

## 6. 디자인·조작 규칙

- 기준 문서는 **UI설계서**. 피그마 시안은 참고하지 않음.
- 화면 문구는 **단어 위주** (문장 금지).
- 스타일은 Apple HIG 참고: iOS 시스템 색, 큰 제목, 유리(블러) 바, 물결(ripple) 효과 없음.
- 체크박스는 **네모**, 태스크 왼쪽 색 막대(액센트 바)는 **쓰지 않음**.
- 색·그라데이션·애니메이션 시간은 `theme.dart`의 `K`, `Motion`, `T`만 사용. 화면 파일에 색 코드 직접 쓰지 말 것.
- ⚠ `Motion.spring`은 1을 넘어 튀는 곡선 → **그림자(boxShadow)·투명도 보간에 쓰면 오류 남** (실제로 테스트 실패했던 원인). 그런 곳은 `Motion.out`.
- 할 일 분류: **지연**(기한 지남·미완료) · 할 일 · **늦은 완료**(지연 상태에서 완료) · 완료. 목록은 모두 **날짜순**.
  - 지연 기준: 기한이 있으면 기한 다음 날 0시, 없으면 만든 뒤 N일(설정 '분류', 기본 3일, 끌 수 있음).
  - 완료 시점 `doneAt`을 저장해서 늦은 완료를 판정 (`lib/state/app_state.dart`의 `statusOf`).
- 태스크 왼쪽 끌기 = 아이폰 알림식 액션: 카드가 줄어들며 [날짜][태그] 등장, 버튼 폭까지 72%만 따라오고 그 뒤는 고무줄 저항, 놓아도 유지.
  [날짜] 끌기 = 그대로 / +1~+7 스냅 다이얼, [태그] 끌기 = 그대로 / 사용 빈도순 태그 / 없음. 패널은 두 버튼을 합친 영역 전체 사용.
  카드·바깥을 누르거나 끌면 닫힘. 열린 채 화면 밖으로 절반 이상 스크롤되면 닫힘.
- 태스크 오른쪽 끌기 = 왼쪽에 삭제 버튼이 나온 상태로 스냅(누르면 삭제). 손가락을 230px 이상 끌면 바로 삭제.
- 끄는 도중 손가락이 위·아래로 36px 이상 벗어나면 그 동작(날짜·태그·삭제) 취소.
- 목록 아래 끝 72px(입력 바 바로 위)에 들어온 항목은 작아지며 흐려져 사라지고 터치를 받지 않음 → 그 영역에서 좌우로 밀면 탭 전환 (`EdgeFade`).
- 입력 바는 **누를 때만** 입력 시작. 입력 바 위에서 좌우로 밀면 탭 전환.
- 캘린더 좌우 = 주 단위.
- 날짜 화면의 날짜 이동은 **좌우 버튼·좌우 제스처를 쓰지 않음** (화면 전환 스와이프와 겹치기 때문).
  목록 끝에서 임계값(72px)을 넘겨 위·아래로 끌고 놓으면 **할 일이 있는 날로만** 이동.
  캘린더에서 직접 고른 날은 비어 있어도 그 날짜로 추가 가능.
- 캘린더 칸: 둥근 네모. 파랑 = 남은 할 일, 초록 = 전부 완료(깃허브 잔디처럼 개수가 많을수록 진하게), 오늘 = 그라데이션 숫자 + 밑줄, 선택 = 그라데이션 채움.
- 날짜 이동 시 날짜 제목이 **제스처 진행도와 동기화**되어 넘어감. 오른쪽 아래 [오늘] 버튼으로 복귀.
- 토스트(실행 취소 알림)는 **0.6초**만 표시, 다른 곳을 누르면 즉시 닫힘 (`lib/widgets/toast.dart`).
- 아이콘은 `CupertinoIcons` 사용 → `pubspec.yaml`의 `cupertino_icons` 패키지 빠지면 아이콘이 네모(□)로 깨짐.
- 화면 배치: **설정(왼쪽) ← 메인 → 날짜(오른쪽)**.
  요구사항 명세서의 "왼쪽으로 스와이프 시 설정"은 손가락 방향과 반대라 헷갈림 → 문서 수정 필요
  (손가락을 오른쪽으로 밀면 설정이 나옴).

## 7. 테스트 작성 규칙

- 흐르는 그라데이션 등 **반복 애니메이션이 있어서 `pumpAndSettle()`은 끝나지 않음**.
  `test/widget_test.dart`의 `settle()` 처럼 시간을 정해 `pump()` 할 것.
- 체크는 0.52초 뒤에 실제 완료 처리됨 (체크 애니메이션을 보여 주려고 지연). 테스트에서 이 시간을 기다릴 것.

## 8. 아이폰에서 확인하는 방법

iOS 앱 빌드는 **macOS + Xcode가 있어야만** 가능 (Windows에서는 불가).

**A. Mac이 있을 때 (무료 Apple 계정으로 가능)**
1. Mac에 Xcode와 Flutter 3.47.9 설치 → `flutter doctor`가 알려 주는 빠진 항목(CocoaPods 등)까지 설치
2. `open ios/Runner.xcworkspace` → Runner → Signing & Capabilities → Team에 본인 Apple 계정(Personal Team) 선택
   - 번들 ID `kr.ac.hansung.keepy`가 이미 쓰이고 있다고 나오면 `kr.ac.hansung.keepy.<이름>` 처럼 바꿔서 테스트
3. 아이폰 USB 연결 → 아이폰 **설정 > 개인정보 보호 및 보안 > 개발자 모드** 켜기 (재부팅)
4. `flutter run` (기기 선택) → 처음 실행 시 아이폰 **설정 > 일반 > VPN 및 기기 관리**에서 개발자 앱 신뢰
5. 무료 계정은 설치한 앱이 **7일 뒤 만료** → 다시 `flutter run` 하면 됨

**B. Mac이 없을 때 — 웹으로 화면·조작만 확인**
```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```
- PC와 아이폰을 같은 Wi-Fi에 연결 → 아이폰 Safari에서 `http://<PC의 IP>:8080`
  (PC IP는 `ipconfig`의 IPv4 주소, Windows 방화벽에서 8080 허용 필요)
- 한계: 진동(햅틱) 없음, 카메라·ML Kit(MP4) 확인 불가, 실제 앱과 스크롤 감이 약간 다름

**C. 여러 명이 실제 앱으로 받아 보려면**
- TestFlight 배포 = **유료 Apple Developer Program 가입 필요**
- Mac이 없으면 Codemagic, GitHub Actions(macOS) 같은 클라우드 Mac 빌드 사용

## 9. 제출 전 체크 (심사기준)

- [ ] **폴더 구조**: 심사기준은 `app/` (앱 소스) + `README.md` + `screenshots/` + `prompts_log.md` 를 요구.
      지금 저장소는 루트가 바로 Flutter 프로젝트 → `app/`으로 옮길지 **팀 결정 필요** (늦을수록 경로 충돌 커짐)
- [ ] `prompts_log.md`: AI 도구 프롬프트 + **채택/수정 판단** 기록 — 각자 쓴 것 모을 것 (모든 MP 공통)
- [ ] `screenshots/`: MP1 목록·추가·완료·빈 상태 / MP2 수정·삭제·필터 + 재시작 전·후 비교
- [ ] MP2 README: **저장 방식 선택 이유를 대안과 비교** (shared_preferences vs sqlite vs Hive 등) — 아직 없음
- [ ] 민감정보: API 키·개인정보 사진 커밋 금지. MP3부터 키는 `.env`로 분리, 저장소에는 `.env.example`만 (NFR-06, CST-04)
- [ ] MP4: 비행기 모드 동작 확인, 원본 사진 미저장, 카메라 권한 거부 안내, **처리 시간 측정값** README 기록

## 10. 현재 상태 · 알려진 이슈

- `flutter analyze` 0건, `flutter test` 6개 전부 통과 (2026-11-03, Flutter 3.47.9).
- 실기기(아이폰·안드로이드) 동작은 아직 아무도 확인 안 함.
- 첫 실행 시 샘플 할 일 7개가 들어감 (제출 스크린샷 전에 지우거나 그대로 쓸지 결정).
- 촬영 화면의 인식 결과는 '샘플' 표시가 붙은 가짜 데이터 (MP4에서 교체).
