// 동기화 계층 (MP3, FR-11·FR-12) — 인터페이스와 no-op 구현까지만.
// Firestore 구현체는 계정 승인 후 2라운드에서 붙인다.
// 이 파일은 Firebase 패키지에 의존하지 않는다.
//
// 설계는 docs/firebase.md 의 "로컬 우선 + 대기 큐 + LWW 병합"을 따른다.
//
//   AppState → SyncStore ─┬─ TaskStore(LocalStore) : 먼저 쓰고, 읽기는 전부 여기서
//                         ├─ 대기 큐               : 아직 못 올린 변경의 id
//                         └─ SyncBackend           : 온라인일 때만 push/pull

import 'task_store.dart';

/// 원격 저장소(Firestore) 추상화. 2라운드에서 `FirestoreBackend`가 구현한다.
abstract class SyncBackend {
  /// 로그인 사용자. null이면 게스트 → 동기화하지 않는다.
  String? get uid;

  /// 지금 올릴 수 있는 상태인지 (로그인 + 네트워크)
  bool get canSync;

  /// 변경분 올리기. 실패하면 예외를 던진다 ([SyncStore]가 큐에 남긴다).
  Future<void> push({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  });

  /// 서버의 태스크 전체 읽기 (복귀 후 병합용)
  Future<List<Map<String, Object?>>> pullTasks();

  /// 실시간 수신 — `snapshots()` 구독을 감싼다.
  Stream<List<Map<String, Object?>>> watchTasks();

  Future<void> dispose();
}

/// 아무것도 하지 않는 백엔드. Firebase를 붙이기 전의 기본값이라
/// `SyncStore`를 끼워도 지금과 동작이 같다.
class NoopSyncBackend implements SyncBackend {
  const NoopSyncBackend();

  @override
  String? get uid => null;

  @override
  bool get canSync => false;

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
/// 원격 전송은 뒤에서 처리한다 → 오프라인에서도 화면이 느려지지 않는다.
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

  /// 서버에서 병합된 태스크 목록이 왔을 때 불린다.
  /// 2라운드에서 `AppState`의 다시 읽기 + `notifyListeners()`에 연결한다.
  final void Function(List<Map<String, Object?>> merged)? onRemoteTasks;

  /// 아직 못 올린 태스크 id. 서버 값이 이걸 덮어쓰지 못하게 막는다
  /// (docs/firebase.md 충돌 해결 흐름도의 "대기 큐에 있나?").
  final Set<String> _pending = {};

  Set<String> get pending => Set.unmodifiable(_pending);

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
    for (final t in tasks) {
      final id = t['id'];
      if (id is String) _pending.add(id);
    }
    await _flushPending(tasks: tasks, log: log, settings: settings);
  }

  /// 대기 큐 비우기. 실패하면 큐를 그대로 두고 조용히 넘어간다
  /// → 네트워크가 돌아올 때 [resync]에서 다시 시도 (FR-12).
  Future<void> _flushPending({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    if (!backend.canSync || _pending.isEmpty) return;
    try {
      await backend.push(tasks: tasks, log: log, settings: settings);
      _pending.clear();
    } catch (_) {
      // 전송 실패 — 큐에 남겨 둔다
    }
  }

  /// 네트워크 복귀 처리 (NFR-04): 큐를 올리고 서버를 다시 읽어 병합한다.
  Future<void> resync() async {
    if (!backend.canSync) return;
    await _flushPending(
      tasks: readTasks(),
      log: readLog(),
      settings: readSettings(),
    );
    final remote = await backend.pullTasks();
    final merged = mergeTasks(
      local: readTasks(),
      remote: remote,
      pending: _pending,
    );
    await local.write(
      tasks: merged,
      log: readLog(),
      settings: readSettings(),
    );
    onRemoteTasks?.call(merged);
  }

  Future<void> dispose() => backend.dispose();

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
      if (mine == null || _updatedAt(r).isAfter(_updatedAt(mine))) {
        out[id] = r;
      }
    }
    return out.values.toList();
  }

  /// `updatedAt` → 없거나 깨졌으면 `createdAt`, 그것도 없으면 아주 과거.
  /// (구버전 문서가 섞여 들어와도 비교가 가능해야 한다)
  static DateTime _updatedAt(Map<String, Object?> t) {
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
