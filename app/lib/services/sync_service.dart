import '../models/task.dart';

/// BaaS 동기화 계약 (FR-01, FR-11, FR-12) — 다음 단계(MP3)에서 구현.
///
/// 붙이는 순서 제안:
/// 1. `.env.example` 을 복사해 `.env` 에 키를 넣는다 (NFR-06, 코드에 하드코딩 금지).
/// 2. 이 계약을 구현한 `SupabaseSyncService` 또는 `FirebaseSyncService` 를 만든다.
/// 3. `TaskStore` 의 저장 직후 [push] 를, 앱 시작·온라인 복귀 시 [pull] 을 부른다.
/// 4. 병합 기준은 `Task.updatedAt` (마지막 수정 우선).
abstract class SyncService {
  bool get isSignedIn;
  String? get accountEmail;

  Future<void> signIn();
  Future<void> signOut();

  /// 로컬 변경을 서버로 보낸다. 오프라인이면 대기열에 쌓아 두었다가 복귀 시 전송.
  Future<void> push(List<Task> tasks);

  /// 서버 변경을 받아 로컬과 병합한 결과를 돌려준다.
  Future<List<Task>> pull(List<Task> local);
}

/// 현재 기본값: 동기화 없이 이 기기에만 저장.
class LocalOnlySyncService implements SyncService {
  const LocalOnlySyncService();

  @override
  bool get isSignedIn => false;

  @override
  String? get accountEmail => null;

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> push(List<Task> tasks) async {}

  @override
  Future<List<Task>> pull(List<Task> local) async => local;
}
