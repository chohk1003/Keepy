import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/companion.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/companion_art.dart';

/// Detailed text belongs here, not in the work screen or the character room.
class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key, required this.state});
  final AppState state;
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  bool _month = false;
  int _offset = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(key: Key('progress-back')),
      title: const Text('기록과 보상'),
      backgroundColor: Colors.white,
    ),
    body: ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final now = dayOf(state.now);
        final start = _month
            ? DateTime(now.year, now.month + _offset)
            : addDays(now, 1 - now.weekday + 7 * _offset);
        final end = _month
            ? DateTime(start.year, start.month + 1)
            : addDays(start, 7);
        final days = <DateTime>[];
        for (var d = start; d.isBefore(end); d = addDays(d, 1)) {
          days.add(d);
        }
        final counts = [
          for (final d in days) state.creditsBetween(d, addDays(d, 1)).length,
        ];
        final total = counts.fold(0, (a, b) => a + b);
        final goals = [
          for (final d in days)
            if (!d.isAfter(now))
              state.dayGoals[dayKey(d)] ??
                  const DailyGoal(planned: 0, completed: 0),
        ];
        final achieved = goals.where((g) => g.achieved).length;
        final planned = goals.fold(0, (a, b) => a + b.planned);
        final completed = goals.fold(0, (a, b) => a + b.completed);
        final previousStart = _month
            ? DateTime(start.year, start.month - 1)
            : addDays(start, -7);
        // Compare equal elapsed portions, not an unfinished week to a full week.
        final elapsed = days.where((d) => !d.isAfter(now)).length;
        final previousEndCandidate = addDays(previousStart, elapsed);
        final previousEnd = previousEndCandidate.isAfter(start)
            ? start
            : previousEndCandidate;
        final previous = state
            .creditsBetween(previousStart, previousEnd)
            .length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            CupertinoSlidingSegmentedControl<bool>(
              groupValue: _month,
              children: const {
                false: Padding(padding: EdgeInsets.all(9), child: Text('주간')),
                true: Padding(padding: EdgeInsets.all(9), child: Text('월간')),
              },
              onValueChanged: (value) {
                if (value != null) {
                  setState(() {
                    _month = value;
                    _offset = 0;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton(
                  tooltip: '이전 기간',
                  onPressed: () => setState(() => _offset--),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _month
                        ? '${start.year}년 ${start.month}월'
                        : '${mdw(start)} – ${mdw(addDays(end, -1))}',
                    textAlign: TextAlign.center,
                    style: T.headline,
                  ),
                ),
                IconButton(
                  tooltip: '다음 기간',
                  onPressed: _offset < 0
                      ? () => setState(() => _offset++)
                      : null,
                  icon: const Icon(CupertinoIcons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 22,
              runSpacing: 14,
              children: [
                _Metric('완료한 일', '$total'),
                _Metric('계획 달성일', '$achieved일'),
                _Metric(
                  '예정한 일 달성률',
                  planned == 0
                      ? '—'
                      : '${(completed / planned * 100).round()}%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '이전 기간 같은 경과일보다 ${total - previous >= 0 ? '+' : ''}${total - previous}개',
              style: T.footnote,
            ),
            const SizedBox(height: 22),
            if (_month)
              _MonthGrid(days: days, counts: counts, goals: state.dayGoals)
            else
              _WeekBars(days: days, counts: counts),
            const SizedBox(height: 24),
            ...state
                .activityCounts(start, end)
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          activityIcon(entry.key),
                          size: 18,
                          color: activityColor(entry.key),
                        ),
                        const SizedBox(width: 9),
                        SizedBox(
                          width: 46,
                          child: Text(
                            activityLabel(entry.key),
                            style: T.footnote,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : entry.value / total,
                              minHeight: 7,
                              color: activityColor(entry.key),
                              backgroundColor: K.fill,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 33,
                          child: Text(
                            '${entry.value}',
                            textAlign: TextAlign.right,
                            style: T.footnote,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const Divider(height: 38),
            Wrap(
              spacing: 30,
              runSpacing: 12,
              children: [
                _Metric('이어온 기록', '${state.currentStreak}일'),
                _Metric('최장 기록', '${state.longestStreak}일'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '예정한 일을 모두 끝낸 날을 셉니다. 일정 없는 날은 쉬고, 늦은 완료는 완료한 날짜에 남아요.',
              style: T.footnote,
            ),
            const SizedBox(height: 26),
            Text('모은 보상', style: T.headline),
            const SizedBox(height: 12),
            ...companionRewards.map((reward) {
              final unlocked = state.unlockedRewards.contains(reward.id);
              final progress = reward.streak
                  ? state.longestStreak
                  : state.creditedTasks.length;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  unlocked ? CupertinoIcons.rosette : CupertinoIcons.lock,
                  color: unlocked ? K.blue : K.label3,
                ),
                title: Text(reward.label, style: T.body),
                subtitle: Text(
                  '${reward.streak ? '연속 달성' : '누적 완료'} ${reward.target}${reward.streak ? '일' : '개'}',
                  style: T.footnote,
                ),
                trailing: Text(
                  unlocked
                      ? '획득'
                      : '${math.min(progress, reward.target)}/${reward.target}',
                  style: T.footnote,
                ),
              );
            }),
          ],
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: T.footnote),
      const SizedBox(height: 5),
      Text(value, style: T.title2),
    ],
  );
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.counts});
  final List<DateTime> days;
  final List<int> counts;
  @override
  Widget build(BuildContext context) {
    final max = counts.fold(1, (a, b) => math.max(a, b));
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Semantics(
                label: '${dayKey(days[i])} 완료 ${counts[i]}개',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${counts[i]}', style: T.caption),
                      const SizedBox(height: 6),
                      Container(
                        height: 4 + counts[i] / max * 98,
                        decoration: BoxDecoration(
                          color: counts[i] == 0 ? K.fill : K.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text('월화수목금토일'[i], style: T.footnote),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.counts,
    required this.goals,
  });
  final List<DateTime> days;
  final List<int> counts;
  final Map<String, DailyGoal> goals;
  @override
  Widget build(BuildContext context) {
    final offset = days.first.weekday - 1;
    return Column(
      children: [
        Row(
          children: [
            for (final label in '월화수목금토일'.split(''))
              Expanded(
                child: Center(child: Text(label, style: T.caption)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
          ),
          itemCount: offset + days.length,
          itemBuilder: (_, i) {
            if (i < offset) return const SizedBox.shrink();
            final index = i - offset, day = days[index];
            final goal = goals[dayKey(day)];
            return Tooltip(
              message:
                  '${dayKey(day)} · 완료 ${counts[index]}개${goal?.achieved == true ? ' · 계획 달성' : ''}',
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: goal?.achieved == true
                      ? K.blue
                      : counts[index] > 0
                      ? K.room
                      : K.fill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${day.day}',
                  style: T.footnote.copyWith(
                    color: goal?.achieved == true ? Colors.white : K.ink,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
