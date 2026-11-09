import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 0: 설정, 1: 메인, 2: 날짜
  final List<String> _tags = ['#과제', '#수업', '#팀 프로젝트', '#개인'];
  final Set<String> _selectedTags = {};
  final TextEditingController _taskController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('keepy.', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            key: const Key('accountButton'),
            icon: const CircleAvatar(child: Text('K')),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('모든 할일', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // 상태 탭 필터 (FR-05)
            Row(
              children: const [
                Text('전체 4', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                SizedBox(width: 16),
                Text('미완료 2', style: TextStyle(color: Colors.grey)),
                SizedBox(width: 16),
                Text('완료 2', style: TextStyle(color: Colors.grey, key: Key('filterDone'))),
              ],
            ),
            const SizedBox(height: 20),
            // 태스크 목록 영역
            Expanded(
              child: ListView(
                children: [
                  CheckboxListTile(
                    title: const Text('모바일 앱 UI 시안 정리'),
                    subtitle: const Text('오늘 · 국립국어원표준국어대사'),
                    value: false,
                    onChanged: (val) {},
                  ),
                  CheckboxListTile(
                    title: const Text('자료구조 3주차 과제 제출'),
                    subtitle: const Text('기한 24일 · eclass'),
                    value: false,
                    onChanged: (val) {},
                  ),
                ],
              ),
            ),
            // 태그 칩 선택 영역 (UI 07)
            Wrap(
              spacing: 8.0,
              children: _tags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // 빠른 태스크 추가 입력창 (FR-02, CST-03)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('quickAddField'),
                    controller: _taskController,
                    decoration: const InputDecoration(
                      hintText: '메모나 태스크를 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('quickAddSend'),
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    // 등록 로직
                  },
                ),
                IconButton(
                  key: const Key('cameraButton'),
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {
                    // OCR 촬영 화면 진입
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // 스와이프 및 탭 내비게이션 처리
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