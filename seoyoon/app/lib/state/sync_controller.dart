import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../services/sync/sync_backend.dart';
import '../services/sync/sync_ledger.dart';
import 'task_store.dart';

/// 동기화 상태 (화면 표시용).
enum SyncPhase {
  /// .env 설정이 없어 서버 동기화를 쓸 수 없음 → 이 기기에만 저장 (1·2단계와 같음)
  notConfigured,

  /// 설정은 있지만 로그인 전
  signedOut,

  /// 로그인됨, 쉬는 중 (다 맞춰짐 또는 곧 올릴 변경 있음)
  idle,

  /// 서버와 주고받는 중
  syncing,

  /// 네트워크에 닿지 못함 → 변경은 대기열에 남김, 연결되면 자동으로 다시 시도
  offline,

  /// 서버가 거절함 (테이블 없음·권한 등) → 문구로 안내, 주기적으로 다시 시도
  error,
}

/// 로그인·가입 결과.
typedef SyncAuthOutcome = ({bool signedIn, String? message, bool error});

/// 서버 동기화 담당 (MP3).
///
/// ## 흐름
/// 1. **변경 감지** — TaskStore 가 바뀔 때마다 할 일별 JSON 을 장부와 비교해
///    새로 생기거나 바뀐 할 일, 사라진(지운) 할 일을 '올릴 변경(dirty)' 으로 표시한다.
///    장부는 기기에 저장되므로 앱을 꺼도 대기열이 남는다 (오프라인 작성 대비).
/// 2. **당겨오기(pull)** — 서버에서 마지막으로 받은 뒤 새로 들어온 줄만 받아 반영한다.
/// 3. **올리기(push)** — 대기열을 한 번에 올리고, 성공한 것만 대기열에서 뺀다.
///    네트워크 오류면 그대로 남겨 두었다가 [retryInterval] 마다 다시 시도한다.
///
/// ## 충돌 처리 (README '동기화 충돌 처리 방침')
/// - 할 일 단위 **마지막 수정 우선(LWW)**: updated_at(밀리초)이 큰 쪽이 이긴다.
///   서버 트리거도 더 오래된 쓰기를 무시하므로 순서가 엇갈려도 결과가 같다.
/// - **삭제는 삭제 표시(tombstone)** 로 올린다 → 다른 기기에서도 지워지고,
///   삭제보다 나중에 고친 쪽이 있으면 그쪽이 이긴다(되살아남).
/// - 로그인할 때 이 기기에 있던 할 일은 계정에 **합친다**. 이때 기준 시각은
///   할 일의 마지막 수정 시각이라, 오래된 기기가 최신 내용을 덮지 않는다.
class SyncController extends ChangeNotifier {
  SyncController({
    required TaskStore tasks,
    required SyncBackend backend,
    required SyncStateRepository repository,
    DateTime Function()? clock,
    this.autoSync = true,
    this.debounce = const Duration(milliseconds: 1200),
    this.pollInterval = const Duration(seconds: 20),
    this.retryInterval = const Duration(seconds: 10),
    this.pageSize = 500,
  })  : _tasks = tasks,
        _backend = backend,
        _repo = repository,
        _clock = clock ?? DateTime.now,
        _phase = SyncPhase.signedOut;

  /// 서버 설정이 없을 때 (키 없이 실행·위젯 테스트): 아무 일도 하지 않는다.
  SyncController.disabled()
      : _tasks = null,
        _backend = null,
        _repo = null,
        _clock = DateTime.now,
        autoSync = false,
        debounce = Duration.zero,
        pollInterval = Duration.zero,
        retryInterval = Duration.zero,
        pageSize = 500,
        _phase = SyncPhase.notConfigured;

  final TaskStore? _tasks;
  final SyncBackend? _backend;
  final SyncStateRepository? _repo;
  final DateTime Function() _clock;

  /// false 면 타이머를 쓰지 않는다 (테스트에서 [syncNow] 를 직접 부를 때).
  final bool autoSync;
  final Duration debounce;
  final Duration pollInterval;
  final Duration retryInterval;
  final int pageSize;

  /// 서버가 받은 순서와 커밋 순서가 살짝 어긋나도 놓치지 않게 겹쳐 받는 폭.
  static const overlapMs = 3000;

  SyncPhase _phase;
  String? _message;
  SyncSession? _session;
  SyncLedger _ledger = SyncLedger();
  bool _initialized = false;
  bool _busy = false;
  bool _applying = false;
  bool _disposed = false;
  bool _again = false;
  int _epoch = 0;
  Future<void>? _inflight;
  Timer? _timer;
  Future<void> _saving = Future<void>.value();

