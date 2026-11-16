// 동기화 계층 (MP3, FR-11·FR-12)
// 이 파일은 Firebase 패키지에 의존하지 않는다 → Firebase 없이 단위 테스트 가능.
// 실제 Firestore 구현은 firestore_backend.dart.
//
// 설계는 docs/firebase.md 의 "로컬 우선 + LWW 병합"을 따른다.
//
//   AppState → SyncStore ─┬─ TaskStore(LocalStore) : 먼저 쓰고, 읽기는 전부 여기서
//                         ├─ 대기 큐               : 로그인 전(게스트)에 바뀐 id
//                         └─ SyncBackend           : 로그인했을 때만 push / 실시간 수신
//
// 오프라인 처리: 로그인 상태에서 오프라인이면 Firestore SDK가 쓰기를 기기 안에
// 쌓아 두었다가(앱을 껐다 켜도 유지) 온라인이 되면 자동으로 보낸다.
// 그래서 여기서는 따로 네트워크 상태를 감시하지 않는다.

import 'dart:async';

import 'task_store.dart';

/// 원격 저장소(Firestore) 추상화. 구현체: `FirestoreBackend`.
abstract class SyncBackend {
  /// 로그인 사용자. null이면 게스트 → 동기화하지 않는다.
  String? get uid;

  /// 지금 올릴 수 있는 상태인지 (= 로그인했는지)
  bool get canSync;

  /// 로그인/로그아웃·계정 전환 알림 (로그인하면 [SyncStore.resync]가 돈다)
  Stream<String?> get uidChanges;

  /// 변경분 올리기. 바뀐 태스크만 골라 보내는 건 구현체 책임.
  Future<void> push({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  });

  /// 서버의 태스크 전체 읽기 (로그인 직후 병합용)
  Future<List<Map<String, Object?>>> pullTasks();

  /// 실시간 수신 — 다른 기기에서 바뀌면 서버 목록 전체가 다시 들어온다.
  Stream<List<Map<String, Object?>>> watchTasks();

  Future<void> dispose();
}

/// 아무것도 하지 않는 백엔드. Firebase 설정이 없을 때(게스트 전용)의 기본값.
class NoopSyncBackend implements SyncBackend {
  const NoopSyncBackend();

  @override
  String? get uid => null;

  @override
  bool get canSync => false;

  @override
  Stream<String?> get uidChanges => const Stream<String?>.empty();

