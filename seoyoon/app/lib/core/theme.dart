import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS 시스템 색을 기준으로 한 Keepy 팔레트.
///
/// prompts_log #3: "그라데이션 칼라 적극 활용, 디자인은 애플 참고"
/// v0.3: 메인 색을 하늘색·파란색 계열로 (사용자 요청).
/// → 바탕·글자는 하늘빛이 도는 회청색으로 차분하게,
///   강조(체크·전송·선택 날짜·탭)는 하늘→파랑 그라데이션으로 통일한다.
/// 지금 다크 모드인지 (v0.4). KeepyApp 이 설정·시스템 값을 보고 매 빌드마다 정한다.
class KeepyPalette {
  KeepyPalette._();
  static bool dark = false;
}

class KeepyColors {
  KeepyColors._();

  static bool get _d => KeepyPalette.dark;

  // 바탕·글자: 라이트 = 하늘빛 회청색, 다크 = 깊은 남색 계열 (모드에 따라 바뀜)
  static Color get background => _d ? const Color(0xFF0D131B) : const Color(0xFFF1F5FA);
  static Color get card => _d ? const Color(0xFF18212D) : const Color(0xFFFFFFFF);
  static Color get label => _d ? const Color(0xFFEEF3FA) : const Color(0xFF1A2433);
  static Color get secondaryLabel => _d ? const Color(0xFF8E9AAE) : const Color(0xFF8792A5);
  static Color get tertiaryLabel => _d ? const Color(0xFF4B576A) : const Color(0xFFC3CCD8);
  static Color get separator => _d ? const Color(0xFF253041) : const Color(0xFFE2E8F0);
  static Color get fill => _d ? const Color(0xFF222C3A) : const Color(0xFFEBF1F8);
  static Color get skyTint => _d ? const Color(0xFF14304D) : const Color(0xFFE6F4FF); // 옅은 하늘 바탕
  static Color get doneCard => _d ? const Color(0xFF141C26) : const Color(0xFFF8FAFD); // 완료한 일 카드
  /// 카드 테두리 (v0.5): 그림자만으로 흐릿하던 카드 경계를 또렷하게.
  static Color get hairline => _d ? const Color(0x17FFFFFF) : const Color(0x121A2433);
  static Color get bar => _d ? const Color(0xD9141B25) : const Color(0xD9F8FBFE); // 반투명 탭 바

  // 메인 색: 하늘색 → 파란색 (두 모드 공통)
  static const sky = Color(0xFF4CC3FF);
  static const blue = Color(0xFF2F7BFF);
  static const deepBlue = Color(0xFF1E5EEB);

  static const red = Color(0xFFFF4D5E);
  static const orange = Color(0xFFFF9F2E);
  static const green = Color(0xFF2FC27A);

  /// 캘린더 칸 채움 (prompts_log #8: 깃허브처럼 완료가 많을수록 진하게).
  /// [0] = 할 일은 있지만 아직 완료 0개, [1..4] = 완료 개수 단계.
  static List<Color> get heat => _d ? _heatDark : _heatLight;
  static const _heatLight = <Color>[
    Color(0xFFE3ECF7),
    Color(0xFFCDF1DD),
    Color(0xFF94DDB5),
    Color(0xFF45C283),
    Color(0xFF1F9A5E),
  ];
  static const _heatDark = <Color>[
    Color(0xFF233041),
    Color(0xFF173B2C),
    Color(0xFF1E5E40),
    Color(0xFF2A8A58),
    Color(0xFF3FBF7A),
  ];
}

class KeepyGradients {
  KeepyGradients._();

  /// 메인 그라데이션: 하늘색 → 파란색.
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4CC3FF), Color(0xFF2F7BFF)],
  );

  static LinearGradient get soft => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: KeepyPalette.dark
            ? const [Color(0xFF13283F), Color(0xFF14223A)]
            : const [Color(0xFFE9F7FF), Color(0xFFE3EEFF)],
      );

  static const delete = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A85), Color(0xFFFF4D5E)],
  );

  static const delayed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFBE55), Color(0xFFFF8A3D)],
  );

  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3FD48C), Color(0xFF22B3C9)],
  );

  static const dateAction = primary;

  /// 미니게임 하늘 배경 (다크 모드에서는 밤하늘).
  static LinearGradient get sky => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: KeepyPalette.dark
            ? const [Color(0xFF0B1A33), Color(0xFF16294A)]
            : const [Color(0xFFBFE6FF), Color(0xFFEAF6FF)],
      );
}

/// 애니메이션 시간·곡선.
///
/// NFR-01: 스와이프 전환·완료 토글 반응은 0.3초 이내.
/// prompts_log #4: 탄성(되튐) 곡선은 1을 넘으므로 그림자 같은
/// "음수가 되면 안 되는 값"에는 절대 쓰지 않는다 → [KeepyMotion.settle].
class KeepyMotion {
  KeepyMotion._();

  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 280);

  /// 되튐 없는 기본 곡선 — 그림자·크기·투명도 어디에 써도 안전.
  static const Curve settle = Curves.easeOutCubic;

  /// 되튐 있는 곡선 — 위치·스케일에만 사용 (그림자/blur 금지).
  static const Curve pop = Curves.easeOutBack;
}

class KeepyText {
  KeepyText._();

  /// 나눔스퀘어라운드 — 미세하게 둥근 고딕 (pubspec.yaml fonts).
  static const family = 'NanumSquareRound';

  // 글자 크기는 v0.2 보다 한 단계씩 작게.
  static TextStyle get largeTitle => TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: KeepyColors.label,
    height: 1.2,
  );
  static TextStyle get title => TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: KeepyColors.label,
  );
  static TextStyle get headline => TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: KeepyColors.label,
  );
  static TextStyle get body => TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    color: KeepyColors.label,
  );
  static TextStyle get caption => TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KeepyColors.secondaryLabel,
  );
  static TextStyle get footnote => TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: KeepyColors.secondaryLabel,
  );
}

class KeepyRadius {
  KeepyRadius._();
  static const card = 16.0;
  static const control = 12.0;
}

ThemeData buildKeepyTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: KeepyColors.blue,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: KeepyColors.blue,
    surface: KeepyColors.card,
    onSurface: KeepyColors.label,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: KeepyText.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: KeepyColors.background,
    canvasColor: KeepyColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      primaryColor: KeepyColors.blue,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: KeepyColors.blue,
      selectionColor: Color(0x552F7BFF),
      selectionHandleColor: KeepyColors.blue,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