  // ---------------------------------------------------------------- 읽기

  bool get isConfigured => _tasks != null && _backend != null && _repo != null;
  SyncPhase get phase => _phase;
  bool get isSignedIn => _session != null;
  String? get email => _session?.email;

  /// 사용자에게 보여 줄 마지막 오류·안내 문구.
  String? get message => _message;

  /// 로그인·가입 요청 중.
  bool get isBusy => _busy;

  /// 아직 서버에 못 올린 변경 수 (오프라인 대기열).
  int get pendingCount => _ledger.pendingCount;
  DateTime? get lastSyncedAt => _ledger.lastSyncedAt;

  /// 설정·계정 화면 한 줄 요약.
  String get statusText {
    switch (_phase) {
      case SyncPhase.notConfigured:
        return '이 기기에만 저장 중';
      case SyncPhase.signedOut:
        return '로그인하면 여러 기기에서 같은 목록을 봐요';
      case SyncPhase.syncing:
        return '동기화 중…';
      case SyncPhase.offline:
        return pendingCount > 0 ? '오프라인 · 올릴 변경 $pendingCount개' : '오프라인';
      case SyncPhase.error:
        return _message ?? '동기화 오류';
      case SyncPhase.idle:
        if (pendingCount > 0) return '올릴 변경 $pendingCount개';
        final last = lastSyncedAt;
        return last == null ? '동기화 준비됨' : '동기화됨 · ${_relative(last)}';
    }
  }

  // ---------------------------------------------------------------- 시작·종료

  /// 저장해 둔 로그인·장부를 불러오고, 로그인 상태면 바로 한 번 동기화한다.
  Future<void> init() async {
    if (!isConfigured || _initialized) return;
    _initialized = true;
    _ledger = await _repo!.loadLedger();
    _session = await _repo!.loadSession();
    _tasks!.addListener(_onTasksChanged);
    if (_session == null) {
      _ledger.clear();
      _setPhase(SyncPhase.signedOut);
      return;
    }
    // 앱이 꺼지기 직전에 바뀌었지만 장부에 못 적은 변경도 여기서 잡는다.
    if (_markLocalChanges()) _saveLedger();
    _setPhase(SyncPhase.idle);
    if (autoSync) unawaited(syncNow());
  }

  /// 앱이 다시 앞으로 왔을 때 (다른 기기에서 바뀐 것 받기).
  void onResumed() {
    if (isSignedIn && autoSync) unawaited(syncNow());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _tasks?.removeListener(_onTasksChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------- 로그인

  Future<SyncAuthOutcome> signIn(String email, String password) =>
      _auth(() async => _startSession(await _backend!.signIn(email.trim(), password)));

  Future<SyncAuthOutcome> signUp(String email, String password) => _auth(() async {
        final result = await _backend!.signUp(email.trim(), password);
        final session = result.session;
        if (session == null) {
          return (signedIn: false, message: '확인 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요.', error: false);
        }
        return _startSession(session);
      });

  /// 로그아웃: 이 기기의 할 일은 그대로 두고, 로그인 정보와 동기화 장부만 지운다.
  Future<void> signOut() async {
    if (!isConfigured) return;
    _epoch++;
    _timer?.cancel();
    _session = null;
    _ledger.clear();
    _message = null;
    _setPhase(SyncPhase.signedOut);
    await _repo!.saveSession(null);
    _saveLedger();
    await _saving;
  }

  // ---------------------------------------------------------------- 동기화

  /// 지금 동기화 (버튼·앱 복귀·주기 실행 공통). 이미 도는 중이면 끝난 뒤 한 번 더 돈다.
  Future<void> syncNow() {
    if (!isConfigured || _session == null || _disposed) return Future<void>.value();
    final running = _inflight;
    if (running != null) {
      _again = true;
      return running;
    }
    final future = _runLoop();
    _inflight = future;
    return future;
  }

  Future<void> _runLoop() async {
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again && _session != null && !_disposed);
    } finally {
      _inflight = null;
      if (!_disposed && _session != null) {
        _schedule(_phase == SyncPhase.idle ? pollInterval : retryInterval);
      }
    }
  }

