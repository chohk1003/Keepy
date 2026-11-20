import '../core/dates.dart';

/// 할 일 하나 (용어 정의: 태스크).
///
/// 로컬 저장소에 JSON 으로 직렬화된다 (FR-10).
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.done = false,
    this.completedAt,
    this.due,
    this.tags = const <String>[],
    this.completedLate = false,
    this.updatedAt,
    double? order,
  }) : order = order ?? 0.0;

  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;

  /// 완료한 시각 (완료 기록·늦은 완료 판단).
  final DateTime? completedAt;

  /// 마감일 (날짜만). null 이면 '날짜 미지정'.
  final DateTime? due;

  /// 태그 이름 목록 (# 없이 저장: '과제', '팀 프로젝트').
  final List<String> tags;

  /// '지연' 상태에서 완료했는지 → '늦은 완료' (prompts_log #11).
  final bool completedLate;

  /// 마지막 수정 시각 — BaaS 병합(FR-12) 때 최신 판정 기준으로 쓴다.
  final DateTime? updatedAt;

  /// 사용자가 편집 모드에서 정한 순서 (작을수록 위). v0.3 추가.
  final double order;

  Task copyWith({
    String? title,
    bool? done,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? due,
    bool clearDue = false,
    List<String>? tags,
    bool? completedLate,
    DateTime? updatedAt,
    double? order,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      done: done ?? this.done,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      due: clearDue ? null : (due ?? this.due),
      tags: tags ?? this.tags,
      completedLate: completedLate ?? this.completedLate,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'due': due == null ? null : toDateKey(due!),
        'tags': tags,
        'completedLate': completedLate,
        'updatedAt': updatedAt?.toIso8601String(),
        'order': order,
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final rawOrder = json['order'];
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      done: (json['done'] as bool?) ?? false,
      createdAt: createdAt,
      completedAt: _parseDateTime(json['completedAt']),
      due: fromDateKey(json['due'] as String?),
      tags: rawTags is List ? rawTags.whereType<String>().toList() : const <String>[],
      completedLate: (json['completedLate'] as bool?) ?? false,
      updatedAt: _parseDateTime(json['updatedAt']),
      // v0.2 데이터에는 순서가 없으므로 만든 시각을 순서로 쓴다
      order: rawOrder is num ? rawOrder.toDouble() : createdAt.millisecondsSinceEpoch.toDouble(),
    );
  }

  static DateTime? _parseDateTime(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  @override
  String toString() => 'Task($id, "$title", done: $done, due: $due)';
}

/// 처음 설치했을 때의 기본 태그 (UI 설계서 07).
/// v0.3부터 사용자가 설정한 태그 목록은 AppSettings.tags 에 있다.
const defaultTags = <String>['과제', '수업', '팀 프로젝트', '개인'];

/// 태그 이름 규칙: 공백 제외 1~12자, '#' 은 쓰지 않는다.
class TagRule {
  TagRule._();

  static const maxLength = 12;
  static const maxCount = 12;

  static String normalize(String raw) => raw.replaceAll('#', '').trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? errorOf(String raw, List<String> existing, {String? except}) {
    final t = normalize(raw);
    if (t.isEmpty) return '태그 이름을 입력해 주세요';
    if (t.length > maxLength) return '$maxLength자 이하로 입력해 주세요';
    if (existing.any((e) => e == t && e != except)) return '이미 있는 태그예요';
    return null;
  }
}

/// 제목 유효성 (CST-03, UI 설계서 07-2): 공백 제외 1자 이상, 100자 이하.
class TitleRule {
  TitleRule._();

  static const maxLength = 100;

  static String normalize(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  static bool isValid(String raw) {
    final t = normalize(raw);
    return t.isNotEmpty && t.length <= maxLength;
  }

  /// 오류 문구, 문제없으면 null.
  static String? errorOf(String raw) {
    final t = normalize(raw);
    if (t.isEmpty) return '할 일을 한 글자 이상 입력해 주세요';
    if (t.length > maxLength) return '$maxLength자 이하로 입력해 주세요';
    return null;
  }
}
