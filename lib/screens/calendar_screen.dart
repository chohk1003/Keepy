import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // 현재 선택된 날짜
  DateTime _selectedDate = DateTime.now();
  
  // 날짜별 할 일 데이터 맵 (예시 데이터)
  final Map<String, List<String>> _tasksByDate = {
    '2026-06-06': ['모바일 앱 UI 시안 정리', '팀 회의 준비'],
    '2026-06-24': ['자료구조 3주차 과제 제출'],
  };

  @override
  Widget build(BuildContext context) {
    // 날짜를 'YYYY-MM-DD' 형식의 키로 변환
    final dateKey = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final currentTasks = _tasksByDate[dateKey] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('날짜 및 일정'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 월간 캘린더 헤더 및 간단 그리드 뷰
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.year}년 ${_selectedDate.month}월',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 요일 표시 바
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('일', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Text('월'), Text('화'), Text('수'), Text('목'), Text('금'),
                Text('토', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),

            // 간단 날짜 선택 그리드 (이번 달 날짜 예시 시뮬레이션)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 30, // 30일까지 표시 시뮬레이션
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isSelected = _selectedDate.day == day;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, day);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 선택된 날짜의 일정 목록 영역
            Text(
              '선택한 날짜: $dateKey',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: currentTasks.isEmpty
                  ? const Center(child: Text('등록된 일정이 없습니다.'))
                  : ListView.builder(
                      itemCount: currentTasks.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
                          title: Text(currentTasks[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}