  Future<void> _syncOnce() async {
    final epoch = _epoch;
    _message = null;
    _setPhase(SyncPhase.syncing);
    try {
      _markLocalChanges();
      await _pull(epoch);
      await _push(epoch);
      _ledger.lastSyncedAt = _clock();
      _phase = SyncPhase.idle;
    } on _Cancelled {
      return; // 도중에 로그아웃함
    } on SyncOfflineException {
      _phase = SyncPhase.offline;
      _message = '인터넷에 연결되면 자동으로 올려요.';
    } on SyncAuthException catch (e) {
      if (epoch == _epoch && _session != null) await _dropSession(e.message);
      return;
    } on SyncServerException catch (e) {
      _phase = SyncPhase.error;
      _message = e.message;
    } catch (e) {
      debugPrint('Keepy: 동기화 실패 ($e)');
      _phase = SyncPhase.error;
      _message = '동기화 중 문제가 생겼어요. 잠시 후 다시 시도해요.';
    }
    if (epoch != _epoch || _disposed) return;
    _saveLedger();
    notifyListeners();
  }

  /// 서버 → 기기. 새로 들어온 줄만 synced_at 순서로 받는다.
  Future<void> _pull(int epoch) async {
    while (true) {
      final from = math.max(0, _ledger.cursor - overlapMs);
      final rows = await _authed(epoch, (s) => _backend!.fetchChanges(s, afterSyncedAt: from, limit: pageSize));
      _ensure(epoch);
      _applyRemoteRows(rows);
      var newest = _ledger.cursor;
      for (final r in rows) {
        newest = math.max(newest, r.syncedAt);
      }
      final advanced = newest > _ledger.cursor;
      _ledger.cursor = newest;
      if (rows.length < pageSize || !advanced) break;
    }
  }

  /// 기기 → 서버. 대기열을 묶어서 올리고, 올리는 동안 또 바뀐 것은 대기열에 남긴다.
  Future<void> _push(int epoch) async {
    final dirty = _ledger.entries.entries.where((e) => e.value.dirty).toList();
    for (var i = 0; i < dirty.length; i += pageSize) {
      final chunk = dirty.sublist(i, math.min(i + pageSize, dirty.length));
      final rows = <RemoteTask>[
        for (final e in chunk)
          RemoteTask(
            id: e.key,
            data: _decodeTask(e.value.json),
            deleted: e.value.deleted,
            updatedAt: e.value.updatedAt,
          ),
      ];
      await _authed(epoch, (s) => _backend!.upsert(s, rows));
      _ensure(epoch);
      for (final e in chunk) {
        final current = _ledger.entries[e.key];
        if (current != null && current.dirty && current.updatedAt == e.value.updatedAt) {
          _ledger.entries[e.key] = current.clean();
        }
      }
      notifyListeners();
    }
  }

  /// 받은 줄을 기기에 반영 (마지막 수정 우선).
  void _applyRemoteRows(List<RemoteTask> rows) {
    final upserts = <String, Task>{};
    final deletes = <String>{};
    for (final r in rows) {
      final e = _ledger.entries[r.id];
      if (e != null) {
        // 이 기기의 변경이 더 최신 → 받지 않고 곧 올린다
        if (e.dirty && e.updatedAt > r.updatedAt) continue;
        // 이미 같은 버전 (내가 올린 것이 되돌아옴 등)
        if (!e.dirty && e.updatedAt == r.updatedAt && e.deleted == r.deleted) continue;
      }
      final data = r.data;
      if (r.deleted || data == null) {
        deletes.add(r.id);
        upserts.remove(r.id);
        _ledger.entries[r.id] = LedgerEntry(updatedAt: r.updatedAt, dirty: false, deleted: true, json: e?.json);
        continue;
      }
      Task? task;
      try {
        task = Task.fromJson(data);
      } catch (_) {
        task = null; // 형식이 깨진 줄은 건너뛴다
      }
      if (task == null || task.id != r.id) continue;
      upserts[r.id] = task;
      deletes.remove(r.id);
      _ledger.entries[r.id] = LedgerEntry(
        updatedAt: r.updatedAt,
        dirty: false,
        deleted: false,
        json: jsonEncode(task.toJson()),
      );
    }
    if (upserts.isEmpty && deletes.isEmpty) return;
    _applying = true;
    try {
      _tasks!.applyRemote(upserts: upserts.values.toList(), deletes: deletes);
    } finally {
      _applying = false;
    }
  }

  // ---------------------------------------------------------------- 변경 감지

  void _onTasksChanged() {
    if (_session == null || _applying || _disposed) return;
    if (!_markLocalChanges()) return;
    _saveLedger();
    notifyListeners();
    _schedule(debounce);
  }

