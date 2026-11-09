import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 디자인 토큰 — Apple Human Interface Guidelines 시스템 컬러 기준
abstract final class K {
  static const font = 'Pretendard';

  // 시스템 컬러
  static const blue = Color(0xFF0A84FF);
  static const indigo = Color(0xFF5E5CE6);
  static const purple = Color(0xFFBF5AF2);
  static const pink = Color(0xFFFF375F);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9F0A);
  static const green = Color(0xFF30D158);
  static const mint = Color(0xFF00C7BE);

  // 배경·라벨
  static const bg = Color(0xFFF2F2F7); // systemGroupedBackground
  static const card = Color(0xFFFFFFFF);
  static const label = Color(0xFF000000);
  static const label2 = Color(0x993C3C43); // secondaryLabel
  static const label3 = Color(0x4D3C3C43); // tertiaryLabel
  static const separator = Color(0x333C3C43);
  static const fill = Color(0x14787880);
  static const fill2 = Color(0x29787880);
  static const gray3 = Color(0xFFC7C7CC);
  static const gray5 = Color(0xFFE5E5EA);

  // 그라데이션
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
  );
  static const brand2 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
  );
  static const danger = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF453A), Color(0xFFFF2D55)],
  );
  static const late = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9F0A), Color(0xFFFF6B3D)],
  );
  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF30D158), Color(0xFF00C7BE)],
  );

  static const shadow = [
    BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 6)),
  ];

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
  static const fast = Duration(milliseconds: 160);
  static const med = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
}

/// 타이포그래피 — iOS 텍스트 스타일 크기
abstract final class T {
  static const largeTitle = TextStyle(
    fontFamily: K.font,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.15,
    color: K.label,
  );
  static const title2 = TextStyle(
    fontFamily: K.font,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: K.label,
  );
  static const title3 = TextStyle(
    fontFamily: K.font,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: K.label,
  );
  static const headline = TextStyle(
    fontFamily: K.font,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: K.label,
  );
  static const body = TextStyle(
    fontFamily: K.font,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    color: K.label,
  );
  static const subhead = TextStyle(
    fontFamily: K.font,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: K.label,
  );
  static const footnote = TextStyle(
    fontFamily: K.font,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: K.label2,
  );
  static const caption = TextStyle(
    fontFamily: K.font,
    fontSize: 12,
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
    scaffoldBackgroundColor: K.bg,
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
