import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 디자인 토큰 — Apple Human Interface Guidelines 시스템 컬러 기준
abstract final class K {
  static const font = 'Pretendard';

  // 시스템 컬러
  static const blue = Color(0xFF6549C9);
  static const indigo = Color(0xFF6549C9);
  static const purple = Color(0xFFBF5AF2);
  static const pink = Color(0xFFFF375F);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9F0A);
  static const green = Color(0xFF30D158);
  static const mint = Color(0xFF00C7BE);

  // 배경·라벨
  static const bg = Color(0xFFFFFFFF);
  static const room = Color(0xFFFFD957);
  static const roomFloor = Color(0xFFFFB85B);
  static const ink = Color(0xFF302547);
  static const crumb = Color(0xFFFF7354);
  static const card = Color(0xFFFFFFFF);
  static const label = ink;
  static const label2 = Color(0x993C3C43); // secondaryLabel
  static const label3 = Color(0x4D3C3C43); // tertiaryLabel
  static const separator = Color(0x333C3C43);
  static const fill = Color(0x14787880);
  static const fill2 = Color(0x29787880);
  static const gray3 = Color(0xFFC7C7CC);
  static const gray5 = Color(0xFFE5E5EA);

  // 서윤님 구현에서 가져온 '정돈된 골격' — 색이 아니라 바탕·테두리·모서리 규칙
  static const bgSoft = Color(0xFFF6F4FB); // 목록 바탕 (흰 카드가 떠 보이게)
  static const hairline = Color(0x121A2433); // 카드 테두리 (잉크 7%)
  static const doneCard = Color(0xFFFAF9FD); // 완료한 타일 배경
  static const tint = Color(0x1F6549C9); // 칩·아이콘 배경 (blue 12%)
  static const radiusCard = 16.0;
  static const radiusControl = 12.0;

  // 상태 색 — 화면 파일에서 직접 쓰지 말고 이 이름으로 (TEAM_NOTES 6장)
  static const lateInk = Color(0xFFAC8043); // 늦은 완료
  static const overdueInk = Color(0xFFB75D53); // 지연·삭제 바탕
  static const inputFill = Color(0xFFF0EDFF); // 입력 바 바탕
  static const inputLine = Color(0xFFB4A4F4); // 입력 바 테두리
  static const deleteColors = [Color(0xFFFF453A), Color(0xFFFF2D55)];

  // 그라데이션
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, blue],
  );
  static const brand2 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, blue],
  );
  static const danger = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB75D53), Color(0xFFB75D53)],
  );
  static const late = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFAC8043), Color(0xFFAC8043)],
  );
  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, blue],
  );

  /// 카드 그림자 — [elevation] 은 0~1. 입력을 clamp 하는 것이 핵심이다:
  /// 탄성 곡선([Motion.spring]) 값이 들어와도 blurRadius 가 음수가 되지 않는다.
  static List<BoxShadow> cardShadow([double elevation = 0]) {
    final e = elevation.clamp(0.0, 1.0);
    return [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.04 + 0.06 * e),
        blurRadius: 10 + 14 * e,
        offset: Offset(0, 2 + 6 * e),
      ),
    ];
  }

  static List<BoxShadow> glow(Color c, {double a = 0.35, double blur = 16}) => [
    BoxShadow(
      color: c.withValues(alpha: a),
      blurRadius: blur,
      offset: const Offset(0, 6),
    ),
  ];
}

/// 모션 — 짧고 탄성 있는 스프링
/// 주의: [spring]은 1을 넘어 튀므로 그림자(boxShadow)·투명도를 보간하는 곳에는 쓰지 말 것
/// (그림자 흐림 값이 음수가 되어 assertion 발생). 그런 곳은 [out] 사용.
abstract final class Motion {
  static const spring = Cubic(0.2, 0.9, 0.25, 1.12);
  static const out = Curves.easeOutCubic;
  // Direct manipulation remains spring driven; these timings cover UI responses.
  static const press = Duration(milliseconds: 90);
  static const feedback = Duration(milliseconds: 200);
  static const navigation = Duration(milliseconds: 220);
  static const expansion = Duration(milliseconds: 280);
  static const sheet = feedback;
  static const dismiss = Duration(milliseconds: 160);
  static const chart = Duration(milliseconds: 300);
  static const celebration = Duration(milliseconds: 550);
  static const delivery = Duration(milliseconds: 1250);

  /// 계속 도는 장식용 움직임 (떠다니기·스캔 띠). 조작 반응과 섞이지 않게 느리게.
  static const ambient = Duration(milliseconds: 2400);
}

/// 타이포그래피 — iOS 텍스트 스타일 크기
abstract final class T {
  static const largeTitle = TextStyle(
    fontFamily: K.font,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.15,
    color: K.label,
  );
  static const title2 = TextStyle(
    fontFamily: K.font,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: K.label,
  );
  static const title3 = TextStyle(
    fontFamily: K.font,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: K.label,
  );
  static const headline = TextStyle(
    fontFamily: K.font,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: K.label,
  );
  static const body = TextStyle(
    fontFamily: K.font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    color: K.label,
  );
  static const subhead = TextStyle(
    fontFamily: K.font,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: K.label,
  );
  static const footnote = TextStyle(
    fontFamily: K.font,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: K.label2,
  );
  static const caption = TextStyle(
    fontFamily: K.font,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: K.label2,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: K.blue,
    primary: K.blue,
    surface: K.card,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: K.font,
    colorScheme: scheme,
    // 흰 카드가 떠 보이도록 바탕만 아주 옅게 (서윤님 #F1F5FA 자리)
    scaffoldBackgroundColor: K.bgSoft,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: K.blue),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xF01C1C1E),
      elevation: 0,
      actionTextColor: Color(0xFF64D2FF),
      contentTextStyle: TextStyle(
        fontFamily: K.font,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: K.bg,
      dragHandleColor: K.gray3,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: K.blue,
      scaffoldBackgroundColor: K.bg,
      textTheme: CupertinoTextThemeData(
        primaryColor: K.blue,
        textStyle: TextStyle(
          fontFamily: K.font,
          fontSize: 17,
          letterSpacing: -0.4,
          color: K.label,
        ),
        navLargeTitleTextStyle: T.largeTitle,
        navTitleTextStyle: T.headline,
        dateTimePickerTextStyle: TextStyle(
          fontFamily: K.font,
          fontSize: 21,
          color: K.label,
        ),
      ),
    ),
  );
}