  /// 할 일 목록과 장부를 비교해 바뀐 것을 '올릴 변경' 으로 표시. 바뀐 게 있으면 true.
  ///
  /// [useTaskTime]: 로그인 직후 합칠 때는 지금 시각 대신 할 일의 마지막 수정 시각을 쓴다.
  bool _markLocalChanges({bool useTaskTime = false}) {
    final tasks = _tasks;
    if (tasks == null) return false;
    final now = _clock().millisecondsSinceEpoch;
    var changed = false;
    final seen = <String>{};
    for (final t in tasks.tasks) {
      seen.add(t.id);
      final json = jsonEncode(t.toJson());
      final e = _ledger.entries[t.id];
      if (e != null && !e.deleted && e.json == json) continue;
      final at = useTaskTime ? (t.updatedAt ?? t.createdAt).millisecondsSinceEpoch : now;
      _ledger.entries[t.id] = LedgerEntry(updatedAt: _stamp(at, e), dirty: true, deleted: false, json: json);
      changed = true;
    }
    for (final id in _ledger.entries.keys.toList()) {
      final e = _ledger.entries[id]!;
      if (e.deleted || seen.contains(id)) continue;
      _ledger.entries[id] = LedgerEntry(updatedAt: _stamp(now, e), dirty: true, deleted: true, json: e.json);
      changed = true;
    }
    return changed;
  }

  /// 같은 할 일의 기록 시각은 항상 앞으로만 간다.
  static int _stamp(int at, LedgerEntry? previous) =>
      previous == null ? at : math.max(at, previous.updatedAt + 1);

  // ---------------------------------------------------------------- 내부

  Future<SyncAuthOutcome> _auth(Future<SyncAuthOutcome> Function() run) async {
    if (!isConfigured) {
      return (signedIn: false, message: '서버 설정(.env)이 없어 로그인할 수 없어요.', error: true);
    }
    _busy = true;
    notifyListeners();
    try {
      return await run();
    } on SyncAuthException catch (e) {
      return (signedIn: false, message: e.message, error: true);
    } on SyncOfflineException {
      return (signedIn: false, message: '인터넷에 연결되지 않았어요.', error: true);
    } on SyncServerException catch (e) {
      return (signedIn: false, message: e.message, error: true);
    } catch (e) {
      debugPrint('Keepy: 로그인 실패 ($e)');
      return (signedIn: false, message: '로그인하지 못했어요. 잠시 후 다시 시도해 주세요.', error: true);
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<SyncAuthOutcome> _startSession(SyncSession session) async {
    _epoch++;
    _session = session;
    await _repo!.saveSession(session);
    // 이 기기에 있던 할 일도 계정에 합친다 (할 일의 마지막 수정 시각 기준).
    _ledger.clear();
    _markLocalChanges(useTaskTime: true);
    _message = null;
    _setPhase(SyncPhase.idle);
    _saveLedger();
    unawaited(syncNow());
    return (signedIn: true, message: null, error: false);
  }

  Future<void> _dropSession(String message) async {
    await signOut();
    _message = message;
    notifyListeners();
  }

  /// 토큰이 곧 만료되면 미리, 서버가 401 을 주면 한 번 새로 받아 다시 시도한다.
  Future<T> _authed<T>(int epoch, Future<T> Function(SyncSession s) call) async {
    var s = _session;
    if (s == null) throw const _Cancelled();
    if (s.isExpiringAt(_clock().millisecondsSinceEpoch)) s = await _refresh(epoch, s);
    try {
      return await call(s);
    } on SyncAuthException {
      final fresh = await _refresh(epoch, s);
      return call(fresh);
    }
  }

  Future<SyncSession> _refresh(int epoch, SyncSession s) async {
    final next = await _backend!.refresh(s);
    _ensure(epoch);
    _session = next;
    await _repo!.saveSession(next);
    return next;
  }

  void _ensure(int epoch) {
    if (epoch != _epoch || _disposed || _session == null) throw const _Cancelled();
  }

  void _schedule(Duration delay) {
    if (!autoSync || _disposed || _session == null) return;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(syncNow()));
  }

  void _saveLedger() {
    final repo = _repo;
    if (repo == null) return;
    final ledger = _ledger;
    _saving = _saving.then((_) => repo.saveLedger(ledger)).catchError((Object e) {
      debugPrint('Keepy: 동기화 장부 저장 실패 ($e)');
    });
  }

  void _setPhase(SyncPhase phase) {
    _phase = phase;
    if (!_disposed) notifyListeners();
  }

  static Map<String, dynamic>? _decodeTask(String? json) {
    if (json == null) return null;
    final decoded = jsonDecode(json);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  String _relative(DateTime t) {
    final diff = _clock().difference(t);
    if (diff.inSeconds < 60) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// 테스트에서 장부 저장이 끝나길 기다릴 때.
  @visibleForTesting
  Future<void> flush() => _saving;
}

/// 동기화 도중 로그아웃 등으로 이번 회차를 그만둘 때 (사용자에게 보이지 않음).
class _Cancelled implements Exception {
  const _Cancelled();
}
