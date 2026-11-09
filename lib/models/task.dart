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
    DateTime? updatedAt,
    this.deleted = false,
  })  : tags = tags ?? <TaskTag>{},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  String title;
  bool done;
  DateTime? due;

  /// 완료 시점 (늦은 완료 판정용)
  DateTime? doneAt;
  Set<TaskTag> tags;
  final DateTime createdAt;

  /// 마지막 변경 시점 — 동기화 충돌 해결(Last-Write-Wins)의 비교 기준.
  /// 제목·완료·기한·태그가 바뀔 때마다 [touch]로 갱신한다.
  DateTime updatedAt;

  /// tombstone — 삭제 표식. 오프라인에서 지운 항목을 다른 기기에 전파하려면
  /// 바로 지우지 않고 표식만 남겨야 한다 (docs/firebase.md).
  bool deleted;

  /// 변경 시점을 찍는다 (LWW 비교용)
  void touch([DateTime? at]) => updatedAt = at ?? DateTime.now();

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'due': due?.toIso8601String(),
        'tags': [for (final t in tags) t.name],
        'createdAt': createdAt.toIso8601String(),
        'doneAt': doneAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  /// 구버전(v1) JSON 호환 — `updatedAt`이 없으면 `createdAt`으로,
  /// `deleted`가 없으면 false로 채운다.
  factory Task.fromJson(Map<String, Object?> j) {
    final tagNames = (j['tags'] as List?)?.cast<String>() ?? const <String>[];
    final created = j['createdAt'] == null
        ? null
        : DateTime.parse(j['createdAt'] as String);
    return Task(
      id: j['id'] as String,
      title: j['title'] as String,
      done: j['done'] as bool? ?? false,
      due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
      tags: {
        for (final t in TaskTag.values)
          if (tagNames.contains(t.name)) t,
      },
      createdAt: created,
      doneAt: j['doneAt'] == null ? null : DateTime.parse(j['doneAt'] as String),
      updatedAt: j['updatedAt'] == null
          ? created
          : DateTime.parse(j['updatedAt'] as String),
      deleted: j['deleted'] as bool? ?? false,
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
