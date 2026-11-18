import 'package:flutter/material.dart';

import 'app.dart';
import 'core/env.dart';
import 'data/local_repositories.dart';
import 'services/ocr_factory.dart';
import 'services/sync/supabase_backend.dart';
import 'services/sync/sync_ledger.dart';
import 'state/settings_store.dart';
import 'state/sync_controller.dart';
import 'state/task_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsStore(repository: LocalSettingsRepository());
  final tasks = TaskStore(repository: LocalTaskRepository());
  await Future.wait(<Future<void>>[settings.load(), tasks.load()]);

  // '지연' 기준 일수는 설정에서 바뀌면 바로 반영한다 (prompts_log #11).
  tasks.delayDays = settings.settings.delayDays;
  settings.addListener(() => tasks.delayDays = settings.settings.delayDays);

  // MP3 서버 동기화: .env 값이 들어온 실행에서만 켠다 (키는 코드에 없음).
  final sync = KeepyEnv.syncConfigured
      ? SyncController(
          tasks: tasks,
          backend: SupabaseBackend(url: KeepyEnv.supabaseUrl, anonKey: KeepyEnv.supabaseAnonKey),
          repository: LocalSyncStateRepository(),
        )
      : SyncController.disabled();
  await sync.init();

  runApp(KeepyApp(tasks: tasks, settings: settings, ocr: createOcrService(), sync: sync));
}
