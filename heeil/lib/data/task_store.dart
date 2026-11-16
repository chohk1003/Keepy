/// 저장소 공통 계약.
///
/// `AppState`는 이 인터페이스만 보고 쓴다. 그래서 MP3에서 Firestore 동기화
/// 계층(SyncStore)을 끼울 때도 `AppState`를 고칠 필요가 없다
/// (docs/firebase.md "계획 — 어디에 끼우나").
///
/// ```
/// AppState → TaskStore ─┬─ LocalStore (shared_preferences)
///                       └─ SyncStore  (LocalStore + 원격, MP3)
/// ```
abstract class TaskStore {
  /// 복원할 데이터가 있는지 (없으면 `AppState._seed()`)
  bool get hasData;

  List<Map<String, Object?>> readTasks();

  List<Map<String, Object?>> readLog();

  Map<String, Object?> readSettings();

  Future<void> write({
    required List<Map<String, Object?>> tasks,
    required List<Map<String, Object?>> log,
    required Map<String, Object?> settings,
  });
}
