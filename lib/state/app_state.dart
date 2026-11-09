import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../util/dates.dart';

enum TaskFilter { all, todo, done }

/// 할 일 분류
/// - pending: 할 일
/// - overdue: 지연 (기한이 지났는데 미완료)
/// - done: 완료
/// - late: 늦은 완료 (지연 상태에서 완료)
enum TaskStatus { pending, overdue, done, late }

/// 금일 완료율 형태 (UI설계서 01-3: 바 / 원형 / 그래프)
enum RateStyle { bar, ring, graph }

class AppState extends ChangeNotifier {
  /// [store]가 없으면 메모리에만 보관 (테스트용)
  AppState({this.store, bool seed = false}) {
    final s = store;
    if (s != null && s.hasData) {
      _load(s);
    } else if (s != null || seed) {
      _seed();
    }
    // 시간이 지나 '지연'으로 넘어가는 항목을 반영하려고 1분마다 다시 그림
    if (s != null) {
      _clock = Timer.periodic(const Duration(minutes: 1), (_) => super.notifyListeners());
    }
  }

  Timer? _clock;

  /// `LocalStore` 또는 MP3의 `SyncStore` (같은 인터페이스)
  final TaskStore? store;

  // ---------------------------------------------------------------- 태스크
  final List<Task> _tasks = [];
  final List<DoneEvent> doneLog = [];
  int _seq = 0;

  /// 화면에 보이는 태스크 — tombstone(`deleted`)은 모두 걸러진다.
  /// **목록 조회는 전부 이걸 거쳐야 한다** (빠뜨리면 지운 항목이 캘린더나
  /// 집계에 남는다). 저장·동기화는 tombstone까지 포함한 [_tasks]를 쓴다.
  Iterable<Task> get _live => _tasks.where((t) => !t.deleted);

  List<Task> get tasks => List.unmodifiable(_live);
  List<Task> get todo => sortByDate(_live.where((t) => !t.done));
  List<Task> get done => sortByDate(_live.where((t) => t.done));

  List<Task> ofStatus(TaskStatus st) =>
      sortByDate(_live.where((t) => statusOf(t) == st));

