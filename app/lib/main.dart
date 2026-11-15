import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local_repositories.dart';
import 'services/ocr_factory.dart';
import 'state/settings_store.dart';
import 'state/task_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsStore(repository: LocalSettingsRepository());
  final tasks = TaskStore(repository: LocalTaskRepository());
  await Future.wait(<Future<void>>[settings.load(), tasks.load()]);

  // '지연' 기준 일수는 설정에서 바뀌면 바로 반영한다 (prompts_log #11).
  tasks.delayDays = settings.settings.delayDays;
  settings.addListener(() => tasks.delayDays = settings.settings.delayDays);

  runApp(KeepyApp(tasks: tasks, settings: settings, ocr: createOcrService()));
}
