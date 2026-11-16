/// 실행할 때 넣어 주는 설정 값 (MP3, NFR-06 · CST-04: 설정 키 하드코딩 금지).
///
/// 값은 코드에 적지 않고 `app/.env` 파일(커밋 안 함)에 적은 뒤, 실행 명령에 붙여 넣는다.
///
/// ```
/// flutter run -d chrome --dart-define-from-file=.env
/// ```
///
/// 값이 없으면 동기화가 꺼진 채로(이 기기에만 저장) 그대로 실행된다.
class KeepyEnv {
  KeepyEnv._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// 예: https://abcdefgh.supabase.co (끝의 / 는 떼어 낸다)
  static String get supabaseUrl {
    var u = _url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Supabase 공개용 키 — 'Publishable key'(sb_publishable_…) 또는 예전 'anon public' 키.
  /// 행 단위 보안(RLS)으로 보호되는 공개용 키지만,
  /// 과제 규칙에 따라 코드에는 넣지 않는다.
  static String get supabaseAnonKey => _anonKey.trim();

  /// 두 값이 모두 있어야 서버 동기화를 켤 수 있다.
  static bool get syncConfigured =>
      supabaseUrl.startsWith('http') && supabaseAnonKey.isNotEmpty;
}