  /// 날짜순: 기한 빠른 순 → 기한 없는 항목은 뒤 → 같은 날은 만든 순
  static List<Task> sortByDate(Iterable<Task> list) {
    final out = list.toList();
    out.sort((a, b) {
      final ad = a.due, bd = b.due;
      if (ad == null && bd != null) return 1;
      if (ad != null && bd == null) return -1;
      if (ad != null && bd != null) {
        final c = ad.compareTo(bd);
        if (c != 0) return c;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
    return out;
  }

  // ---------------------------------------------------------------- 분류
  /// 기한 없는 할 일이 만든 뒤 며칠 지나면 '지연'인지 (0 = 지연 처리 안 함)
  int overdueDays = 3;

  /// 지연 기준 시점: 기한이 있으면 기한 다음 날 0시, 없으면 만든 뒤 [overdueDays]일
  DateTime? deadlineOf(Task t) {
    final due = t.due;
    if (due != null) return addDays(due, 1);
    if (overdueDays <= 0) return null;
    return t.createdAt.add(Duration(days: overdueDays));
  }

  TaskStatus statusOf(Task t, {DateTime? now}) {
    final deadline = deadlineOf(t);
    if (t.done) {
      final at = t.doneAt;
      return deadline != null && at != null && at.isAfter(deadline)
          ? TaskStatus.late
          : TaskStatus.done;
    }
    return deadline != null && (now ?? DateTime.now()).isAfter(deadline)
        ? TaskStatus.overdue
        : TaskStatus.pending;
  }

  void setOverdueDays(int d) {
    overdueDays = d;
    notifyListeners();
  }

  /// 태그 사용 빈도순 (같으면 기본 순서)
  List<TaskTag> tagsByUsage() {
    final count = {for (final g in TaskTag.values) g: 0};
    for (final t in _live) {
      for (final g in t.tags) {
        count[g] = count[g]! + 1;
      }
    }
    final list = TaskTag.values.toList();
    list.sort((a, b) {
      final c = count[b]!.compareTo(count[a]!);
      return c != 0 ? c : a.index.compareTo(b.index);
    });
    return list;
  }

  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_seq++}';

  /// 새 항목은 `Task` 생성자가 `updatedAt`을 `createdAt`과 같게 맞춘다.
  Task add(String title, {DateTime? due, Set<TaskTag>? tags}) {
    final t = Task(
      id: _nextId(),
      title: title.trim(),
      due: due == null ? null : dayOf(due),
      tags: {...?tags},
    );
    _tasks.insert(0, t);
    notifyListeners();
    return t;
  }

  int addAll(Iterable<String> titles, {DateTime? due}) {
    var n = 0;
    for (final title in titles) {
      final s = title.trim();
      if (s.isEmpty) continue;
      _tasks.insert(
        n,
        Task(id: _nextId(), title: s, due: due == null ? null : dayOf(due)),
      );
      n++;
    }
    if (n > 0) notifyListeners();
    return n;
  }

  void setDone(Task t, bool value) {
    if (t.done == value) return;
    t.done = value;
    t.doneAt = value ? DateTime.now() : null;
    t.touch();
    if (value) {
      doneLog.insert(0, DoneEvent(t.id, t.title, DateTime.now()));
      if (doneLog.length > 100) doneLog.removeLast();
    } else if (doneLog.isNotEmpty && doneLog.first.taskId == t.id) {
      doneLog.removeAt(0);
    }
    notifyListeners();
  }

  /// 되돌리기(`restore`)가 인덱스를 쓰므로 **지금은 목록에서 실제로 뺀다**.
  /// Firestore를 붙일 때 `t.deleted = true; t.touch();`로 바꾼다
  /// (조회는 이미 [_live]에서 tombstone을 걸러 두었다).
  int remove(Task t) {
    final i = _tasks.indexOf(t);
    if (i >= 0) {
      _tasks.removeAt(i);
      notifyListeners();
    }
    return i;
  }

  void restore(int index, Task t) {
    if (_tasks.contains(t)) return;
    _tasks.insert(math.max(0, math.min(index, _tasks.length)), t);
    notifyListeners();
  }

  /// 완료 항목 일괄 삭제 → 되돌리기용 스냅샷 반환
  /// (`remove`와 같은 이유로 아직 실제 삭제. tombstone 전환 시 함께 바꾼다)
  List<Task> clearDone() {
    final before = List.of(_tasks);
    _tasks.removeWhere((t) => t.done && !t.deleted);
    notifyListeners();
    return before;
  }

  void restoreAll(List<Task> snapshot) {
    _tasks
      ..clear()
      ..addAll(snapshot);
    notifyListeners();
  }

  void update(
    Task t, {
    String? title,
    Set<TaskTag>? tags,
    DateTime? due,
    bool clearDue = false,
  }) {
    if (title != null) t.title = title.trim();
    if (tags != null) t.tags = {...tags};
    if (clearDue) {
      t.due = null;
    } else if (due != null) {
      t.due = dayOf(due);
    }
    t.touch();
    notifyListeners();
  }

  List<Task> onDay(DateTime d) =>
      _live.where((t) => sameDay(t.due, d)).toList();

  /// 그날의 (완료 개수, 전체 개수)
  ({int done, int total}) dayCounts(DateTime d) {
    var done = 0;
    var total = 0;
    for (final t in _live) {
      if (!sameDay(t.due, d)) continue;
      total++;
      if (t.done) done++;
    }
    return (done: done, total: total);
  }

  /// [d] 기준 앞(dir > 0)·뒤(dir < 0)로 가장 가까운 '할 일이 있는 날'
  DateTime? neighborTaskDay(DateTime d, int dir) {
    DateTime? best;
    for (final t in _live) {
      final due = t.due;
      if (due == null) continue;
      final diff = dayDiff(d, due);
      if (dir > 0 ? diff <= 0 : diff >= 0) continue;
      if (best == null || (dir > 0 ? due.isBefore(best) : due.isAfter(best))) {
        best = due;
      }
    }
    return best == null ? null : dayOf(best);
  }

  double dayRate(DateTime d) {
    final list = onDay(d);
    if (list.isEmpty) return 0;
    return list.where((t) => t.done).length / list.length;
  }

  // ---------------------------------------------------------------- 화면 상태
  TaskFilter filter = TaskFilter.all;
  DateTime selectedDay = dayOf(DateTime.now());
  int weekOffset = 0;

  void setFilter(TaskFilter f) {
    if (filter == f) return;
    filter = f;
    notifyListeners();
  }

  void selectDay(DateTime d, {bool syncWeek = true}) {
    selectedDay = dayOf(d);
    if (syncWeek) {
      weekOffset = dayDiff(weekStart(DateTime.now()), weekStart(d)) ~/ 7;
    }
    notifyListeners();
  }

  void setWeekOffset(int v) {
    if (weekOffset == v) return;
    weekOffset = v;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 설정
  int calendarRows = 2;
  int thisWeekRow = 1;
  RateStyle rateStyle = RateStyle.ring;
  bool notify = true;
  final Set<int> remindDays = {0};
  TimeOfDay notifyTime = const TimeOfDay(hour: 9, minute: 0);
  bool eclass = false;
  bool everytime = false;

  void setCalendarRows(int r) {
    calendarRows = r;
    if (thisWeekRow > r) thisWeekRow = r;
    notifyListeners();
  }

  void setThisWeekRow(int r) {
    thisWeekRow = r;
    notifyListeners();
  }

  void setRateStyle(RateStyle s) {
    rateStyle = s;
    notifyListeners();
  }

  void setNotify(bool v) {
    notify = v;
    notifyListeners();
  }

  void toggleRemind(int days) {
    if (!remindDays.remove(days)) remindDays.add(days);
    notifyListeners();
  }

  void setNotifyTime(TimeOfDay t) {
    notifyTime = t;
    notifyListeners();
  }

  void setEclass(bool v) {
    eclass = v;
    notifyListeners();
  }

  void setEverytime(bool v) {
    everytime = v;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 저장
  Timer? _saveTimer;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (store == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), flush);
  }

  /// 즉시 저장 (앱이 백그라운드로 갈 때도 호출)
  Future<void> flush() async {
    _saveTimer?.cancel();
    final s = store;
    if (s == null) return;
    await s.write(
      tasks: [for (final t in _tasks) t.toJson()],
      log: [for (final e in doneLog) e.toJson()],
      settings: _settingsJson(),
    );
  }

  Map<String, Object?> _settingsJson() => {
        'calendarRows': calendarRows,
        'thisWeekRow': thisWeekRow,
        'rateStyle': rateStyle.name,
        'notify': notify,
        'remindDays': remindDays.toList(),
        'notifyTime': '${notifyTime.hour}:${notifyTime.minute}',
        'eclass': eclass,
        'everytime': everytime,
        'overdueDays': overdueDays,
      };

  void _load(TaskStore s) {
    for (final j in s.readTasks()) {
      try {
        _tasks.add(Task.fromJson(j));
      } catch (_) {
        // 손상된 항목은 건너뜀
      }
    }
    for (final j in s.readLog()) {
      try {
        doneLog.add(DoneEvent.fromJson(j));
      } catch (_) {}
    }
    final m = s.readSettings();
    calendarRows = (m['calendarRows'] as int? ?? 2).clamp(1, 4);
    thisWeekRow = (m['thisWeekRow'] as int? ?? 1).clamp(1, calendarRows);
    rateStyle = RateStyle.values.firstWhere(
      (e) => e.name == m['rateStyle'],
      orElse: () => RateStyle.ring,
    );
    notify = m['notify'] as bool? ?? true;
    final rd = (m['remindDays'] as List?)?.cast<int>();
    if (rd != null) {
      remindDays
        ..clear()
        ..addAll(rd);
    }
    final nt = (m['notifyTime'] as String?)?.split(':');
    if (nt != null && nt.length == 2) {
      notifyTime = TimeOfDay(
        hour: int.tryParse(nt[0]) ?? 9,
        minute: int.tryParse(nt[1]) ?? 0,
      );
    }
    eclass = m['eclass'] as bool? ?? false;
    everytime = m['everytime'] as bool? ?? false;
    overdueDays = m['overdueDays'] as int? ?? 3;
  }

  void _seed() {
    final today = dayOf(DateTime.now());
    Task mk(String title, int? inDays, Set<TaskTag> tags, {bool done = false}) =>
        Task(
          id: _nextId(),
          title: title,
          due: inDays == null ? null : addDays(today, inDays),
          tags: tags,
          done: done,
        );
    _tasks.addAll([
      mk('운영체제 과제', 0, {TaskTag.assignment}),
      mk('장보기', 0, {TaskTag.personal}),
      mk('팀 회의 자료', 0, {TaskTag.team}, done: true),
      mk('컴그 복습', 1, {TaskTag.lecture}),
      mk('헬스', 2, {TaskTag.personal}),
      mk('네트워크 퀴즈', -1, {TaskTag.lecture}),
      mk('알고리즘 문제', null, {}),
    ]);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// 상태 변경 시 다시 그림
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// 콜백 안에서 읽기만 할 때
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
