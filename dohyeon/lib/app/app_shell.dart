import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  static const paths = ['/tasks', '/calendar', '/ocr', '/settings'];

  @override
  Widget build(BuildContext context) {
    var index = paths.indexOf(location);
    if (index < 0) index = 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(paths[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist), label: '태스크'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month), label: '날짜'),
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner), label: 'OCR'),
          NavigationDestination(icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
