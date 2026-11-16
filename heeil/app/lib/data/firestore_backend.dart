import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'sync_store.dart';

/// Firestore 구현 (MP3)
///
/// 문서 구조: `users/{uid}/tasks/{taskId}`
/// - 필드는 `Task.toJson()` 그대로 + `updatedAtMs`(정수, 보안 규칙의 LWW 비교용)
///   + `serverUpdatedAt`(서버 시각, 콘솔에서 보기 좋으라고)
/// - 삭제는 문서를 지우지 않고 `deleted: true`(tombstone)로 남긴다.
///   그래야 오프라인 기기에도 "지워졌다"는 사실이 전해진다.
///
/// 오프라인: `set()`의 결과를 기다리지 않는다. 오프라인이면 Firestore SDK가
/// 기기 안에 쌓아 두었다가 온라인이 되면 보낸다.
class FirestoreBackend implements SyncBackend {
  FirestoreBackend({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen(_onUser);
  }

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _snapSub;

  final _remote = StreamController<List<Map<String, Object?>>>.broadcast();
  final _uidChanges = StreamController<String?>.broadcast();

  String? _uid;

  /// 서버에 이미 있는 버전 (id → updatedAt). 같은 버전은 다시 보내지 않는다.
  final Map<String, String> _known = {};

  @override
  String? get uid => _uid;

  @override
  bool get canSync => _uid != null;

  @override
  Stream<String?> get uidChanges => _uidChanges.stream;

  CollectionReference<Map<String, dynamic>> _tasksOf(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  void _onUser(User? user) {
    final next = user?.uid;
    if (next == _uid) return;
    _uid = next;
    _known.clear();
    _snapSub?.cancel();
    _snapSub = null;
    if (next != null) {
      _snapSub = _tasksOf(next).snapshots().listen(
        (snap) {
          final list = [for (final d in snap.docs) _fromDoc(d)];
          _remember(list);
          _remote.add(list);
        },
        onError: (Object e) => debugPrint('[sync] 실시간 수신 오류: $e'),
      );
    }
    _uidChanges.add(next);
  }

  void _remember(List<Map<String, Object?>> tasks) {
    for (final t in tasks) {
      final id = t['id'];
      final at = t['updatedAt'];
      if (id is String && at is String) _known[id] = at;
    }
  }

  @override
  Future<void> push({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final col = _tasksOf(uid);
    for (final t in tasks) {
      final id = t['id'];
      if (id is! String) continue;
      final at = t['updatedAt'];
      if (at is String && _known[id] == at) continue; // 이미 서버에 있는 버전
      if (at is String) _known[id] = at;
      // 결과를 기다리지 않는다 (오프라인이면 SDK가 쌓아 둠).
      // 보안 규칙이 "더 오래된 버전으로 덮어쓰기"를 거절하면 여기로 온다.
      unawaited(
        col.doc(id).set(_toDoc(t)).catchError((Object e) {
          if (_known[id] == at) _known.remove(id);
          debugPrint('[sync] 업로드 거절/실패 ($id): $e');
        }),
      );
    }
  }

  @override
  Future<List<Map<String, Object?>>> pullTasks() async {
    final uid = _uid;
    if (uid == null) return const [];
    final snap = await _tasksOf(uid).get();
    final list = [for (final d in snap.docs) _fromDoc(d)];
    _remember(list);
    return list;
  }

  @override
  Stream<List<Map<String, Object?>>> watchTasks() => _remote.stream;

  static Map<String, Object?> _toDoc(Map<String, Object?> t) {
    final at = SyncStore.updatedAtOf(t);
    return {
      ...t,
      'updatedAtMs': at.millisecondsSinceEpoch,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Firestore 전용 필드는 빼고 `Task.fromJson`이 읽는 모양으로 돌려준다.
  /// (`Timestamp`가 남아 있으면 로컬 JSON 저장에서 실패한다)
  static Map<String, Object?> _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = <String, Object?>{...d.data()};
    m.remove('serverUpdatedAt');
    m.remove('updatedAtMs');
    m['id'] = d.id;
    return m;
  }

  @override
  Future<void> dispose() async {
    await _authSub.cancel();
    await _snapSub?.cancel();
    await _remote.close();
    await _uidChanges.close();
  }
}
