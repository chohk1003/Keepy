import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 꺾쇠괄호를 쓰지 않고 타입을 추론하도록 선언하여 에러 원인을 차단합니다.
  final _todos = [
    {'title': '모바일 앱 UI 시안 정리', 'sub': '오늘 · 국립국어원표준국어대사', 'done': false, 'tag': '#과제'},
    {'title': '자료구조 3주차 과제 제출', 'sub': '기한 24일 · eclass', 'done': false, 'tag': '#수업'},
  ];

  final TextEditingController _textController = TextEditingController();
  String? _selectedTag;
  String _selectedStatus = '전체';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addTodo() {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _todos.add({
        'title': _textController.text.trim(),
        'sub': '방금 추가됨 · Keepy',
        'done': false,
        'tag': _selectedTag ?? '#개인',
      });
      _textController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredTodos = _todos.where((todo) {
      final isDone = todo['done'] as bool;
      if (_selectedStatus == '미완료' && isDone) return false;
      if (_selectedStatus == '완료' && !isDone) return false;
      if (_selectedTag != null && todo['tag'] != _selectedTag) return false;
      return true;
    }).toList();

    final totalCount = _todos.length;
    final activeCount = _todos.where((t) => !(t['done'] as bool)).length;
    final doneCount = _todos.where((t) => t['done'] as bool).length;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '모든 할일',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusTab('전체', totalCount),
                const SizedBox(width: 16),
                _buildStatusTab('미완료', activeCount),
                const SizedBox(width: 16),
                _buildStatusTab('완료', doneCount),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['#과제', '#수업', '#팀 프로젝트', '#개인'].map((tag) {
                  final isSelected = _selectedTag == tag;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTag = selected ? tag : null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredTodos.isEmpty
                  ? const Center(child: Text('조건에 해당하는 할 일이 없습니다.'))
                  : ListView.builder(
                      itemCount: filteredTodos.length,
                      itemBuilder: (context, index) {
                        final todo = filteredTodos[index];
                        return CheckboxListTile(
                          title: Text(
                            todo['title'] as String,
                            style: TextStyle(
                              decoration: (todo['done'] as bool)
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: (todo['done'] as bool)
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                          subtitle: Text('${todo['sub']} · ${todo['tag']}'),
                          value: todo['done'] as bool,
                          onChanged: (bool? value) {
                            setState(() {
                              todo['done'] = value ?? false;
                            });
                          },
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _addTodo(),
                    decoration: const InputDecoration(
                      hintText: '메모나 태스크를 입력하세요',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab(String statusName, int count) {
    final isSelected = _selectedStatus == statusName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = statusName;
        });
      },
      child: Text(
        '$statusName $count',
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }
}