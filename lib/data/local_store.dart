import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 영속성 (FR-10) — JSON 직렬화 후 shared_preferences 저장.
/// MP3에서 Firestore 동기화 계층을 이 위에 얹는다.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kTasks = 'keepy.tasks.v1';
  static const _kLog = 'keepy.doneLog.v1';
  static const _kSettings = 'keepy.settings.v1';

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  bool get hasData => _prefs.containsKey(_kTasks);

  List<Map<String, Object?>> readTasks() => _readList(_kTasks);

  List<Map<String, Object?>> readLog() => _readList(_kLog);

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

  Future<void> write({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  }) async {
    await _prefs.setString(_kTasks, jsonEncode(tasks));
    await _prefs.setString(_kLog, jsonEncode(log));
    await _prefs.setString(_kSettings, jsonEncode(settings));
  }
}
