/// 날짜 유틸. 모든 '기한'은 시각 없이 날짜(연·월·일)만 다룬다.
library;

const _weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];

/// 월요일 시작 요일 이름 (캘린더 머리줄).
const weekdayLabels = _weekdays;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 달력상의 날짜 차이 (b - a). 시각·서머타임과 무관하게 계산한다.
int daysBetween(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// 그 주의 월요일.
DateTime startOfWeek(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

String weekdayKo(DateTime d) => _weekdays[d.weekday - 1];

String formatMonthDay(DateTime d) => '${d.month}월 ${d.day}일';

String formatFull(DateTime d) => '${d.month}월 ${d.day}일 ${weekdayKo(d)}요일';

String formatYearMonth(DateTime d) => '${d.year}년 ${d.month}월';

String twoDigits(int n) => n.toString().padLeft(2, '0');

/// "오전 9:00" 형식.
String formatTimeOfDayMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final period = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$period ${twoDigits(h12)}:${twoDigits(m)}';
}

/// 할 일 배지에 쓰는 상대 날짜: 오늘 / 내일 / 모레 / 어제 / 11월 24일.
String relativeDayLabel(DateTime day, DateTime today) {
  final diff = daysBetween(today, day);
  switch (diff) {
    case 0:
      return '오늘';
    case 1:
      return '내일';
    case 2:
      return '모레';
    case -1:
      return '어제';
  }
  if (day.year != today.year) return '${day.year}. ${day.month}. ${day.day}.';
  return formatMonthDay(day);
}

/// 완료 기록용: "오늘 14:02" / "어제 09:10" / "11월 3일 18:40".
String formatCompletedAt(DateTime at, DateTime now) {
  final time = '${twoDigits(at.hour)}:${twoDigits(at.minute)}';
  final diff = daysBetween(at, now);
  if (diff == 0) return '오늘 $time';
  if (diff == 1) return '어제 $time';
  return '${formatMonthDay(at)} $time';
}

/// 'yyyy-MM-dd' ↔ DateTime (기한 저장용).
String toDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${twoDigits(d.month)}-${twoDigits(d.day)}';

DateTime? fromDateKey(String? key) {
  if (key == null || key.isEmpty) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}
