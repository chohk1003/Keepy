# Keepy

할 일 앱 — UI설계서 기준, Apple HIG 스타일 조작·디자인

## 실행

```powershell
flutter pub get
flutter run -d windows   # 또는 -d chrome / 에뮬레이터
flutter analyze
flutter test
```

## 조작

| 위치 | 조작 | 결과 |
|---|---|---|
| 전체 | 좌우 스와이프 / 하단 유리 탭 바 | 설정 ← 메인 → 날짜 (탭 알약이 스와이프를 따라옴) |
| 태스크 | 네모 체크 | 체크 그리기 + 입자 효과 + 취소선 → 잠시 뒤 '완료'로 이동, 토스트에서 취소 |
| 태스크 | 왼쪽으로 끌기 | 카드가 줄어들며 [날짜][태그] 버튼 등장(고무줄 저항, 놓아도 유지). [날짜] 끌기 = 그대로/+1~+7, [태그] 끌기 = 그대로/자주 쓰는 순/없음. 카드·바깥 터치, 화면 밖 스크롤 시 닫힘 |
| 태스크 | 오른쪽으로 끌기 | 삭제 버튼이 나온 상태로 스냅(누르면 삭제), 더 세게 끌면 바로 삭제. 끄는 중 위·아래로 벗어나면 취소 |
| 태스크 | 탭 | 편집 시트 (제목·태그·날짜 휠 피커·삭제) |
| 메인 | 상단 슬라이딩 세그먼트 | 전체 / 미완료 / 완료 |
| 입력 바 | 포커스 | 태그 칩(#과제 #수업 #팀 프로젝트 #개인), 1~100자일 때 전송 활성, 빈 입력은 흔들림 |
| 입력 바 | 카메라 | 촬영 → 인식 결과 검토 → N개 추가 (현재 샘플, MP4에서 ML Kit로 교체) |
| 날짜 | 캘린더 좌우 스와이프 / 날짜 탭 | 주 단위 스냅 이동. 고른 날은 비어 있어도 그 날짜로 바로 추가 |
| 날짜 | 목록 끝에서 더 세게 위·아래로 끌기 | 날짜 제목이 손가락을 따라 넘어가고, 임계값을 넘긴 채 놓으면 **할 일이 있는** 다음·이전 날로 이동 |
| 날짜 | 오른쪽 아래 [오늘] | 오늘로 바로 이동 |
| 메인·날짜 | 목록 아래 끝 · 입력 바 | 항목이 작아지며 흐려져 사라지는 영역과 입력 바 위에서 좌우로 밀면 탭 전환. 입력은 누를 때만 |
| 메인 | 분류 | 지연 · 할 일 · 늦은 완료 · 완료, 각각 날짜순 |
| 날짜 | 캘린더 칸 색 | 파랑 = 남은 할 일(많을수록 진함), 초록 = 전부 완료(완료가 많을수록 진함), 오늘 = 그라데이션 숫자 + 밑줄 |
| 전체 | 토스트 | 0.6초만 표시, 다른 곳을 누르면 즉시 닫힘 |
| 설정 | 달력 행 / 이번 주 위치 / 완료율(바·원형·그래프) | 날짜 화면에 즉시 반영 |

## 구조

```
lib/
  main.dart                  앱 시작, 로컬 저장소 열기
  theme.dart                 컬러·그라데이션·모션·타이포 토큰
  data/local_store.dart      shared_preferences JSON 저장 (FR-10)
  models/task.dart           Task, TaskTag, DoneEvent (+ JSON)
  state/app_state.dart       상태·설정, 변경 시 자동 저장
  pages/                     home_shell, main, date, settings, ocr
  widgets/
    task_tile.dart           스냅 다이얼·삭제 제스처
    square_check.dart        네모 체크 + 입자 효과, 취소선 텍스트
    diff_sliver_list.dart    추가·삭제·이동 애니메이션 목록
    quick_input_bar.dart     유리 입력 바, 태그 칩
    week_calendar.dart       주 스와이프 캘린더, 완료율
    glass_tab_bar.dart       유리 탭 바
    task_editor.dart         편집 시트
    fx.dart                  눌림·그라데이션·유리·링·롤링 숫자 등 공통 효과
assets/fonts/                Pretendard (SIL OFL 1.1)
```

## 남은 단계

- MP3: Firebase Auth·Firestore 동기화 (`data/` 계층 위에 추가)
- MP4: `ocr_pages.dart`의 `recognizeLines()`를 카메라 + ML Kit 텍스트 인식으로 교체
