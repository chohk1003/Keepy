import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../widgets/glass_tab_bar.dart';
import 'date_page.dart';
import 'main_page.dart';
import 'settings_page.dart';

/// 3단 수평 스와이프 + 유리 탭 바 (UI설계서 04)
/// [설정] ← [메인] → [날짜]
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final _pages = PageController(initialPage: 1);
  int _index = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AppScope.read(context).flush();
    }
  }

  void _go(int i) {
    if (i == _index) return;
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pages,
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        onPageChanged: (i) {
          HapticFeedback.selectionClick();
          FocusScope.of(context).unfocus();
          setState(() => _index = i);
        },
        children: const [SettingsPage(), MainPage(), DatePage()],
      ),
      bottomNavigationBar: keyboard
          ? null
          : GlassTabBar(
              controller: _pages,
              index: _index,
              tabs: keepyTabs,
              onTap: _go,
            ),
    );
  }
}
