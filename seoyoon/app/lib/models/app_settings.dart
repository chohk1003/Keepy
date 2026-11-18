import 'task.dart' show defaultTags;

/// 화면 모드 (v0.4): 시스템 설정 따르기 / 라이트 / 다크.
enum AppearanceMode { system, light, dark }

extension AppearanceModeLabel on AppearanceMode {
  String get label => switch (this) {
        AppearanceMode.system => '시스템',
        AppearanceMode.light => '라이트',
        AppearanceMode.dark => '다크',
      };
}

/// 미니게임 기본 캐릭터 (v0.4).
enum CharacterStyle { boy, girl, photo }

/// 미니게임 펫 (v0.4).
enum PetKind { none, dog, cat, rabbit }

extension PetKindLabel on PetKind {
  String get label => switch (this) {
        PetKind.none => '없음',
        PetKind.dog => '강아지',
        PetKind.cat => '고양이',
        PetKind.rabbit => '토끼',
      };
}

/// 금일 완료율 형태 (UI 설계서 01-3).
enum CompletionStyle { bar, ring, graph }

extension CompletionStyleLabel on CompletionStyle {
  String get label => switch (this) {
        CompletionStyle.bar => '바',
        CompletionStyle.ring => '원형',
        CompletionStyle.graph => '그래프',
      };
}

/// 미리 알림 선택지: 0 = 당일, 1 = 1일 전 …
const remindOptions = <int>[0, 1, 2, 3];

String remindLabel(int daysBefore) => daysBefore == 0 ? '당일' : '$daysBefore일 전';

/// 앱 설정 (설정 화면 01).
class AppSettings {
  const AppSettings({
    this.userName = '키피 사용자',
    this.email = '',
    this.notificationsEnabled = true,
    this.remindDaysBefore = 1,
    this.remindMinutes = 9 * 60,
    this.eclassConnected = false,
    this.everytimeConnected = false,
    this.calendarRows = 2,
    this.currentWeekRow = 1,
    this.completionStyle = CompletionStyle.bar,
    this.delayDays = 3,
    this.tags = defaultTags,
    this.miniGameEnabled = false,
    this.characterPixels,
    this.appearance = AppearanceMode.system,
    this.characterStyle = CharacterStyle.boy,
    this.pet = PetKind.none,
  });

  final String userName;
  final String email;

  // 1. 계정 및 알림
  final bool notificationsEnabled;
  final int remindDaysBefore;
  final int remindMinutes; // 0시 기준 분 (540 = 오전 9:00)

  // 2. 외부 서비스 연동
  final bool eclassConnected;
  final bool everytimeConnected;

  // 3. 날짜 화면 옵션
  final int calendarRows; // {1,2,3,4}
  final int currentWeekRow; // {1..calendarRows}
  final CompletionStyle completionStyle;

  // 4. 할 일 분류 (prompts_log #11)
  final int delayDays; // 기한 없는 일이 '지연'이 되기까지 일수

  // 5. 태그 (v0.3: 사용자가 추가·이름 변경·삭제)
  final List<String> tags;

  // 6. 미니게임 (v0.3)
  final bool miniGameEnabled;

  /// 사진으로 만든 픽셀 캐릭터 (ARGB, 정사각형 [characterSize]²). null 이면 기본 캐릭터.
  final List<int>? characterPixels;
  static const characterSize = 24;

  // 7. 화면 모드 · 미니게임 꾸미기 (v0.4)
  final AppearanceMode appearance;

  /// 사진 캐릭터는 [characterPixels] 가 있을 때만 쓸 수 있다.
  final CharacterStyle characterStyle;
  final PetKind pet;

  CharacterStyle get effectiveCharacterStyle =>
      characterStyle == CharacterStyle.photo && characterPixels == null ? CharacterStyle.boy : characterStyle;

  static const minRows = 1;
  static const maxRows = 4;
  static const minDelayDays = 1;
  static const maxDelayDays = 14;