  @override
  Future<void> push({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {}

  @override
  Future<List<Map<String, Object?>>> pullTasks() async => const [];

  @override
  Stream<List<Map<String, Object?>>> watchTasks() =>
      const Stream<List<Map<String, Object?>>>.empty();

  @override
  Future<void> dispose() async {}
}

/// `LocalStore`와 같은 인터페이스([TaskStore])라서 `AppState`를 고치지 않고
/// 그 자리에 끼울 수 있다.
///
/// 읽기는 **전부 로컬**이다 (local-first). 쓰기도 로컬을 먼저 끝내고,
/// 원격 전송은 그다음이다 → 오프라인에서도 화면이 느려지지 않는다.
class SyncStore implements TaskStore {
  SyncStore({
    required this.local,
    this.backend = const NoopSyncBackend(),
    this.onRemoteTasks,
  });

  /// 로컬 저장소 — 항상 여기에 먼저 쓰고, 읽기는 전부 여기서 한다
  final TaskStore local;

  /// 원격 — 기본값은 아무것도 하지 않는 [NoopSyncBackend]
  final SyncBackend backend;

  /// 서버 쪽 태스크 목록이 왔을 때 불린다. `main.dart`에서
  /// `AppState.applyRemote`(항목별 LWW 병합 + 화면 갱신)를 연결한다.
  /// AppState가 SyncStore보다 늦게 만들어지므로 final이 아니다.
  void Function(List<Map<String, Object?>> remote)? onRemoteTasks;

  /// 로그인 전(게스트)에 바뀐 태스크 id. 로그인하면 [resync]가 올리고 비운다.
  final Set<String> _pending = {};

  Set<String> get pending => Set.unmodifiable(_pending);

  final List<StreamSubscription<Object?>> _subs = [];

  /// 실시간 수신·로그인 감시 시작. `onRemoteTasks`를 연결한 뒤 한 번 부른다.
  void start() {
    if (_subs.isNotEmpty) return;
    _subs.add(backend.watchTasks().listen(_onRemote));
    _subs.add(backend.uidChanges.listen((uid) {
      if (uid != null) unawaited(resync());
    }));
    if (backend.canSync) unawaited(resync());
  }

  // ------------------------------------------------------------------ 읽기
  @override
  bool get hasData => local.hasData;

  @override
  List<Map<String, Object?>> readTasks() => local.readTasks();

  @override
  List<Map<String, Object?>> readLog() => local.readLog();

  @override
  Map<String, Object?> readSettings() => local.readSettings();

  // ------------------------------------------------------------------ 쓰기
  @override
  Future<void> write({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    await local.write(tasks: tasks, log: log, settings: settings);
    if (!backend.canSync) {
      for (final t in tasks) {
        final id = t['id'];
        if (id is String) _pending.add(id);
      }
      return;
    }
    await _push(tasks: tasks, log: log, settings: settings);
  }

  Future<void> _push({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    try {
      await backend.push(tasks: tasks, log: log, settings: settings);
      _pending.clear();
    } catch (_) {
      // 전송 실패 — 대기 큐를 남겨 두고 다음 쓰기·로그인 때 다시 보낸다
    }
  }

  /// 로그인 직후 / 앱 시작 시: 서버를 읽어 병합한 뒤, 내 쪽이 더 최신인 것을 올린다.
  ///
  /// 순서가 중요하다. **먼저 올리면** 이 기기의 오래된 값이 다른 기기에서
  /// 고친 최신 값을 덮어쓸 수 있으므로, 받아서 병합 → 병합 결과를 올린다.
  Future<void> resync() async {
    if (!backend.canSync) return;
    List<Map<String, Object?>> remote;
    try {
      remote = await backend.pullTasks();
    } catch (_) {
      remote = const [];
    }
    final merged = mergeTasks(local: readTasks(), remote: remote);
    await local.write(tasks: merged, log: readLog(), settings: readSettings());
    onRemoteTasks?.call(merged);
    await _push(tasks: merged, log: readLog(), settings: readSettings());
  }

  void _onRemote(List<Map<String, Object?>> remote) {
    final apply = onRemoteTasks;
    if (apply != null) {
      apply(remote); // AppState가 항목별로 병합하고 저장까지 한다
      return;
    }
    // 연결된 화면 상태가 없으면 로컬 저장소에 직접 병합
    final merged =
        mergeTasks(local: readTasks(), remote: remote, pending: _pending);
    unawaited(
      local.write(tasks: merged, log: readLog(), settings: readSettings()),
    );
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await backend.dispose();
  }

  // ------------------------------------------------------------------ 병합
  /// Last-Write-Wins 병합 (docs/firebase.md 충돌 해결).
  ///
  /// - 로컬에 없는 서버 항목 → 추가
  /// - [pending]에 있는 id → 서버 값 무시 (아직 못 올린 내 변경이 우선)
  /// - 서버 `updatedAt`이 더 최신이면 → 서버 값으로 교체, 아니면 로컬 유지
  ///
  /// 순수 함수라 Firebase 없이도 단위 테스트할 수 있다.
  static List<Map<String, Object?>> mergeTasks({
    required List<Map<String, Object?>> local,
    required List<Map<String, Object?>> remote,
    Set<String> pending = const {},
  }) {
    final out = <String, Map<String, Object?>>{};
    for (final t in local) {
      final id = t['id'];
      if (id is String) out[id] = t;
    }
    for (final r in remote) {
      final id = r['id'];
      if (id is! String) continue;
      if (pending.contains(id)) continue;
      final mine = out[id];
      if (mine == null || updatedAtOf(r).isAfter(updatedAtOf(mine))) {
        out[id] = r;
      }
    }
    return out.values.toList();
  }

  /// `updatedAt` → 없거나 깨졌으면 `createdAt`, 그것도 없으면 아주 과거.
  /// (구버전 문서가 섞여 들어와도 비교가 가능해야 한다)
  static DateTime updatedAtOf(Map<String, Object?> t) {
    for (final key in const ['updatedAt', 'createdAt']) {
      final v = t[key];
      if (v is String) {
        final d = DateTime.tryParse(v);
        if (d != null) return d;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
