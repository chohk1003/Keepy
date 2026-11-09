import 'package:flutter/material.dart';

/// UI설계서 07: #과제, #수업, #팀 프로젝트, #개인
enum TaskTag {
  assignment('과제', [Color(0xFF0A84FF), Color(0xFF5E5CE6)]),
  lecture('수업', [Color(0xFFBF5AF2), Color(0xFFFF375F)]),
  team('팀 프로젝트', [Color(0xFFFF9F0A), Color(0xFFFF375F)]),
  personal('개인', [Color(0xFF30D158), Color(0xFF00C7BE)]);

  const TaskTag(this.label, this.colors);

  final String label;
  final List<Color> colors;

  Color get color => colors.first;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.done = false,
    this.due,
    this.doneAt,
    Set<TaskTag>? tags,
    DateTime? createdAt,
  })  : tags = tags ?? <TaskTag>{},
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  bool done;
  DateTime? due;

  /// 완료 시점 (늦은 완료 판정용)
  DateTime? doneAt;
  Set<TaskTag> tags;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'due': due?.toIso8601String(),
        'tags': [for (final t in tags) t.name],
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, Object?> j) {
    final tagNames = (j['tags'] as List?)?.cast<String>() ?? const <String>[];
    return Task(
      id: j['id'] as String,
      title: j['title'] as String,
      done: j['done'] as bool? ?? false,
      due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
      tags: {
        for (final t in TaskTag.values)
          if (tagNames.contains(t.name)) t,
      },
      createdAt: j['createdAt'] == null
          ? null
          : DateTime.parse(j['createdAt'] as String),
      doneAt: j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
    );
  }
}

/// 설정 화면의 완료 이벤트 내역
class DoneEvent {
  const DoneEvent(this.taskId, this.title, this.at);

  final String taskId;
  final String title;
  final DateTime at;

  Map<String, Object?> toJson() =>
      {'taskId': taskId, 'title': title, 'at': at.toIso8601String()};

  factory DoneEvent.fromJson(Map<String, Object?> j) => DoneEvent(
        j['taskId'] as String,
        j['title'] as String,
        DateTime.parse(j['at'] as String),
      );
}
