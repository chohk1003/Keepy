import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync_backend.dart';

/// 할 일 하나의 동기화 기록.
///
/// - [updatedAt]: 이 기기에서(또는 서버에서 받아) 마지막으로 바뀐 시각(밀리초)
/// - [dirty]: 아직 서버에 못 올린 변경이 있음 → '오프라인 대기열'
/// - [deleted]: 지운 할 일 (삭제 표시). 다른 기기에서도 지워지도록 서버에 올린다.
/// - [json]: 마지막으로 맞춰 본 할 일 JSON (무엇이 바뀌었는지 비교용)
class LedgerEntry {
  const LedgerEntry({
    required this.updatedAt,
    required this.dirty,
    required this.deleted,
    this.json,
  });

  final int updatedAt;
  final bool dirty;
  final bool deleted;
  final String? json;

  LedgerEntry clean() => LedgerEntry(updatedAt: updatedAt, dirty: false, deleted: deleted, json: json);

  Map<String, Object?> toJson() => <String, Object?>{'u': updatedAt, 'd': dirty, 'x': deleted, 'j': json};

  static LedgerEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final u = raw['u'];
    if (u is! num) return null;
    final j = raw['j'];
    return LedgerEntry(
      updatedAt: u.toInt(),
      dirty: raw['d'] == true,
      deleted: raw['x'] == true,
      json: j is String ? j : null,
    );
  }
}

/// 이 기기의 동기화 장부: 할 일별 기록 + 서버에서 어디까지 받았는지(커서).
class SyncLedger {
  SyncLedger({Map<String, LedgerEntry>? entries, this.cursor = 0, this.lastSyncedAt})
      : entries = entries ?? <String, LedgerEntry>{};

  final Map<String, LedgerEntry> entries;

  /// 서버 synced_at 기준 '여기까지 받았음' (밀리초).
  int cursor;

  /// 마지막으로 동기화를 끝낸 시각 (화면 표시용).
  DateTime? lastSyncedAt;

  /// 아직 서버에 못 올린 변경 수.
  int get pendingCount => entries.values.where((e) => e.dirty).length;

  void clear() {
    entries.clear();
    cursor = 0;
    lastSyncedAt = null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'v': 1,
        'cursor': cursor,
        'last': lastSyncedAt?.millisecondsSinceEpoch,
        'entries': <String, Object?>{for (final e in entries.entries) e.key: e.value.toJson()},
      };

  static SyncLedger fromJson(Object? raw) {
    if (raw is! Map) return SyncLedger();
    final map = <String, LedgerEntry>{};
    final rawEntries = raw['entries'];
    if (rawEntries is Map) {
      for (final e in rawEntries.entries) {
        final entry = LedgerEntry.fromJson(e.value);
        if (e.key is String && entry != null) map[e.key as String] = entry;
      }
    }
    final cursor = raw['cursor'];
    final last = raw['last'];
    return SyncLedger(
      entries: map,
      cursor: cursor is num ? cursor.toInt() : 0,
      lastSyncedAt: last is num ? DateTime.fromMillisecondsSinceEpoch(last.toInt()) : null,
    );
  }
}

/// 장부·로그인 정보 저장소 계약.
abstract class SyncStateRepository {
  Future<SyncLedger> loadLedger();
  Future<void> saveLedger(SyncLedger ledger);
  Future<SyncSession?> loadSession();
  Future<void> saveSession(SyncSession? session);
}

/// 기기 저장소(shared_preferences) 구현. 할 일 목록(keepy.tasks.v1)과는 다른 키를 쓴다.
class LocalSyncStateRepository implements SyncStateRepository {
  static const ledgerKey = 'keepy.sync.ledger.v1';
  static const sessionKey = 'keepy.sync.session.v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<SyncLedger> loadLedger() async {
    final raw = (await _prefs).getString(ledgerKey);
    if (raw == null) return SyncLedger();
    try {
      return SyncLedger.fromJson(jsonDecode(raw));
    } on FormatException {
      return SyncLedger();
    }
  }

  @override
  Future<void> saveLedger(SyncLedger ledger) async {
    await (await _prefs).setString(ledgerKey, jsonEncode(ledger.toJson()));
  }

  @override
  Future<SyncSession?> loadSession() async {
    final raw = (await _prefs).getString(sessionKey);
    if (raw == null) return null;
    try {
      return SyncSession.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveSession(SyncSession? session) async {
    final prefs = await _prefs;
    if (session == null) {
      await prefs.remove(sessionKey);
    } else {
      await prefs.setString(sessionKey, jsonEncode(session.toJson()));
    }
  }
}

/// 테스트용 메모리 저장소.
class InMemorySyncStateRepository implements SyncStateRepository {
  InMemorySyncStateRepository({SyncSession? session}) : _session = session;

  String _ledger = '';
  SyncSession? _session;

  @override
  Future<SyncLedger> loadLedger() async => _ledger.isEmpty ? SyncLedger() : SyncLedger.fromJson(jsonDecode(_ledger));

  @override
  Future<void> saveLedger(SyncLedger ledger) async => _ledger = jsonEncode(ledger.toJson());

  @override
  Future<SyncSession?> loadSession() async => _session;

  @override
  Future<void> saveSession(SyncSession? session) async => _session = session;
}
