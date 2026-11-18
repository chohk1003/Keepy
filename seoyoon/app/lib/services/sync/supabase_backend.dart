import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_backend.dart';

/// Supabase 연동 (MP3) — 공식 SDK 대신 REST 를 직접 부른다.
///
/// - 인증: Supabase Auth (이메일 + 비밀번호) `/auth/v1/...`
/// - 데이터: PostgREST `/rest/v1/keepy_tasks` (행 단위 보안으로 내 줄만 보임)
///
/// SDK 를 쓰지 않은 이유: `http` 패키지 하나만 더하면 되고 안드로이드·iOS·웹 설정을
/// 따로 건드릴 필요가 없어, 기존 앱(1·2단계)과 충돌할 여지가 가장 적다.
/// 테이블·보안 규칙은 `app/supabase/schema.sql` 에 있다.
class SupabaseBackend implements SyncBackend {
  SupabaseBackend({
    required String url,
    required String anonKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  })  : _url = url,
        _anonKey = anonKey,
        _client = client ?? http.Client();

  static const table = 'keepy_tasks';

  final String _url;
  final String _anonKey;
  final http.Client _client;
  final Duration timeout;

  // ---------------------------------------------------------------- 인증

  @override
  Future<SyncSession> signIn(String email, String password) async {
    final res = await _send(
      'POST',
      '/auth/v1/token?grant_type=password',
      body: <String, Object?>{'email': email, 'password': password},
    );
    if (res.statusCode == 400 || res.statusCode == 401) {
      throw SyncAuthException(_authMessage(res));
    }
    _check(res);
    return _sessionFrom(res.body, fallbackEmail: email);
  }

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    final res = await _send(
      'POST',
      '/auth/v1/signup',
      body: <String, Object?>{'email': email, 'password': password},
    );
    if (res.statusCode >= 400 && res.statusCode < 500) {
      throw SyncAuthException(_authMessage(res));
    }
    _check(res);
    final json = _decode(res.body);
    // '메일 확인' 이 켜진 프로젝트는 토큰 없이 사용자 정보만 돌려준다.
    if (json is Map && json['access_token'] is String) {
      return SignUpResult.signedIn(_sessionFrom(res.body, fallbackEmail: email));
    }
    return const SignUpResult.confirmEmail();
  }

  @override
  Future<SyncSession> refresh(SyncSession session) async {
    final res = await _send(
      'POST',
      '/auth/v1/token?grant_type=refresh_token',
      body: <String, Object?>{'refresh_token': session.refreshToken},
    );
    if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
      throw const SyncAuthException('로그인이 만료됐어요. 다시 로그인해 주세요.');
    }
    _check(res);
    return _sessionFrom(res.body, fallbackEmail: session.email);
  }

  // ---------------------------------------------------------------- 데이터

  @override
  Future<List<RemoteTask>> fetchChanges(SyncSession session, {required int afterSyncedAt, int limit = 500}) async {
    final path = '/rest/v1/$table'
        '?select=id,data,deleted,updated_at,synced_at'
        '&synced_at=gt.$afterSyncedAt'
        '&order=synced_at.asc'
        '&limit=$limit';
    final res = await _send('GET', path, token: session.accessToken);
    _check(res);
    final json = _decode(res.body);
    if (json is! List) throw const SyncServerException('서버 응답 형식이 올바르지 않아요.');
    return json.map(RemoteTask.fromJson).whereType<RemoteTask>().toList();
  }

  @override
  Future<void> upsert(SyncSession session, List<RemoteTask> rows) async {
    if (rows.isEmpty) return;
    final body = <Map<String, Object?>>[
      for (final r in rows)
        <String, Object?>{
          'user_id': session.userId,
          'id': r.id,
          'data': r.data,
          'deleted': r.deleted,
          'updated_at': r.updatedAt,
        },
    ];
    final res = await _send(
      'POST',
      '/rest/v1/$table?on_conflict=user_id,id',
      token: session.accessToken,
      body: body,
      prefer: 'resolution=merge-duplicates,return=minimal',
    );
    _check(res);
  }

  // ---------------------------------------------------------------- 내부

  Future<http.Response> _send(
    String method,
    String path, {
    String? token,
    Object? body,
    String? prefer,
  }) async {
    // 프로젝트 키는 apikey 헤더에만 싣는다. 새 형식 키(sb_publishable_…)는 JWT 가 아니라서
    // Authorization 에 넣으면 'Invalid JWT' 로 거절된다. Authorization 에는 로그인한 사용자 토큰만.
    final headers = <String, String>{
      'apikey': _anonKey,
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (prefer != null) 'Prefer': prefer,
    };
    final uri = Uri.parse('$_url$path');
    try {
      final Future<http.Response> call = method == 'GET'
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: jsonEncode(body));
      return await call.timeout(timeout);
    } on TimeoutException {
      throw const SyncOfflineException('시간 초과');
    } on http.ClientException catch (e) {
      // 와이파이 끊김·비행기 모드·주소 못 찾음 (웹·모바일 공통으로 이 예외로 온다)
      throw SyncOfflineException(e.message);
    }
  }

  void _check(http.Response res) {
    final code = res.statusCode;
    if (code >= 200 && code < 300) return;
    if (code == 401) throw const SyncAuthException('로그인이 만료됐어요. 다시 로그인해 주세요.');
    final detail = _errorText(res.body);
    if (code == 404 || detail.contains('PGRST205') || detail.contains('does not exist')) {
      throw SyncServerException('서버에 keepy_tasks 테이블이 없어요. 실행 매뉴얼의 SQL 을 먼저 실행해 주세요.', status: code);
    }
    if (code == 403 || detail.contains('row-level security')) {
      throw SyncServerException('서버 권한 설정(RLS)을 확인해 주세요.', status: code);
    }
    if (code >= 500) {
      throw SyncServerException('서버가 잠시 응답하지 않아요. 잠시 후 다시 시도해요.', status: code);
    }
    throw SyncServerException(detail.isEmpty ? '서버 오류 ($code)' : detail, status: code);
  }

  SyncSession _sessionFrom(String body, {required String fallbackEmail}) {
    final json = _decode(body);
    if (json is! Map) throw const SyncServerException('로그인 응답 형식이 올바르지 않아요.');
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final user = json['user'];
    final userId = user is Map ? user['id'] : null;
    if (access is! String || refresh is! String || userId is! String) {
      throw const SyncServerException('로그인 응답에 토큰이 없어요.');
    }
    final email = user is Map && user['email'] is String ? user['email'] as String : fallbackEmail;
    final expiresIn = json['expires_in'];
    final seconds = expiresIn is num ? expiresIn.toInt() : 3600;
    return SyncSession(
      userId: userId,
      email: email,
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now().millisecondsSinceEpoch + seconds * 1000,
    );
  }

  static Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String _errorText(String body) {
    final json = _decode(body);
    if (json is Map) {
      for (final key in <String>['msg', 'message', 'error_description', 'error', 'hint']) {
        final v = json[key];
        if (v is String && v.isNotEmpty) {
          final code = json['code'];
          return code is String && code.isNotEmpty ? '$v ($code)' : v;
        }
      }
    }
    return body.length > 160 ? body.substring(0, 160) : body;
  }

  /// 로그인·가입 실패 문구를 한국어로.
  static String _authMessage(http.Response res) {
    final raw = _errorText(res.body).toLowerCase();
    if (raw.contains('invalid login') || raw.contains('invalid_credentials') || raw.contains('invalid_grant')) {
      return '이메일 또는 비밀번호가 맞지 않아요.';
    }
    if (raw.contains('not confirmed')) return '메일함에서 가입 확인 링크를 먼저 눌러 주세요.';
    if (raw.contains('already registered') || raw.contains('already been registered') || raw.contains('user_already_exists')) {
      return '이미 가입된 이메일이에요. 로그인해 주세요.';
    }
    if (raw.contains('password') && (raw.contains('at least') || raw.contains('weak'))) {
      return '비밀번호는 6자 이상으로 정해 주세요.';
    }
    if (raw.contains('email') && raw.contains('invalid')) return '이메일 형식을 확인해 주세요.';
    if (raw.contains('rate limit') || raw.contains('too many')) return '잠시 후 다시 시도해 주세요. (요청이 너무 많아요)';
    if (raw.contains('signup') && raw.contains('disabled')) return '이 프로젝트는 회원가입이 꺼져 있어요.';
    return '로그인하지 못했어요. (${res.statusCode})';
  }
}
