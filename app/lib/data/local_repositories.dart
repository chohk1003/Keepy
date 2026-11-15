import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/task.dart';
import 'repositories.dart';

/// shared_preferences 에 JSON 문자열로 저장하는 로컬 저장소 (FR-10).
///
/// 앱을 껐다 켜거나 기기를 재부팅해도 데이터가 유지된다.
class LocalTaskRepository implements TaskRepository {
  LocalTaskRepository({SharedPreferences? prefs}) : _prefs = prefs;

  static const storageKey = 'keepy.tasks.v1';
  static const backupKey = 'keepy.tasks.v1.corrupt';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _instance async => _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<List<Task>> loadTasks() async {
    final prefs = await _instance;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <Task>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Task.fromJson)
          .toList();
    } catch (error) {
      // 깨진 데이터는 지우지 않고 따로 보관해 두고 빈 목록으로 시작한다.
      debugPrint('Keepy: 저장된 할 일을 읽지 못했습니다 ($error)');
      await prefs.setString(backupKey, raw);
      return <Task>[];
    }
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await _instance;
    final raw = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(storageKey, raw);
  }
}

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository({SharedPreferences? prefs}) : _prefs = prefs;

  static const storageKey = 'keepy.settings.v1';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _instance async => _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<AppSettings> loadSettings() async {
    final prefs = await _instance;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Keepy: 설정을 읽지 못해 기본값을 씁니다 ($error)');
      return const AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await _instance;
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }
}
