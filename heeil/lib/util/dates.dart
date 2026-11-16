DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

/// from → to 날짜 차이(일)
int dayDiff(DateTime from, DateTime to) =>
    (dayOf(to).difference(dayOf(from)).inHours / 24).round();

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// 일요일 시작 주의 첫날
DateTime weekStart(DateTime d) => addDays(dayOf(d), -(d.weekday % 7));

const weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];
const weekdayLongKo = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
const weekHeaderKo = ['일', '월', '화', '수', '목', '금', '토'];

String two(int n) => n.toString().padLeft(2, '0');

String md(DateTime d) => '${d.month}/${d.day}';

String mdw(DateTime d) => '${d.month}/${d.day} ${weekdayKo[d.weekday - 1]}';

String longKo(DateTime d) => '${d.month}월 ${d.day}일 ${weekdayLongKo[d.weekday - 1]}';

String hm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

String dueLabel(DateTime due, {DateTime? now}) {
  final n = dayDiff(now ?? DateTime.now(), due);
  return switch (n) {
    0 => '오늘',
    1 => '내일',
    2 => '모레',
    -1 => '어제',
    _ => md(due),
  };
}
