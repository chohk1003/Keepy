import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class KeepyApp extends ConsumerWidget {
  const KeepyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Keepy Prototype',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 90, 247),
          surface: const Color(0xFFFAFCFB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF3F7F5),
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.bold,
            color: Color(0xFF20312D)),
        ),
      ),
    );
  }
}
