enum TaskPriority { low, normal, high }

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.dueAt,
    this.priority = TaskPriority.normal,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime? dueAt;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueAt,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? updatedAt,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        dueAt: dueAt ?? this.dueAt,
        priority: priority ?? this.priority,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'dueAt': dueAt?.toIso8601String(),
        'priority': priority.name,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Task.fromJson(String id, Map<String, dynamic> json) {
    TaskPriority parsedPriority = TaskPriority.normal;
    for (final priority in TaskPriority.values) {
      if (priority.name == json['priority']) {
        parsedPriority = priority;
        break;
      }
    }
    return Task(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? ''),
      priority: parsedPriority,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
