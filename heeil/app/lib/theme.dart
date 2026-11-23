import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 테마 선택 — 설정에서 고른다. [AppTheme.system] 은 기기 설정을 따른다.
enum AppTheme { system, light, dark }

String themeLabel(AppTheme t) => switch (t) {
  AppTheme.system => '시스템',
  AppTheme.light => '라이트',
  AppTheme.dark => '다크',
};

bool _dark = false;

/// 지금 그리고 있는 팔레트가 다크인가. [K]·[T] 의 색이 여기에 따라 갈린다.
bool get isDarkTone => _dark;

/// 앱 뿌리(`KeepyApp`)에서 화면을 다시 그리기 직전에 한 번 정한다.
/// 중간에 바뀌면 뿌리가 함께 다시 그려지므로, 그 사이 색은 흔들리지 않는다.
void applyTone(bool dark) => _dark = dark;

/// 라이트·다크 한 쌍. 호출부는 이름만 쓰고 어느 쪽인지 신경 쓰지 않는다.
Color _tone(Color light, Color dark) => _dark ? dark : light;

/// 통계용 색 — 같은 색을 네온사인처럼 또렷하게 올린다.
/// 막대가 얇아서 원래 태그색으로는 무슨 색인지 읽히지 않기 때문이다.
Color vivid(Color c) {
  final h = HSLColor.fromColor(c);
  return h
      .withSaturation((h.saturation * 1.8).clamp(0.0, 1.0))
      .withLightness(_dark ? 0.6 : 0.5)
      .toColor();
}

/// 디자인 토큰 — Apple Human Interface Guidelines 시스템 컬러 기준
abstract final class K {
  static const font = 'Pretendard';

