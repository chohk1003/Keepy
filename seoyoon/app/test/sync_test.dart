import 'package:flutter_test/flutter_test.dart';
import 'package:keepy/data/repositories.dart';
import 'package:keepy/services/sync/sync_backend.dart';
import 'package:keepy/services/sync/sync_ledger.dart';
import 'package:keepy/state/sync_controller.dart';
import 'package:keepy/state/task_store.dart';

/// 메모리로 흉내 낸 Supabase (MP3 동기화 검증용).
///
/// 실제 서버(app/supabase/schema.sql)와 같은 규칙:
/// - 사용자별로 줄이 나뉜다 (RLS)
/// - updated_at 이 더 오래된 쓰기는 무시한다 (마지막 수정 우선 트리거)
/// - 받은 순서대로 synced_at 을 매긴다
class FakeServer implements SyncBackend {
  final Map<String, Map<String, RemoteTask>> rows = <String, Map<String, RemoteTask>>{};
  final Map<String, String> users = <String, String>{};
  bool offline = false;
  int upsertCalls = 0;
  int _serverClock = 1000;

  List<RemoteTask> rowsOf(String email) => rows['u-$email']?.values.toList() ?? <RemoteTask>[];

  void _net() {
    if (offline) throw const SyncOfflineException('테스트: 오프라인');
  }

  SyncSession _session(String email) => SyncSession(
        userId: 'u-$email',
        email: email,
        accessToken: 'access-$email',
        refreshToken: 'refresh-$email',
        expiresAt: DateTime(2100).millisecondsSinceEpoch,
      );

  @override
  Future<SyncSession> signIn(String email, String password) async {
    _net();
    if (users[email] != password) throw const SyncAuthException('이메일 또는 비밀번호가 맞지 않아요.');
    return _session(email);
  }

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    _net();
    if (users.containsKey(email)) throw const SyncAuthException('이미 가입된 이메일이에요. 로그인해 주세요.');
    users[email] = password;
    return SignUpResult.signedIn(_session(email));
  }

  @override
  Future<SyncSession> refresh(SyncSession session) async {
    _net();
    return session;
  }

  @override
  Future<List<RemoteTask>> fetchChanges(SyncSession session, {required int afterSyncedAt, int limit = 500}) async {
    _net();
    final list = (rows[session.userId]?.values ?? const <RemoteTask>[])
        .where((r) => r.syncedAt > afterSyncedAt)
        .toList()
      ..sort((a, b) => a.syncedAt.compareTo(b.syncedAt));
    return list.take(limit).toList();
  }

  @override
  Future<void> upsert(SyncSession session, List<RemoteTask> list) async {
    _net();
    upsertCalls++;
    final mine = rows.putIfAbsent(session.userId, () => <String, RemoteTask>{});
    for (final r in list) {
      final old = mine[r.id];
      if (old != null && r.updatedAt < old.updatedAt) continue; // 더 오래된 쓰기 무시
      mine[r.id] = RemoteTask(
        id: r.id,
        data: r.data,
        deleted: r.deleted,
        updatedAt: r.updatedAt,
        syncedAt: ++_serverClock,
      );
    }
  }
}

/// 테스트용 '기기' 하나: 할 일 저장소 + 동기화.
class Device {
  Device._(this.store, this.sync, this.state);

  final TaskStore store;
  final SyncController sync;
  final InMemorySyncStateRepository state;

  static Future<Device> create(FakeServer server, DateTime Function() clock, {InMemorySyncStateRepository? state, TaskStore? store}) async {
    final tasks = store ?? TaskStore(repository: InMemoryTaskRepository(), clock: clock);
    if (store == null) await tasks.load();
    final repo = state ?? InMemorySyncStateRepository();
    final sync = SyncController(tasks: tasks, backend: server, repository: repo, clock: clock, autoSync: false);
    await sync.init();
    return Device._(tasks, sync, repo);
  }

  List<String> get titles => store.tasks.map((t) => t.title).toList()..sort();
}

