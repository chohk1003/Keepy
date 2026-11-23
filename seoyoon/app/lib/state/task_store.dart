import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../data/repositories.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../models/task_status.dart' as rules show isDelayed, statusOf;

/// 태그 하나의 오늘 통계 (v0.7).
class TagStat {
  const TagStat({required this.tag, required this.total, required this.done, this.untagged = false});

  /// 화면에 보일 이름 ('미지정' 이면 태그 없는 일).
  String get label => untagged ? '미지정' : '#$tag';

  /// 태그 없는 할 일 묶음 (통계에 '미지정' 으로 표시, v0.7).
  final bool untagged;
  final String tag;
  final int total;
  final int done;
}

/// 오늘 통계 패널에 보여 줄 내용 (v0.7).
class TodayTagSummary {
  const TodayTagSummary({
    required this.stats,
    required this.hiddenCount,
    required this.untaggedCount,
    required this.top,
  });

  /// 많은 순 최대 5개
  final List<TagStat> stats;

  /// 5개 밖이라 안 보이는 태그 수
  final int hiddenCount;

  /// 태그 없는 오늘 할 일 수
  final int untaggedCount;

  /// '오늘 가장 많이 한 일' — 완료 수가 가장 많은 태그 (완료가 없으면 개수가 가장 많은 태그)
  final TagStat? top;
}

/// 하루치 통계 (캘린더 칸 색, 완료율).
@immutable
class DayStat {
  const DayStat({required this.total, required this.done});
  final int total;
  final int done;
  double get rate => total == 0 ? 0 : done / total;
}

/// 되돌리기용 삭제 기록.
@immutable
class RemovedTask {
  const RemovedTask(this.task, this.index);
  final Task task;
  final int index;
}

/// 할 일 상태의 단일 출처. 모든 변경은 여기서만 일어나고 곧바로 저장된다.
class TaskStore extends ChangeNotifier {
  TaskStore({
    required TaskRepository repository,
    DateTime Function()? clock,
    int delayDays = 3,
  })  : _repository = repository,
        _clock = clock ?? DateTime.now,
        _delayDays = delayDays;

  final TaskRepository _repository;
  final DateTime Function() _clock;
  final Random _random = Random();

  List<Task> _tasks = <Task>[];
  bool _loaded = false;
  int _delayDays;
  Future<void> _saving = Future<void>.value();

  // ---------------------------------------------------------------- 읽기

  bool get isLoaded => _loaded;
  List<Task> get tasks => List<Task>.unmodifiable(_tasks);
  DateTime now() => _clock();
  DateTime get today => dateOnly(_clock());

  int get delayDays => _delayDays;
  set delayDays(int value) {
    if (value == _delayDays) return;
    _delayDays = value;
    notifyListeners();
  }

  TaskStatus statusOf(Task task) =>
      rules.statusOf(task, now: _clock(), delayDays: _delayDays);

  int get totalCount => _tasks.length;
  int get doneCount => _tasks.where((t) => t.done).length;
  int get openCount => totalCount - doneCount;