  /// 행 수를 줄였을 때 '이번 주 행 순서'가 범위를 넘지 않게 맞춘다.
  int get effectiveWeekRow => currentWeekRow.clamp(1, calendarRows);

  AppSettings copyWith({
    String? userName,
    String? email,
    bool? notificationsEnabled,
    int? remindDaysBefore,
    int? remindMinutes,
    bool? eclassConnected,
    bool? everytimeConnected,
    int? calendarRows,
    int? currentWeekRow,
    CompletionStyle? completionStyle,
    int? delayDays,
    List<String>? tags,
    bool? miniGameEnabled,
    List<int>? characterPixels,
    bool clearCharacter = false,
    AppearanceMode? appearance,
    CharacterStyle? characterStyle,
    PetKind? pet,
  }) {
    final rows = (calendarRows ?? this.calendarRows).clamp(minRows, maxRows);
    return AppSettings(
      userName: userName ?? this.userName,
      email: email ?? this.email,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      remindMinutes: remindMinutes ?? this.remindMinutes,
      eclassConnected: eclassConnected ?? this.eclassConnected,
      everytimeConnected: everytimeConnected ?? this.everytimeConnected,
      calendarRows: rows,
      currentWeekRow: (currentWeekRow ?? this.currentWeekRow).clamp(1, rows),
      completionStyle: completionStyle ?? this.completionStyle,
      delayDays: (delayDays ?? this.delayDays).clamp(minDelayDays, maxDelayDays),
      tags: tags ?? this.tags,
      miniGameEnabled: miniGameEnabled ?? this.miniGameEnabled,
      characterPixels: clearCharacter ? null : (characterPixels ?? this.characterPixels),
      appearance: appearance ?? this.appearance,
      characterStyle: characterStyle ?? this.characterStyle,
      pet: pet ?? this.pet,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'userName': userName,
        'email': email,
        'notificationsEnabled': notificationsEnabled,
        'remindDaysBefore': remindDaysBefore,
        'remindMinutes': remindMinutes,
        'eclassConnected': eclassConnected,
        'everytimeConnected': everytimeConnected,
        'calendarRows': calendarRows,
        'currentWeekRow': currentWeekRow,
        'completionStyle': completionStyle.name,
        'delayDays': delayDays,
        'tags': tags,
        'miniGameEnabled': miniGameEnabled,
        'characterPixels': characterPixels,
        'appearance': appearance.name,
        'characterStyle': characterStyle.name,
        'pet': pet.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const d = AppSettings();
    final styleName = json['completionStyle'];
    final style = CompletionStyle.values.firstWhere(
      (s) => s.name == styleName,
      orElse: () => d.completionStyle,
    );
    final rawTags = json['tags'];
    final rawPixels = json['characterPixels'];
    final pixels = rawPixels is List ? rawPixels.whereType<int>().toList() : null;
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return d.copyWith(
      userName: json['userName'] as String?,
      email: json['email'] as String?,
      notificationsEnabled: json['notificationsEnabled'] as bool?,
      remindDaysBefore: json['remindDaysBefore'] as int?,
      remindMinutes: json['remindMinutes'] as int?,
      eclassConnected: json['eclassConnected'] as bool?,
      everytimeConnected: json['everytimeConnected'] as bool?,
      calendarRows: json['calendarRows'] as int?,
      currentWeekRow: json['currentWeekRow'] as int?,
      completionStyle: style,
      delayDays: json['delayDays'] as int?,
      tags: rawTags is List ? rawTags.whereType<String>().toList() : null,
      miniGameEnabled: json['miniGameEnabled'] as bool?,
      characterPixels: pixels != null && pixels.length == characterSize * characterSize ? pixels : null,
      appearance: pick(AppearanceMode.values, json['appearance'], d.appearance),
      characterStyle: pick(CharacterStyle.values, json['characterStyle'], d.characterStyle),
      pet: pick(PetKind.values, json['pet'], d.pet),
    );
  }
}