void main() {
  late FakeServer server;
  late DateTime now;
  DateTime clock() => now;
  void tick([int seconds = 5]) => now = now.add(Duration(seconds: seconds));

  setUp(() {
    server = FakeServer();
    now = DateTime(2026, 11, 16, 9);
  });

  Future<(Device, Device)> twoDevices() async {
    final a = await Device.create(server, clock);
    final b = await Device.create(server, clock);
    final up = await a.sync.signUp('team@keepy.app', 'secret12');
    expect(up.signedIn, isTrue);
    final login = await b.sync.signIn('team@keepy.app', 'secret12');
    expect(login.signedIn, isTrue);
    await a.sync.syncNow();
    await b.sync.syncNow();
    return (a, b);
  }

  test('기기 A 에서 추가한 할 일이 기기 B 에서 새로고침(동기화) 후 보인다 (통과 기준 1)', () async {
    final (a, b) = await twoDevices();
    a.store.add('자료구조 과제 제출');
    tick();
    await a.sync.syncNow();
    expect(a.sync.pendingCount, 0);
    expect(server.rowsOf('team@keepy.app'), hasLength(1));

    expect(b.titles, isEmpty);
    await b.sync.syncNow();
    expect(b.titles, <String>['자료구조 과제 제출']);
    expect(b.sync.phase, SyncPhase.idle);
  });

  test('오프라인에서 쓴 할 일은 대기열에 남았다가 온라인 복귀 후 서버에 반영된다 (통과 기준 2)', () async {
    final (a, b) = await twoDevices();
    server.offline = true;
    a.store.add('오프라인에서 쓴 할 일');
    tick();
    await a.sync.syncNow();
    expect(a.sync.phase, SyncPhase.offline);
    expect(a.sync.pendingCount, 1);
    expect(server.rowsOf('team@keepy.app'), isEmpty);

    server.offline = false;
    tick();
    await a.sync.syncNow();
    expect(a.sync.phase, SyncPhase.idle);
    expect(a.sync.pendingCount, 0);
    expect(server.rowsOf('team@keepy.app').single.data?['title'], '오프라인에서 쓴 할 일');

    await b.sync.syncNow();
    expect(b.titles, <String>['오프라인에서 쓴 할 일']);
  });

  test('앱을 껐다 켜도 못 올린 변경(대기열)이 남아 있다', () async {
    final a = await Device.create(server, clock);
    await a.sync.signUp('me@keepy.app', 'secret12');
    await a.sync.syncNow();
    server.offline = true;
    a.store.add('지하철에서 쓴 할 일');
    await a.sync.syncNow();
    await a.sync.flush();
    expect(a.sync.pendingCount, 1);

    // 같은 기기 저장소로 앱을 다시 켠 상황
    a.sync.dispose();
    final again = await Device.create(server, clock, state: a.state, store: a.store);
    expect(again.sync.isSignedIn, isTrue);
    expect(again.sync.pendingCount, 1);

    server.offline = false;
    await again.sync.syncNow();
    expect(again.sync.pendingCount, 0);
    expect(server.rowsOf('me@keepy.app'), hasLength(1));
  });

  test('수정·완료·삭제도 다른 기기에 전해진다', () async {
    final (a, b) = await twoDevices();
    final task = a.store.add('팀 회의 준비')!;
    tick();
    await a.sync.syncNow();
    await b.sync.syncNow();

    a.store.toggle(task.id);
    tick();
    await a.sync.syncNow();
    await b.sync.syncNow();
    expect(b.store.byId(task.id)?.done, isTrue);

    a.store.remove(task.id);
    tick();
    await a.sync.syncNow();
    expect(server.rowsOf('team@keepy.app').single.deleted, isTrue);
    await b.sync.syncNow();
    expect(b.titles, isEmpty);
    expect(b.sync.pendingCount, 0);
  });

  test('충돌: 두 기기에서 같은 할 일을 고치면 나중에 고친 쪽이 남는다 (LWW)', () async {
    final (a, b) = await twoDevices();
    final task = a.store.add('발표 자료')!;
    tick();
    await a.sync.syncNow();
    await b.sync.syncNow();

    // 둘 다 오프라인 상태에서 각자 고침: A 가 먼저, B 가 나중에
    a.store.update(task.id, title: '발표 자료 (A안)');
    tick();
    b.store.update(task.id, title: '발표 자료 (B안)');
    tick();

    // 먼저 고친 A 가 나중에 올려도, 나중에 고친 B 가 이긴다
    await b.sync.syncNow();
    await a.sync.syncNow();
    await b.sync.syncNow();
    expect(a.store.byId(task.id)?.title, '발표 자료 (B안)');
    expect(b.store.byId(task.id)?.title, '발표 자료 (B안)');
    expect(server.rowsOf('team@keepy.app').single.data?['title'], '발표 자료 (B안)');
  });

  test('충돌: 지운 뒤 다른 기기에서 더 나중에 고치면 되살아난다', () async {
    final (a, b) = await twoDevices();
    final task = a.store.add('운동 가기')!;
    tick();
    await a.sync.syncNow();
    await b.sync.syncNow();

    a.store.remove(task.id);
    tick();
    b.store.update(task.id, title: '운동 가기 (저녁)');
    tick();
    await a.sync.syncNow();
    await b.sync.syncNow();
    await a.sync.syncNow();
    expect(a.titles, <String>['운동 가기 (저녁)']);
    expect(b.titles, <String>['운동 가기 (저녁)']);
  });

  test('서버에서 받은 변경은 다시 올리지 않는다 (불필요한 왕복 없음)', () async {
    final (a, b) = await twoDevices();
    a.store.add('한 번만 올라가야 함');
    tick();
    await a.sync.syncNow();
    final calls = server.upsertCalls;
    await b.sync.syncNow();
    await b.sync.syncNow();
    expect(server.upsertCalls, calls);
    expect(b.sync.pendingCount, 0);
  });

  test('로그인하면 이 기기에 있던 할 일도 계정에 합쳐진다', () async {
    final a = await Device.create(server, clock);
    await a.sync.signUp('me@keepy.app', 'secret12');
    a.store.add('A 의 할 일');
    tick();
    await a.sync.syncNow();

    final b = await Device.create(server, clock);
    b.store.add('B 에서 로그인 전에 쓴 할 일');
    tick();
    final login = await b.sync.signIn('me@keepy.app', 'secret12');
    expect(login.signedIn, isTrue);
    await b.sync.syncNow();
    await a.sync.syncNow();
    expect(a.titles, <String>['A 의 할 일', 'B 에서 로그인 전에 쓴 할 일']);
    expect(b.titles, <String>['A 의 할 일', 'B 에서 로그인 전에 쓴 할 일']);
  });

  test('비밀번호가 틀리면 로그인되지 않고 안내 문구를 준다', () async {
    final a = await Device.create(server, clock);
    await a.sync.signUp('me@keepy.app', 'secret12');
    await a.sync.signOut();
    final b = await Device.create(server, clock);
    final r = await b.sync.signIn('me@keepy.app', 'wrong-pw');
    expect(r.signedIn, isFalse);
    expect(r.error, isTrue);
    expect(r.message, contains('비밀번호'));
    expect(b.sync.isSignedIn, isFalse);
  });

  test('로그아웃해도 이 기기의 할 일은 남는다', () async {
    final (a, _) = await twoDevices();
    a.store.add('남아 있어야 할 일');
    tick();
    await a.sync.syncNow();
    await a.sync.signOut();
    expect(a.sync.isSignedIn, isFalse);
    expect(a.sync.phase, SyncPhase.signedOut);
    expect(a.titles, <String>['남아 있어야 할 일']);
  });

  test('설정(.env)이 없으면 동기화가 꺼진 채로 아무것도 하지 않는다', () async {
    final sync = SyncController.disabled();
    expect(sync.phase, SyncPhase.notConfigured);
    expect(sync.isConfigured, isFalse);
    await sync.init();
    await sync.syncNow();
    final r = await sync.signIn('a@b.c', '123456');
    expect(r.signedIn, isFalse);
    sync.dispose();
  });
}
