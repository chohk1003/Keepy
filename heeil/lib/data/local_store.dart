import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'task_store.dart';

/// 로컬 영속성 (FR-10) — JSON 직렬화 후 shared_preferences 저장.
/// MP3에서 Firestore 동기화 계층(SyncStore)을 이 위에 얹는다.
class LocalStore implements TaskStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  // 동기화 필드(updatedAt·deleted)가 생겨서 v2로 올렸다 (2026-11-09)
  static const _kTasks = 'keepy.tasks.v2';
  static const _kLog = 'keepy.doneLog.v2';
  static const _kSettings = 'keepy.settings.v2';

  static const _kTasksV1 = 'keepy.tasks.v1';
  static const _kLogV1 = 'keepy.doneLog.v1';
  static const _kSettingsV1 = 'keepy.settings.v1';

  static Future<LocalStore> open() async {
    final store = LocalStore(await SharedPreferences.getInstance());
    await store._migrateV1();
    return store;
  }

  @override
  bool get hasData => _prefs.containsKey(_kTasks);

  @override
  List<Map<String, Object?>> readTasks() => _readList(_kTasks);

  @override
  List<Map<String, Object?>> readLog() => _readList(_kLog);

  @override
  Map<String, Object?> readSettings() {
    final s = _prefs.getString(_kSettings);
    if (s == null) return const {};
    try {
      return (jsonDecode(s) as Map).cast<String, Object?>();
    } catch (_) {
      return const {};
    }
  }

  List<Map<String, Object?>> _readList(String key) {
    final s = _prefs.getString(key);
    if (s == null) return const [];
    try {
      return [
        for (final e in jsonDecode(s) as List) (e as Map).cast<String, Object?>(),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    await _prefs.setString(_kTasks, jsonEncode(tasks));
    await _prefs.setString(_kLog, jsonEncode(log));
    await _prefs.setString(_kSettings, jsonEncode(settings));
  }

  // ---------------------------------------------------------- 마이그레이션
  /// v1 → v2. 기존 사용자의 할 일이 사라지지 않게 **키를 올리기 전에** 옮긴다.
  /// 이미 v2가 있으면(=옮긴 적 있음) 아무것도 하지 않는다.
  ///
  /// v1 키는 **지우지 않고 남긴다**. 이유:
  /// - 팀 규칙상 브랜치별로 구현을 비교·선정하므로(TEAM_NOTES 3장) v1 코드로
  ///   되돌아가 실행하는 일이 흔하다. 지워 버리면 그때 데이터가 빈 상태가 된다.
  /// - 변환에 버그가 있어도 원본으로 다시 시작할 수 있다.
  /// - 담는 양이 수십~수백 건이라 중복 보관 비용이 사실상 없다.
  /// v2가 충분히 검증된 뒤(MP3 마무리)에 한 번 정리한다.
  /// 단, 그 사이에 v1 빌드로 돌아가 고친 내용은 v2로 다시 올라오지 않는다.
  Future<void> _migrateV1() async {
    if (_prefs.containsKey(_kTasks)) return; // 이미 v2
    if (!_prefs.containsKey(_kTasksV1)) return; // 첫 실행 — 옮길 것 없음

    // 태스크만 형식이 바뀐다 (updatedAt·deleted 추가)
    final tasks = [for (final t in _readList(_kTasksV1)) _upgradeTask(t)];
    await _prefs.setString(_kTasks, jsonEncode(tasks));

    // 완료 내역·설정은 형식 그대로, 키만 올린다
    final log = _prefs.getString(_kLogV1);
    if (log != null) await _prefs.setString(_kLog, log);
    final settings = _prefs.getString(_kSettingsV1);
    if (settings != null) await _prefs.setString(_kSettings, settings);
  }

  /// v1 태스크 맵에 동기화 필드를 채운다. `Task.fromJson`도 같은 기본값을
  /// 쓰지만(하위호환), 저장된 JSON 자체를 v2 형태로 맞춰 두려고 여기서도 채운다.
  /// 모델을 모르는 계층이므로 맵 수준에서만 손댄다.
  static Map<String, Object?> _upgradeTask(Map<String, Object?> t) => {
        ...t,
        'updatedAt': t['updatedAt'] ?? t['createdAt'],
        'deleted': t['deleted'] ?? false,
      };
}