  /// 화면 정렬 기준.
  /// 미완료: 지연 → 사용자가 정한 순서(편집 모드에서 끌어서 변경) → 만든 순.
  /// 완료: 최근 완료 순.
  List<Task> sorted(Iterable<Task> source) {
    final open = source.where((t) => !t.done).toList()
      ..sort((a, b) {
        final da = statusOf(a) == TaskStatus.delayed ? 0 : 1;
        final db = statusOf(b) == TaskStatus.delayed ? 0 : 1;
        if (da != db) return da - db;
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) return byOrder;
        return a.createdAt.compareTo(b.createdAt);
      });
    final done = source.where((t) => t.done).toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));
    return <Task>[...open, ...done];
  }

  double get _nextOrder =>
      _tasks.isEmpty ? 0 : _tasks.map((t) => t.order).reduce(max) + 1;

  /// 이번 달 통계: 기한이 이번 달이거나, 기한 없이 이번 달에 만든 할 일 (v0.3, 옛 미니게임 계단).
  /// 전체(미완료·지연 포함)와 완료 수.
  DayStat monthStat(DateTime month) {
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
    final list = _tasks.where((t) => t.due != null ? inMonth(t.due!) : inMonth(t.createdAt));
    return DayStat(total: list.length, done: list.where((t) => t.done).length);
  }

  List<Task> get delayedTasks =>
      sorted(_tasks.where((t) => statusOf(t) == TaskStatus.delayed));
  List<Task> get todoTasks =>
      sorted(_tasks.where((t) => statusOf(t) == TaskStatus.todo));
  List<Task> get doneTasks => sorted(_tasks.where((t) => t.done));

  List<Task> tasksOn(DateTime day) =>
      sorted(_tasks.where((t) => t.due != null && isSameDay(t.due!, day)));

  DayStat statOn(DateTime day) {
    final list = _tasks.where((t) => t.due != null && isSameDay(t.due!, day));
    return DayStat(total: list.length, done: list.where((t) => t.done).length);
  }

  /// 오늘의 할 일 (v0.7 수영장 · 오늘 통계 공통 기준).
  /// - 완료한 일: **완료한 날** 기준. 어제가 기한이던 일(지연)이나 기한 없는 일도 오늘 끝냈으면 오늘의 일.
  /// - 아직 안 끝낸 일: 오늘이 기한인 일 + 기한 없이 오늘 만든 일.
  List<Task> get todayTasks {
    final day = today;
    return sorted(_tasks.where((t) {
      if (t.done) {
        final completed = t.completedAt;
        return completed != null && isSameDay(completed, day);
      }
      final due = t.due;
      return due != null ? isSameDay(due, day) : isSameDay(t.createdAt, day);
    }));
  }

  /// 오늘의 완료율 (오리 수영장 물 높이).
  DayStat get todayStat {
    final list = todayTasks;
    return DayStat(total: list.length, done: list.where((t) => t.done).length);
  }

  /// 오늘의 태그별 통계 — 개수 많은 순(같으면 완료 많은 순, 같으면 태그 목록 순)으로 최대 [limit] 개.
  /// 사용자가 만든 태그를 포함해 할 일에 붙은 모든 태그를 센다.
  TodayTagSummary todayTagStats({List<String> tagOrder = const <String>[], int limit = 5}) {
    final byTag = <String, TagStat>{};
    var untagged = 0;
    var untaggedDone = 0;
    for (final t in todayTasks) {
      if (t.tags.isEmpty) {
        untagged++;
        if (t.done) untaggedDone++;
      }
      for (final tag in t.tags.toSet()) {
        final prev = byTag[tag] ?? TagStat(tag: tag, total: 0, done: 0);
        byTag[tag] = TagStat(tag: tag, total: prev.total + 1, done: prev.done + (t.done ? 1 : 0));
      }
    }
    // 태그 없는 일은 '미지정' 한 묶음으로 함께 순위를 매긴다 (같은 개수면 태그들 뒤).
    int orderOf(TagStat e) {
      if (e.untagged) return tagOrder.length + 1;
      final i = tagOrder.indexOf(e.tag);
      return i < 0 ? tagOrder.length : i;
    }

    final all = <TagStat>[
      ...byTag.values,
      if (untagged > 0) TagStat(tag: '', total: untagged, done: untaggedDone, untagged: true),
    ]
      ..sort((a, b) {
        final byTotal = b.total.compareTo(a.total);
        if (byTotal != 0) return byTotal;
        final byDone = b.done.compareTo(a.done);
        if (byDone != 0) return byDone;
        final byOrder = orderOf(a).compareTo(orderOf(b));
        return byOrder != 0 ? byOrder : a.tag.compareTo(b.tag);
      });
    TagStat? top;
    for (final e in all) {
      if (top == null || e.done > top.done) top = e;
    }
    return TodayTagSummary(
      stats: all.take(limit).toList(),
      hiddenCount: all.length > limit ? all.length - limit : 0,
      untaggedCount: untagged,
      top: top,
    );
  }

  /// 기한이 지정된 날짜들 (오름차순, 중복 없음).
  List<DateTime> get datesWithTasks {
    final keys = <String, DateTime>{};
    for (final t in _tasks) {
      final d = t.due;
      if (d != null) keys[toDateKey(d)] = dateOnly(d);
    }
    final list = keys.values.toList()..sort();
    return list;
  }

  /// [from] 기준 이전(-1)·다음(+1)으로 할 일이 있는 가장 가까운 날 (prompts_log #7).
  DateTime? adjacentTaskDate(DateTime from, int direction) {
    final dates = datesWithTasks;
    if (direction < 0) {
      for (final d in dates.reversed) {
        if (daysBetween(d, from) > 0) return d;
      }
    } else {
      for (final d in dates) {
        if (daysBetween(from, d) > 0) return d;
      }
    }
    return null;
  }

  /// 오늘 요약 카드 (v0.5): 오늘이 기한인 미완료 / 지연 / 오늘 완료한 수.
  int get dueTodayOpenCount =>
      _tasks.where((t) => !t.done && t.due != null && isSameDay(t.due!, today)).length;
  int get delayedCount => _tasks.where((t) => statusOf(t) == TaskStatus.delayed).length;
  int get doneTodayCount =>
      _tasks.where((t) => t.done && t.completedAt != null && isSameDay(t.completedAt!, today)).length;

  /// 최근 완료 기록 (설정 화면의 완료 이벤트 내역).
  List<Task> recentCompletions({int limit = 8}) {
    final list = _tasks.where((t) => t.done && t.completedAt != null).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return list.take(limit).toList();
  }

  Task? byId(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------- 쓰기

  Future<void> load() async {
    _tasks = await _repository.loadTasks();
    _loaded = true;
    notifyListeners();
  }

  /// 새 할 일. 제목이 규칙(CST-03)에 맞지 않으면 null.
  Task? add(String rawTitle, {DateTime? due, List<String> tags = const <String>[]}) {
    if (!TitleRule.isValid(rawTitle)) return null;
    final now = _clock();
    final task = Task(
      id: _newId(now),
      title: TitleRule.normalize(rawTitle),
      createdAt: now,
      due: due == null ? null : dateOnly(due),
      tags: List<String>.unmodifiable(tags),
      updatedAt: now,
      order: _nextOrder,
    );
    _tasks = <Task>[..._tasks, task];
    _commit();
    return task;
  }

  /// 여러 개를 한 번에 (OCR 검토 화면의 '선택한 N개 추가').
  List<Task> addAll(Iterable<String> titles, {DateTime? due}) {
    final added = <Task>[];
    final now = _clock();
    final base = _nextOrder;
    var i = 0;
    for (final raw in titles) {
      if (!TitleRule.isValid(raw)) continue;
      added.add(Task(
        id: _newId(now.add(Duration(microseconds: i))),
        title: TitleRule.normalize(raw),
        createdAt: now,
        due: due == null ? null : dateOnly(due),
        updatedAt: now,
        order: base + i,
      ));
      i++;
    }
    if (added.isEmpty) return added;
    _tasks = <Task>[..._tasks, ...added];
    _commit();
    return added;
  }

  /// 완료 ↔ 미완료 (FR-03). 지연 중에 완료하면 '늦은 완료'로 남긴다.
  void toggle(String id) {
    final now = _clock();
    _replace(id, (t) {
      if (t.done) {
        return t.copyWith(done: false, clearCompletedAt: true, completedLate: false, updatedAt: now);
      }
      final wasDelayed = rules.isDelayed(t, now: now, delayDays: _delayDays);
      return t.copyWith(done: true, completedAt: now, completedLate: wasDelayed, updatedAt: now);
    });
  }

  /// 제목·태그·기한 수정 (FR-04). 제목이 규칙에 맞지 않으면 false.
  bool update(String id, {String? title, List<String>? tags, DateTime? due, bool clearDue = false}) {
    if (title != null && !TitleRule.isValid(title)) return false;
    final now = _clock();
    _replace(
      id,
      (t) => t.copyWith(
        title: title == null ? null : TitleRule.normalize(title),
        tags: tags == null ? null : List<String>.unmodifiable(tags),
        due: due == null ? null : dateOnly(due),
        clearDue: clearDue,
        updatedAt: now,
      ),
    );
    return true;
  }

  void setDue(String id, DateTime? due) =>
      update(id, due: due, clearDue: due == null);

  void setTags(String id, List<String> tags) => update(id, tags: tags);

  /// 삭제 (FR-04). 되돌리기용 기록을 돌려준다.
  RemovedTask? remove(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return null;
    final removed = RemovedTask(_tasks[index], index);
    _tasks = <Task>[..._tasks]..removeAt(index);
    _commit();
    return removed;
  }

  void restore(RemovedTask removed) {
    if (byId(removed.task.id) != null) return;
    final list = <Task>[..._tasks];
    list.insert(min(removed.index, list.length), removed.task);
    _tasks = list;
    _commit();
  }

  /// 되돌리기용: 특정 시점의 할 일 값으로 덮어쓴다.
  void put(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) {
      _tasks = <Task>[..._tasks, task];
    } else {
      _tasks = <Task>[..._tasks]..[index] = task;
    }
    _commit();
  }

  /// 편집 모드에서 끌어서 순서 바꾸기 (v0.3).
  ///
  /// [ids] 는 한 구역(지연 / 해야 할 일 / 완료)에 보이는 순서 그대로의 id 목록.
  /// 그 구역이 쓰던 순서 값들을 새 순서대로 다시 나눠 주므로 다른 구역은 영향이 없다.
  void reorder(List<String> ids, int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1; // ReorderableList 규칙
    target = target.clamp(0, ids.length - 1);
    if (target == oldIndex) return;
    final moved = List<String>.of(ids);
    final id = moved.removeAt(oldIndex);
    moved.insert(target, id);
    final slots = <double>[
      for (final i in ids) byId(i)?.order ?? 0,
    ]..sort();
    // 같은 값이 있으면 구분되도록 살짝 벌린다
    for (var k = 1; k < slots.length; k++) {
      if (slots[k] <= slots[k - 1]) slots[k] = slots[k - 1] + 0.001;
    }
    final orderOf = <String, double>{for (var k = 0; k < moved.length; k++) moved[k]: slots[k]};
    _tasks = <Task>[
      for (final t in _tasks) orderOf.containsKey(t.id) ? t.copyWith(order: orderOf[t.id]) : t,
    ];
    _commit();
  }

  /// 태그 이름이 바뀌면 그 태그를 단 할 일도 함께 바꾼다 (v0.3 태그 관리).
  void renameTag(String from, String to) {
    if (from == to) return;
    var changed = false;
    final next = <Task>[];
    for (final t in _tasks) {
      if (t.tags.contains(from)) {
        changed = true;
        final tags = <String>[];
        for (final g in t.tags) {
          final name = g == from ? to : g;
          if (!tags.contains(name)) tags.add(name);
        }
        next.add(t.copyWith(tags: tags));
      } else {
        next.add(t);
      }
    }
    if (!changed) return;
    _tasks = next;
    _commit();
  }

  /// 태그를 지우면 할 일에서도 떼어 낸다. 떼어 낸 할 일 수를 돌려준다.
  int removeTag(String tag) {
    var count = 0;
    final next = <Task>[];
    for (final t in _tasks) {
      if (t.tags.contains(tag)) {
        count++;
        next.add(t.copyWith(tags: t.tags.where((g) => g != tag).toList()));
      } else {
        next.add(t);
      }
    }
    if (count == 0) return 0;
    _tasks = next;
    _commit();
    return count;
  }

  int countWithTag(String tag) => _tasks.where((t) => t.tags.contains(tag)).length;

  /// 완료한 일 모두 지우기 (v0.5). 되돌리기용 기록을 돌려준다.
  List<RemovedTask> removeDone() {
    final removed = <RemovedTask>[];
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].done) removed.add(RemovedTask(_tasks[i], i));
    }
    if (removed.isEmpty) return removed;
    _tasks = _tasks.where((t) => !t.done).toList();
    _commit();
    return removed;
  }

  /// [removeDone] 되돌리기: 원래 자리에 다시 넣는다.
  void restoreAll(List<RemovedTask> removed) {
    final list = <Task>[..._tasks];
    for (final r in removed) {
      if (list.any((t) => t.id == r.task.id)) continue;
      list.insert(min(r.index, list.length), r.task);
    }
    _tasks = list;
    _commit();
  }

  void clearAll() {
    _tasks = <Task>[];
    _commit();
  }

  /// 서버에서 받은 변경을 한 번에 반영 (MP3 동기화 전용).
  ///
  /// [upserts] 는 넣거나 바꿀 할 일, [deletes] 는 다른 기기에서 지운 할 일 id.
  /// 화면·저장은 다른 변경과 똑같이 갱신된다. 어떤 변경이 서버에서 왔는지는
  /// 동기화 쪽(SyncController)이 기억하므로 다시 서버로 올라가지 않는다.
  void applyRemote({List<Task> upserts = const <Task>[], Set<String> deletes = const <String>{}}) {
    if (upserts.isEmpty && deletes.isEmpty) return;
    final list = <Task>[
      for (final t in _tasks)
        if (!deletes.contains(t.id)) t,
    ];
    for (final u in upserts) {
      final index = list.indexWhere((t) => t.id == u.id);
      if (index < 0) {
        list.add(u);
      } else {
        list[index] = u;
      }
    }
    _tasks = list;
    _commit();
  }

  /// 시연용 샘플 (설정 > 데이터).
  void addSamples() {
    final t = today;
    final samples = <(String, int?, List<String>, bool)>[
      ('모바일 앱 UI 시안 정리', 0, <String>['과제'], false),
      ('자료구조 3주차 과제 제출', 2, <String>['과제'], false),
      ('팀 프로젝트 회의 준비', 3, <String>['팀 프로젝트'], false),
      ('알고리즘 강의 복습', 0, <String>['수업'], false),
      ('요구사항 명세서 검토', 0, <String>['팀 프로젝트'], true),
      ('이번 주 시간표 확인', -1, <String>['개인'], true),
      ('운영체제 퀴즈 준비', -2, <String>['수업'], false),
      ('읽고 싶은 책 찾아보기', null, <String>['개인'], false),
    ];
    final now = _clock();
    var i = 0;
    final added = <Task>[];
    for (final (title, offset, tags, done) in samples) {
      final created = now.subtract(Duration(minutes: 30 * (samples.length - i)));
      added.add(Task(
        id: _newId(created.add(Duration(microseconds: i++))),
        title: title,
        createdAt: created,
        due: offset == null ? null : addDays(t, offset),
        tags: tags,
        done: done,
        completedAt: done ? now.subtract(Duration(minutes: 10 * i)) : null,
        updatedAt: now,
        order: _nextOrder + i,
      ));
    }
    _tasks = <Task>[..._tasks, ...added];
    _commit();
  }

  // ---------------------------------------------------------------- 내부

  void _replace(String id, Task Function(Task) change) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tasks = <Task>[..._tasks]..[index] = change(_tasks[index]);
    _commit();
  }

  void _commit() {
    notifyListeners();
    final snapshot = List<Task>.of(_tasks);
    // 저장은 순서대로 이어 붙여 늦게 끝난 이전 저장이 최신 값을 덮지 않게 한다.
    _saving = _saving.then((_) => _repository.saveTasks(snapshot)).catchError((Object e) {
      debugPrint('Keepy: 저장 실패 ($e)');
    });
  }

  /// 테스트에서 저장 완료를 기다릴 때.
  Future<void> flush() => _saving;

  String _newId(DateTime at) =>
      '${at.microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(0x7fffffff).toRadixString(36)}';
}
