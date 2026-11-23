import 'dart:async';

import 'package:flutter/material.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../models/companion.dart';
import '../theme.dart';
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
  AppState({this.store, bool seed = false, DateTime Function()? clock})
    : _now = clock ?? DateTime.now {
    final s = store;
    if (s != null && s.hasData) {
      _load(s);
    } else if (s != null || seed) {
      _seed();
    }
    _refreshProgress();
    // Refresh day boundaries as well as overdue labels.
    if (s != null) {
      _clock = Timer.periodic(
        const Duration(minutes: 1),
        (_) => notifyListeners(),
      );
    }
  }

  Timer? _clock;
  final DateTime Function() _now;
  DateTime get now => _now();
  final Map<String, DailyGoal> dayGoals = {};
  final Set<String> unlockedRewards = {};

  /// Includes archived completed tasks; a completion undo removes the credit
  /// from statistics without erasing whether it has already been delivered.
  List<Task> get creditedTasks =>
      _tasks.where((t) => t.done && t.credit != null).toList();

  List<Task> creditsBetween(DateTime start, DateTime end) =>
      creditedTasks.where((t) {
        final at = t.credit!.at;
        return !at.isBefore(start) && at.isBefore(end);
      }).toList();

  Map<ActivityKind, int> activityCounts([DateTime? start, DateTime? end]) {
    final source = start == null || end == null
        ? creditedTasks
        : creditsBetween(start, end);
    return {
      for (final a in ActivityKind.values)
        a: source.where((t) => t.credit!.activity == a).length,
    };
  }

  DailyGoal get todayGoal =>
      dayGoals[dayKey(now)] ?? const DailyGoal(planned: 0, completed: 0);

  int get currentStreak {
    var count = 0;
    final today = dayKey(now);
    final keys = dayGoals.keys.where((k) => k.compareTo(today) <= 0).toList()
      ..sort();
    for (final key in keys.reversed) {
      final goal = dayGoals[key]!;
      if (goal.planned == 0) {
        continue; // Rest days neither increase nor break it.
      }
      if (!goal.achieved) {
        if (key == today) continue; // Today is not over yet.
        break;
      }
      count++;
    }
    return count;
  }

  int get longestStreak {
    var best = 0, run = 0;
    final keys = dayGoals.keys.toList()..sort();
    for (final key in keys) {
      final goal = dayGoals[key]!;
      if (goal.planned == 0) continue;
      run = goal.achieved ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }

  void _refreshProgress() {
    final today = dayOf(now);
    // A pre-upgrade completion is history, not a fresh reward to feed again.
    for (final t in _tasks) {
      if (t.done && t.credit == null && t.doneAt != null) {
        t.credit = CompletionCredit(
          at: t.doneAt!,
          activity: activityFor(t.tags.map((t) => t.name)),
          deliveredAt: t.doneAt,
        );
      }
    }
    final dates = <String, DateTime>{dayKey(today): today};
    for (final t in _tasks) {
      if (t.due != null && !dayOf(t.due!).isAfter(today)) {
        dates[dayKey(t.due!)] = dayOf(t.due!);
      }
    }
    for (final entry in dates.entries) {
      if (entry.key != dayKey(today) && dayGoals.containsKey(entry.key)) {
        continue;
      }
      final end = addDays(entry.value, 1);
      final planned = _tasks
          .where(
            (t) =>
                sameDay(t.due, entry.value) &&
                (!t.deleted || (t.done && t.credit != null)),
          )
          .toList();
      dayGoals[entry.key] = DailyGoal(
        planned: planned.length,
        completed: planned
            .where((t) => t.done && t.doneAt != null && t.doneAt!.isBefore(end))
            .length,
      );
    }
    for (final reward in companionRewards) {
      if ((reward.streak ? longestStreak : creditedTasks.length) >=
          reward.target) {
        unlockedRewards.add(reward.id);
      }
    }
  }

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

  /// 제목 최대 길이 (입력 바와 같은 규칙, CST-03)
  static const maxTitle = 100;

  int addAll(Iterable<String> titles, {DateTime? due}) {
    var n = 0;
    for (final title in titles) {
      var s = title.trim();
      if (s.isEmpty) continue;
      // OCR 경로에도 입력 바와 같은 1~100자 규칙 적용 (넘치면 자름)
      if (s.characters.length > maxTitle) {
        s = s.characters.take(maxTitle).toString().trimRight();
      }
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
    t.doneAt = value ? now : null;
    t.touch(now);
    if (value) {
      t.credit = CompletionCredit(
        at: now,
        activity: activityFor(t.tags.map((g) => g.name)),
        deliveredAt: t.credit?.deliveredAt,
      );
    }
    if (value) {
      doneLog.insert(0, DoneEvent(t.id, t.title, now));
      if (doneLog.length > 100) doneLog.removeLast();
    } else if (doneLog.isNotEmpty && doneLog.first.taskId == t.id) {
      doneLog.removeAt(0);
    }
    notifyListeners();
  }

  /// 삭제 = tombstone (MP3). 목록에서 빼지 않고 `deleted` 표식만 남긴다.
  /// 그래야 다른 기기·오프라인 기기에도 "지워졌다"가 전달된다.
  /// 화면 조회는 [_live]가 걸러 준다.
  ///
  /// 반환값은 **보이는 목록 기준** 위치 (되돌리기용). 없으면 -1.
  int remove(Task t) {
    if (t.deleted || !_tasks.contains(t)) return -1;
    final i = _live.toList().indexOf(t);
    t.deleted = true;
    t.touch();
    notifyListeners();
    return i;
  }

  /// [remove] 되돌리기. [index]는 보이는 목록 기준 위치.
  void restore(int index, Task t) {
    if (_tasks.contains(t)) {
      if (!t.deleted) return; // 이미 보이는 항목 — 중복 방지
      _tasks.remove(t);
    }
    t.deleted = false;
    t.touch();
    _tasks.insert(_rawIndexOfLive(index), t);
    notifyListeners();
  }

  /// 보이는 목록의 [liveIndex]번째 자리에 해당하는 [_tasks] 위치
  int _rawIndexOfLive(int liveIndex) {
    if (liveIndex <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].deleted) continue;
      if (seen == liveIndex) return i;
      seen++;
    }
    return _tasks.length;
  }

  /// 완료 항목 일괄 삭제(tombstone) → 되돌리기용 스냅샷(지우기 전 보이던 목록) 반환
  List<Task> clearDone() {
    final before = _live.toList();
    final now = DateTime.now();
    for (final t in before) {
      if (t.done) {
        t.deleted = true;
        t.touch(now);
      }
    }
    notifyListeners();
    return before;
  }

  /// [clearDone] 되돌리기 — 그때 지운 완료 항목만 되살린다.
  /// (예전처럼 목록 전체를 덮어쓰지 않으므로, 그사이 새로 추가한 할 일이 사라지지 않는다)
  void restoreAll(List<Task> snapshot) {
    final now = DateTime.now();
    for (final t in snapshot) {
      if (!_tasks.contains(t)) _tasks.add(t);
      if (t.done && t.deleted) {
        t.deleted = false;
        t.touch(now);
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- 동기화
  /// 서버(다른 기기)에서 온 태스크 목록 반영 — 항목별 Last-Write-Wins.
  ///
  /// - 처음 보는 id → 추가 (tombstone이어도 기록으로 남김)
  /// - 서버 쪽 `updatedAt`이 더 최신 → 내 항목의 내용을 서버 값으로 바꿈
  /// - 아니면 그대로 (내가 더 최근에 고친 것)
  ///
  /// 객체를 새로 만들지 않고 **기존 객체의 필드를 바꾼다.** 편집 시트 등이
  /// 같은 `Task` 객체를 들고 있으므로, 바꿔치기하면 화면과 데이터가 어긋난다.
  void applyRemote(List<Map<String, Object?>> remote) {
    final byId = {for (final t in _tasks) t.id: t};
    var changed = false;
    for (final j in remote) {
      Task? r;
      try {
        r = Task.fromJson(j);
      } catch (_) {
        r = null;
      }
      if (r == null) continue; // 손상된 문서는 건너뜀
      final mine = byId[r.id];
      if (mine == null) {
        _tasks.insert(0, r);
        byId[r.id] = r;
        changed = true;
      } else if (r.updatedAt.isAfter(mine.updatedAt)) {
        mine
          ..title = r.title
          ..done = r.done
          ..due = r.due
          ..doneAt = r.doneAt
          ..tags = r.tags
          ..deleted = r.deleted
          ..credit = r.credit
          ..updatedAt = r.updatedAt;
        changed = true;
      }
    }
    if (changed) notifyListeners();
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

  /// 그 날의 할 일을 활동 4분류로 묶는다.
  ///
  /// 포함 기준은 '그 날의 일' — 기한이 그 날이거나, 그 날 완료한 일.
  /// 분류는 완료한 일이면 완료 기록에 보존된 것을, 남은 일이면 지금 태그로 판정한다.
  /// (완료 기록이 없는 옛 데이터는 태그로 판정한다)
  Map<ActivityKind, ({int done, int total})> dayActivityStats(DateTime d) {
    final counts = <ActivityKind, ({int done, int total})>{
      for (final a in ActivityKind.values) a: (done: 0, total: 0),
    };
    for (final t in _live) {
      final at = t.credit?.at ?? t.doneAt;
      final doneOnDay = t.done && sameDay(at, d);
      if (!doneOnDay && !sameDay(t.due, d)) continue;
      final activity = t.done && t.credit != null
          ? t.credit!.activity
          : activityFor(t.tags.map((tag) => tag.name));
      final before = counts[activity]!;
      counts[activity] = (
        done: before.done + (t.done ? 1 : 0),
        total: before.total + 1,
      );
    }
    return counts;
  }

  /// 그 날의 할 일을 '태그 그대로' 묶는다 — 사용자에게 보여 줄 통계용.
  /// (캐릭터 동작은 통합 분류인 [dayActivityStats] 를 쓴다)
  ///
  /// 태그가 여러 개면 각 태그에 모두 센다. 그래서 합이 할 일 수보다 클 수 있다.
  /// 태그가 없는 일은 null 칸(미지정)에 들어간다.
  Map<TaskTag?, ({int done, int total})> dayTagStats(DateTime d) {
    final counts = <TaskTag?, ({int done, int total})>{
      for (final tag in TaskTag.values) tag: (done: 0, total: 0),
      null: (done: 0, total: 0),
    };
    void bump(TaskTag? key, bool done) {
      final before = counts[key]!;
      counts[key] = (
        done: before.done + (done ? 1 : 0),
        total: before.total + 1,
      );
    }

    for (final t in _live) {
      final at = t.credit?.at ?? t.doneAt;
      final doneOnDay = t.done && sameDay(at, d);
      if (!doneOnDay && !sameDay(t.due, d)) continue;
      if (t.tags.isEmpty) {
        bump(null, t.done);
      } else {
        for (final tag in t.tags) {
          bump(tag, t.done);
        }
      }
    }
    return counts;
  }

  /// 그 날 끝낸 일을 태그별로 센다 (주간 그래프용).
  Map<TaskTag?, int> tagCreditsOn(DateTime d) {
    final counts = <TaskTag?, int>{
      for (final tag in TaskTag.values) tag: 0,
      null: 0,
    };
    for (final t in creditsBetween(d, addDays(d, 1))) {
      if (t.tags.isEmpty) {
        counts[null] = counts[null]! + 1;
      } else {
        for (final tag in t.tags) {
          counts[tag] = counts[tag]! + 1;
        }
      }
    }
    return counts;
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
  /// 화이트·다크 — 기본은 기기 설정을 따른다 (테마는 캐릭터 배경까지 바꾼다)
  AppTheme theme = AppTheme.system;
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

  void setTheme(AppTheme t) {
    theme = t;
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
    _refreshProgress();
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
    'theme': theme.name,
    'calendarRows': calendarRows,
    'thisWeekRow': thisWeekRow,
    'rateStyle': rateStyle.name,
    'notify': notify,
    'remindDays': remindDays.toList(),
    'notifyTime': '${notifyTime.hour}:${notifyTime.minute}',
    'eclass': eclass,
    'everytime': everytime,
    'overdueDays': overdueDays,
    'dayGoals': {for (final e in dayGoals.entries) e.key: e.value.toJson()},
    'unlockedRewards': unlockedRewards.toList(),
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
    // 'companion'·'companionPicked' 는 캐릭터가 오리 하나가 되면서 더 읽지 않는다.
    final goals = m['dayGoals'];
    if (goals is Map) {
      for (final e in goals.entries) {
        final goal = DailyGoal.fromJson(e.value);
        if (e.key is String &&
            DateTime.tryParse(e.key as String) != null &&
            goal != null) {
          dayGoals[e.key as String] = goal;
        }
      }
    }
    final rewards = m['unlockedRewards'];
    if (rewards is List) unlockedRewards.addAll(rewards.whereType<String>());
    theme = AppTheme.values.firstWhere(
      (e) => e.name == m['theme'],
      orElse: () => AppTheme.system,
    );
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
    // 샘플은 기기마다 같은 id + 아주 오래된 updatedAt으로 만든다.
    // → 두 기기에서 로그인해도 샘플이 두 벌로 늘지 않고,
    //   다른 기기에서 고치거나 지운 샘플이 되살아나지 않는다 (LWW에서 항상 짐).
    var n = 0;
    Task mk(
      String title,
      int? inDays,
      Set<TaskTag> tags, {
      bool done = false,
    }) => Task(
      id: 'sample-${++n}',
      title: title,
      due: inDays == null ? null : addDays(today, inDays),
      tags: tags,
      done: done,
      updatedAt: DateTime(2000),
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
