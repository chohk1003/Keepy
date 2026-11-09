import 'package:flutter/material.dart';
import 'package:keepy/screens/main_screen.dart';
import 'package:keepy/screens/settings_screen.dart';
import 'package:keepy/screens/calendar_screen.dart';

class HomeContainerScreen extends StatefulWidget {
  const HomeContainerScreen({super.key});

  @override
  State<HomeContainerScreen> createState() => _HomeContainerScreenState();
}

class _HomeContainerScreenState extends State<HomeContainerScreen> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentIndex = 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          SettingsScreen(),
          MainScreen(),
          CalendarScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '메인'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '날짜'),
        ],
      ),
    );
  }
}