  // 시스템 컬러 — 다크에서는 보라를 한 단계 밝게 (어두운 바탕에서 읽히게)
  static Color get blue =>
      _tone(const Color(0xFF6549C9), const Color(0xFFA290F2));
  static Color get indigo => blue;
  static const purple = Color(0xFFBF5AF2);
  static const pink = Color(0xFFFF375F);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9F0A);
  static const green = Color(0xFF30D158);
  static const mint = Color(0xFF00C7BE);

  // 배경·라벨
  static Color get bg =>
      _tone(const Color(0xFFFFFFFF), const Color(0xFF14121C));
  static Color get card =>
      _tone(const Color(0xFFFFFFFF), const Color(0xFF1D1B27));

  /// 캐릭터 띠·방 바탕. 노랑은 캐릭터(오리)만 쓰도록 비워 두고,
  /// 띠는 깊은 보라로 내려 캐릭터와 네온 막대가 떠 보이게 한다.
  static Color get room =>
      _tone(const Color(0xFF2E2749), const Color(0xFF221C38));
  static Color get roomFloor =>
      _tone(const Color(0xFF241E3B), const Color(0xFF1A162B));

  /// 띠 위에 올라가는 글자·아이콘 색 (띠가 어두우므로 밝다)
  static Color get onRoom =>
      _tone(const Color(0xFFF2EEFF), const Color(0xFFEDE9FA));

  /// 띠 위의 보조 글자 (라벨 등)
  static Color get onRoomDim => onRoom.withValues(alpha: .66);

  /// 띠 위의 강조색 (완료율처럼 눈이 먼저 가야 하는 것)
  static const onRoomAccent = Color(0xFFC3AEFF);

  /// 캐릭터 노랑 — 오리가 가진 색. 화면에서 '우리 캐릭터'를 가리킬 때만 쓴다
  /// (고른 탭, 기록이 있는 날처럼). 넓은 바탕에는 쓰지 않는다.
  static Color get duck =>
      _tone(const Color(0xFFFFD957), const Color(0xFFE9C659));
  static Color get ink =>
      _tone(const Color(0xFF302547), const Color(0xFFECEAF6));
  static const crumb = Color(0xFFFF7354);
  static Color get label => ink;
  static Color get label2 =>
      _tone(const Color(0x993C3C43), const Color(0xA8E6E3F2)); // secondaryLabel
  static Color get label3 =>
      _tone(const Color(0x4D3C3C43), const Color(0x66E6E3F2)); // tertiaryLabel
  static Color get separator =>
      _tone(const Color(0x333C3C43), const Color(0x2EE6E3F2));
  static Color get fill =>
      _tone(const Color(0x14787880), const Color(0x1FFFFFFF));
  static Color get fill2 =>
      _tone(const Color(0x29787880), const Color(0x33FFFFFF));
  static Color get gray3 =>
      _tone(const Color(0xFFC7C7CC), const Color(0xFF4A4A55));
  static Color get gray5 =>
      _tone(const Color(0xFFE5E5EA), const Color(0xFF2A2A35));

  // 서윤님 구현에서 가져온 '정돈된 골격' — 색이 아니라 바탕·테두리·모서리 규칙
  /// 목록 바탕 (카드가 떠 보이게)
  static Color get bgSoft =>
      _tone(const Color(0xFFF6F4FB), const Color(0xFF100E18));

  /// 카드 테두리 (라이트는 잉크 7%, 다크는 흰 14%)
  static Color get hairline =>
      _tone(const Color(0x121A2433), const Color(0x24FFFFFF));

  /// 완료한 타일 배경
  static Color get doneCard =>
      _tone(const Color(0xFFFAF9FD), const Color(0xFF191723));

  /// 칩·아이콘 배경 (보라 12%)
  static Color get tint => blue.withValues(alpha: _dark ? .22 : .12);
  static const radiusCard = 16.0;
  static const radiusControl = 12.0;

  // 상태 색 — 화면 파일에서 직접 쓰지 말고 이 이름으로 (TEAM_NOTES 6장)
  /// 늦은 완료
  static Color get lateInk =>
      _tone(const Color(0xFFAC8043), const Color(0xFFD7A860));

  /// 지연·삭제 바탕
  static Color get overdueInk =>
      _tone(const Color(0xFFB75D53), const Color(0xFFE08A7E));

  /// 입력 바 바탕
  static Color get inputFill =>
      _tone(const Color(0xFFF0EDFF), const Color(0xFF211E30));

  /// 입력 바 테두리
  static Color get inputLine =>
      _tone(const Color(0xFFB4A4F4), const Color(0xFF4C3F86));
  static const deleteColors = [Color(0xFFFF453A), Color(0xFFFF2D55)];

  // 그라데이션
  static LinearGradient get brand => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, blue],
  );
  static LinearGradient get brand2 => brand;
  static LinearGradient get danger => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [overdueInk, overdueInk],
  );
  static LinearGradient get late => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lateInk, lateInk],
  );
  static LinearGradient get success => brand;

  /// 카드 그림자 — [elevation] 은 0~1. 입력을 clamp 하는 것이 핵심이다:
  /// 탄성 곡선([Motion.spring]) 값이 들어와도 blurRadius 가 음수가 되지 않는다.
  /// 다크에서는 그림자가 보이지 않으므로 조금 더 짙게 깐다.
  static List<BoxShadow> cardShadow([double elevation = 0]) {
    final e = elevation.clamp(0.0, 1.0);
    return [
      BoxShadow(
        color: const Color(0xFF0F172A)
            .withValues(alpha: _dark ? 0.18 + 0.16 * e : 0.04 + 0.06 * e),
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
  static TextStyle get largeTitle => TextStyle(
    fontFamily: K.font,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.15,
    color: K.label,
  );
  static TextStyle get title2 => TextStyle(
    fontFamily: K.font,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: K.label,
  );
  static TextStyle get title3 => TextStyle(
    fontFamily: K.font,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: K.label,
  );
  static TextStyle get headline => TextStyle(
    fontFamily: K.font,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: K.label,
  );
  static TextStyle get body => TextStyle(
    fontFamily: K.font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    color: K.label,
  );
  static TextStyle get subhead => TextStyle(
    fontFamily: K.font,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: K.label,
  );
  static TextStyle get footnote => TextStyle(
    fontFamily: K.font,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: K.label2,
  );
  static TextStyle get caption => TextStyle(
    fontFamily: K.font,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: K.label2,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: K.blue,
    brightness: isDarkTone ? Brightness.dark : Brightness.light,
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
    textSelectionTheme: TextSelectionThemeData(cursorColor: K.blue),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF01C1C1E),
      elevation: 0,
      actionTextColor: const Color(0xFF64D2FF),
      contentTextStyle: const TextStyle(
        fontFamily: K.font,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: K.bg,
      dragHandleColor: K.gray3,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
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
