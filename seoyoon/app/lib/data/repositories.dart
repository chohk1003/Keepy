import '../models/app_settings.dart';
import '../models/task.dart';

/// 할 일 저장소 계약.
///
/// 지금은 [LocalTaskRepository](shared_preferences)만 쓰지만,
/// BaaS(FR-11, FR-12)를 붙일 때 이 계약을 구현한 원격 저장소를
/// 추가하면 화면·상태 코드는 바꾸지 않아도 된다.
abstract class TaskRepository {
  Future<List<Task>> loadTasks();
  Future<void> saveTasks(List<Task> tasks);
}

abstract class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

/// 테스트·미리보기용 메모리 저장소.
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository([List<Task>? initial]) : _tasks = List<Task>.of(initial ?? const <Task>[]);

  List<Task> _tasks;
  int saveCount = 0;

  List<Task> get saved => List<Task>.unmodifiable(_tasks);

  @override
  Future<List<Task>> loadTasks() async => List<Task>.of(_tasks);

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    _tasks = List<Task>.of(tasks);
    saveCount++;
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async => _settings = settings;
}
