import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/data/sync_store.dart';
import 'package:keepy/data/task_store.dart';
import 'package:keepy/models/task.dart';
import 'package:keepy/state/app_state.dart';

/// 메모리 저장소 (shared_preferences 없이)
class _MemStore implements TaskStore {
  List<Map<String, Object?>> tasks = [];
  List<Map<String, Object?>> log = [];
  Map<String, Object?> settings = {};

  /// 항상 true → AppState가 샘플을 만들지 않고 이 저장소에서 읽는다
  @override
  bool get hasData => true;

  @override
  List<Map<String, Object?>> readTasks() => tasks;

  @override
  List<Map<String, Object?>> readLog() => log;

  @override
  Map<String, Object?> readSettings() => settings;

  @override
  Future<void> write({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    this.tasks = [
      for (final t in tasks) {...t},
    ];
    this.log = log;
    this.settings = settings;
  }
}

/// 서버 흉내 — Firestore 대신 메모리 맵
class _FakeBackend implements SyncBackend {
  final Map<String, Map<String, Object?>> server = {};
  final _remote = StreamController<List<Map<String, Object?>>>.broadcast();
  final _uids = StreamController<String?>.broadcast();
  String? _uid;
  int pushes = 0;

  void login(String uid) {
    _uid = uid;
    _uids.add(uid);
  }

  void logout() {
    _uid = null;
    _uids.add(null);
  }

  /// 다른 기기가 서버를 바꾼 상황
  void remoteEdit(Map<String, Object?> t) {
    server[t['id']! as String] = t;
    _remote.add(server.values.toList());
  }

  @override
  String? get uid => _uid;

  @override
  bool get canSync => _uid != null;

  @override
  Stream<String?> get uidChanges => _uids.stream;

  @override
  Future<void> push({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    pushes++;
    for (final t in tasks) {
      final id = t['id']! as String;
      final old = server[id];
      // 보안 규칙과 같은 LWW: 더 오래된 버전으로는 덮어쓰지 않음
      if (old == null ||
          !SyncStore.updatedAtOf(t).isBefore(SyncStore.updatedAtOf(old))) {
        server[id] = {...t};
      }
    }
  }

  @override
  Future<List<Map<String, Object?>>> pullTasks() async =>
      server.values.toList();

  @override
  Stream<List<Map<String, Object?>>> watchTasks() => _remote.stream;

  @override
  Future<void> dispose() async {
    await _remote.close();
    await _uids.close();
  }
}

Map<String, Object?> _json(
  String id,
  String title,
  DateTime at, {
  bool deleted = false,
}) => Task(
  id: id,
  title: title,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: at,
  deleted: deleted,
).toJson();

List<String> _titles(Iterable<Task> list) => [for (final t in list) t.title];

void main() {
  group('삭제 = tombstone', () {
    test('remove 하면 보이는 목록에서 빠지지만 저장 데이터에는 deleted 로 남는다', () async {
      final store = _MemStore();
      final s = AppState(store: store);
      s.addAll(['하나', '둘']);
      final t = s.tasks.first;

      s.remove(t);
      await s.flush();

      expect(_titles(s.tasks), ['둘']);
      final saved = store.tasks.firstWhere((j) => j['id'] == t.id);
      expect(saved['deleted'], isTrue);
      s.dispose();
    });

    test('clearDone 되돌리기는 그사이 새로 추가한 할 일을 지우지 않는다', () {
      final s = AppState(seed: false);
      final a = s.add('완료할 것');
      s.setDone(a, true);

      final snapshot = s.clearDone();
      s.add('새 할 일'); // 지운 직후 추가
      s.restoreAll(snapshot);

      expect(_titles(s.tasks), containsAll(['완료할 것', '새 할 일']));
      s.dispose();
    });
  });

  group('applyRemote — 항목별 LWW', () {
    test('처음 보는 항목은 추가, 더 최신이면 교체, 더 오래됐으면 무시', () {
      final s = AppState(seed: false);
      final mine = s.add('내 것');

      s.applyRemote([
        _json('remote-1', '다른 기기에서 추가', DateTime(2030)),
        _json(mine.id, '옛날 버전', DateTime(2000)),
      ]);
      expect(_titles(s.tasks), containsAll(['다른 기기에서 추가', '내 것']));

      s.applyRemote([_json(mine.id, '다른 기기에서 고침', DateTime(2099))]);
      expect(mine.title, '다른 기기에서 고침', reason: '같은 객체의 필드를 바꾼다');
      s.dispose();
    });

    test('다른 기기에서 지운 항목은 이 기기에서도 사라진다', () {
      final s = AppState(seed: false);
      final t = s.add('지울 것');
      s.applyRemote([_json(t.id, '지울 것', DateTime(2099), deleted: true)]);
      expect(s.tasks, isEmpty);
      s.dispose();
    });
  });

  group('SyncStore + 가짜 서버', () {
    test('게스트로 쓴 할 일이 로그인하면 서버로 올라간다', () async {
      final backend = _FakeBackend();
      final sync = SyncStore(local: _MemStore(), backend: backend);
      final s = AppState(store: sync);
      sync.onRemoteTasks = s.applyRemote;
      sync.start();

      s.add('오프라인에서 쓴 것');
      await s.flush();
      expect(backend.server, isEmpty, reason: '로그인 전에는 안 올림');
      expect(sync.pending, isNotEmpty);

      backend.login('user-a');
      await pumpEventQueue();

      expect(
        backend.server.values.map((j) => j['title']),
        contains('오프라인에서 쓴 것'),
      );
      expect(sync.pending, isEmpty);
      await sync.dispose();
      s.dispose();
    });

    test('로그인 직후 병합: 서버의 최신 값이 이 기기의 옛 값을 이긴다 (덮어쓰지 않음)', () async {
      final backend = _FakeBackend()
        ..server['x'] = _json('x', '서버 최신', DateTime(2030));
      final local = _MemStore()
        ..tasks = [_json('x', '이 기기 옛것', DateTime(2001))];
      final sync = SyncStore(local: local, backend: backend);
      final s = AppState(store: sync);
      sync.onRemoteTasks = s.applyRemote;
      sync.start();

      backend.login('user-a');
      await pumpEventQueue();

      expect(backend.server['x']!['title'], '서버 최신');
      expect(_titles(s.tasks), ['서버 최신']);
      await sync.dispose();
      s.dispose();
    });

    test('다른 기기의 변경이 실시간으로 화면에 반영된다', () async {
      final backend = _FakeBackend();
      final sync = SyncStore(local: _MemStore(), backend: backend);
      final s = AppState(store: sync);
      sync.onRemoteTasks = s.applyRemote;
      sync.start();
      backend.login('user-a');
      await pumpEventQueue();

      backend.remoteEdit(_json('b-1', '기기 B에서 추가', DateTime(2030)));
      await pumpEventQueue();

      expect(_titles(s.tasks), contains('기기 B에서 추가'));
      await sync.dispose();
      s.dispose();
    });
  });

  test('mergeTasks — 대기 중인 내 변경은 서버 값보다 우선', () {
    final merged = SyncStore.mergeTasks(
      local: [_json('a', '내 수정', DateTime(2001))],
      remote: [_json('a', '서버', DateTime(2030))],
      pending: {'a'},
    );
    expect(merged.single['title'], '내 수정');
  });

  test('OCR 일괄 추가도 100자로 자른다', () {
    final s = AppState(seed: false);
    s.addAll(['가' * 150]);
    expect(s.tasks.single.title.length, AppState.maxTitle);
    s.dispose();
  });
}
