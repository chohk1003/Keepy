import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import '../models/app_settings.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore({required SettingsRepository repository}) : _repository = repository;

  final SettingsRepository _repository;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> load() async {
    _settings = await _repository.loadSettings();
    notifyListeners();
  }

  void update(AppSettings Function(AppSettings current) change) {
    final next = change(_settings);
    _settings = next;
    notifyListeners();
    _repository.saveSettings(next).catchError((Object e) {
      debugPrint('Keepy: 설정 저장 실패 ($e)');
    });
  }
}
