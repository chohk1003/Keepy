/// 서버 동기화에 필요한 최소한의 계약 (MP3).
///
/// 실제 구현은 [SupabaseBackend](supabase_backend.dart) 하나이고,
/// 테스트에서는 메모리로 흉내 낸 가짜 서버를 끼워 두 기기 동기화를 검증한다.
library;

/// 로그인 상태 (기기 저장소에 보관 → 앱을 다시 켜도 로그인 유지).
class SyncSession {
  const SyncSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;

  /// 접근 토큰 만료 시각 (밀리초). 1분 전부터는 미리 새로 받는다.
  final int expiresAt;

  bool isExpiringAt(int nowMs) => nowMs > expiresAt - 60 * 1000;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'email': email,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt,
      };

  static SyncSession? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final userId = raw['userId'];
    final access = raw['accessToken'];
    final refresh = raw['refreshToken'];
    if (userId is! String || access is! String || refresh is! String) return null;
    final email = raw['email'];
    final expires = raw['expiresAt'];
    return SyncSession(
      userId: userId,
      email: email is String ? email : '',
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expires is num ? expires.toInt() : 0,
    );
  }
}

/// 서버의 할 일 한 줄 (keepy_tasks 테이블).
///
/// - [data]: 할 일 JSON (Task.toJson). 지운 할 일이면 null 일 수 있다.
/// - [updatedAt]: 기기에서 마지막으로 고친 시각(밀리초) — 충돌 시 큰 쪽이 이긴다.
/// - [syncedAt]: 서버가 받은 시각(밀리초) — '여기부터 새로 온 것' 을 고르는 기준.
class RemoteTask {
  const RemoteTask({
    required this.id,
    required this.data,
    required this.deleted,
    required this.updatedAt,
    this.syncedAt = 0,
  });

  final String id;
  final Map<String, dynamic>? data;
  final bool deleted;
  final int updatedAt;
  final int syncedAt;

  static RemoteTask? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final updated = raw['updated_at'];
    if (id is! String || updated is! num) return null;
    final data = raw['data'];
    final synced = raw['synced_at'];
    return RemoteTask(
      id: id,
      data: data is Map ? Map<String, dynamic>.from(data) : null,
      deleted: raw['deleted'] == true,
      updatedAt: updated.toInt(),
      syncedAt: synced is num ? synced.toInt() : 0,
    );
  }
}

/// 회원가입 결과: 바로 로그인되거나, 메일 확인을 기다리거나.
class SignUpResult {
  const SignUpResult.signedIn(SyncSession this.session) : needsEmailConfirm = false;
  const SignUpResult.confirmEmail()
      : session = null,
        needsEmailConfirm = true;

  final SyncSession? session;
  final bool needsEmailConfirm;
}

/// 네트워크에 닿지 못함 (비행기 모드, 와이파이 끊김, 시간 초과).
/// → 변경은 대기열에 남겨 두고 나중에 다시 보낸다.
class SyncOfflineException implements Exception {
  const SyncOfflineException([this.detail = '']);
  final String detail;
  @override
  String toString() => 'SyncOfflineException($detail)';
}

/// 로그인이 필요하거나 만료됨, 또는 아이디·비밀번호가 틀림.
class SyncAuthException implements Exception {
  const SyncAuthException(this.message);
  final String message;
  @override
  String toString() => 'SyncAuthException($message)';
}

/// 서버가 거절함 (테이블이 없음, 권한 설정 누락 등). [message] 는 사용자에게 보여 줄 문구.
class SyncServerException implements Exception {
  const SyncServerException(this.message, {this.status = 0});
  final String message;
  final int status;
  @override
  String toString() => 'SyncServerException($status, $message)';
}

abstract class SyncBackend {
  Future<SyncSession> signIn(String email, String password);
  Future<SignUpResult> signUp(String email, String password);
  Future<SyncSession> refresh(SyncSession session);

  /// [afterSyncedAt] 보다 늦게 서버에 들어온 줄을 [limit] 개까지 (synced_at 오름차순).
  Future<List<RemoteTask>> fetchChanges(SyncSession session, {required int afterSyncedAt, int limit = 500});

  /// 여러 줄을 한 번에 넣거나 고친다. 서버는 updated_at 이 더 오래된 쓰기를 무시한다(마지막 수정 우선).
  Future<void> upsert(SyncSession session, List<RemoteTask> rows);
}
