/// Character artwork is replaceable; progress never depends on the animal.
enum CompanionKind { dog, cat }

enum ActivityKind { study, teamwork, life, other }

ActivityKind activityFor(Iterable<String> tags) {
  final names = tags.toSet();
  if (names.contains('team')) return ActivityKind.teamwork;
  if (names.contains('assignment') || names.contains('lecture')) {
    return ActivityKind.study;
  }
  if (names.contains('personal')) return ActivityKind.life;
  return ActivityKind.other;
}

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// One credit per task. Archiving a task retains it; undoing completion makes
/// it inactive. Delivery is retained across re-checks to prevent repeat rewards.
class CompletionCredit {
  const CompletionCredit({
    required this.at,
    required this.activity,
    this.deliveredAt,
  });
  final DateTime at;
  final ActivityKind activity;
  final DateTime? deliveredAt;

  CompletionCredit delivered(DateTime when) => CompletionCredit(
    at: at,
    activity: activity,
    deliveredAt: deliveredAt ?? when,
  );

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'activity': activity.name,
    'deliveredAt': deliveredAt?.toIso8601String(),
  };

  static CompletionCredit? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null) return null;
    return CompletionCredit(
      at: at,
      activity: ActivityKind.values.firstWhere(
        (a) => a.name == raw['activity'],
        orElse: () => ActivityKind.other,
      ),
      deliveredAt: DateTime.tryParse('${raw['deliveredAt']}'),
    );
  }
}

class DailyGoal {
  const DailyGoal({required this.planned, required this.completed});
  final int planned;
  final int completed;
  bool get achieved => planned > 0 && completed >= planned;
  Map<String, Object?> toJson() => {'planned': planned, 'completed': completed};
  static DailyGoal? fromJson(Object? raw) {
    if (raw is! Map || raw['planned'] is! int || raw['completed'] is! int) {
      return null;
    }
    final total = raw['planned'] as int;
    if (total < 0) return null;
    return DailyGoal(
      planned: total,
      completed: (raw['completed'] as int).clamp(0, total),
    );
  }
}

class RewardSpec {
  const RewardSpec(this.id, this.label, this.target, {this.streak = false});
  final String id;
  final String label;
  final int target;
  final bool streak;
}

const companionRewards = [
  RewardSpec('first', '첫 조각', 1),
  RewardSpec('plant', '작은 화분', 10),
  RewardSpec('cushion', '포근한 쿠션', 30),
  RewardSpec('lamp', '별빛 조명', 100),
  RewardSpec('streak3', '세 날의 발자국', 3, streak: true),
  RewardSpec('streak7', '일주일의 약속', 7, streak: true),
  RewardSpec('streak14', '꾸준한 친구', 14, streak: true),
  RewardSpec('streak30', '함께한 한 달', 30, streak: true),
];
