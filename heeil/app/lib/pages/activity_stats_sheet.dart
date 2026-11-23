import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/companion.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import '../widgets/companion_art.dart';

Future<void> showActivityStats(
  BuildContext context,
  AppState state,
  ActivityKind initial,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  sheetAnimationStyle: const AnimationStyle(
    duration: Motion.sheet,
    reverseDuration: Motion.dismiss,
  ),
  backgroundColor: Colors.white,
  builder: (_) => ActivityStatsSheet(state: state, initial: initial),
);

class ActivityStatsSheet extends StatefulWidget {
  const ActivityStatsSheet({
    super.key,
    required this.state,
    required this.initial,
  });
  final AppState state;
  final ActivityKind initial;
  @override
  State<ActivityStatsSheet> createState() => _ActivityStatsSheetState();
}

class _ActivityStatsSheetState extends State<ActivityStatsSheet> {
  late final _pages = PageController(initialPage: widget.initial.index);
  late int _index = widget.initial.index;
  int _days = 7;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .65,
    child: ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  activityIcon(ActivityKind.values[_index]),
                  color: activityColor(ActivityKind.values[_index]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${activityLabel(ActivityKind.values[_index])} 기록',
                    key: const Key('activity-stats-title'),
                    style: T.title3,
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final n in [7, 30])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('최근 $n일'),
                    selected: _days == n,
                    onSelected: (_) => setState(() => _days = n),
                  ),
                ),
            ],
          ),
          Expanded(
            child: PageView.builder(
              key: const Key('activity-stats-pages'),
              controller: _pages,
              physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
              itemCount: ActivityKind.values.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _content(ActivityKind.values[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final a in ActivityKind.values)
                  IconButton(
                    tooltip: activityLabel(a),
                    onPressed: () => _pages.animateToPage(
                      a.index,
                      duration: Motion.navigation,
                      curve: Curves.easeOutCubic,
                    ),
                    icon: Icon(
                      activityIcon(a),
                      color: a.index == _index ? activityColor(a) : K.gray3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _content(ActivityKind a) {
    final state = widget.state, now = widget.state.now;
    final end = addDays(dayOf(now), 1), start = addDays(dayOf(now), 1 - _days);
    final tasks =
        state
            .creditsBetween(start, end)
            .where((t) => t.credit!.activity == a)
            .toList()
          ..sort((a, b) => b.credit!.at.compareTo(a.credit!.at));
    final counts = List.generate(
      _days,
      (i) =>
          tasks.where((t) => sameDay(t.credit!.at, addDays(start, i))).length,
    );
    final maximum = counts.fold(1, math.max);
    final previous = state
        .creditsBetween(addDays(start, -_days), start)
        .where((t) => t.credit!.activity == a)
        .length;
    final delta = tasks.length - previous;
    return ListView(
      key: ValueKey('stats-${a.name}'),
      padding: const EdgeInsets.all(22),
      children: [
        Text('${tasks.length}개 완료', style: T.title2),
        const SizedBox(height: 6),
        Text('이전 $_days일보다 ${delta >= 0 ? '+' : ''}$delta개', style: T.footnote),
        const SizedBox(height: 18),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < counts.length; i++)
                Expanded(
                  child: Tooltip(
                    message: '${dayKey(addDays(start, i))} · ${counts[i]}개',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        height: 4 + counts[i] / maximum * 84,
                        decoration: BoxDecoration(
                          color: counts[i] == 0 ? K.fill : activityColor(a),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(mdw(start), style: T.caption),
            Text('오늘', style: T.caption),
          ],
        ),
        const SizedBox(height: 18),
        if (tasks.isEmpty) Text('아직 이 활동의 완료 기록이 없어요.', style: T.footnote),
        for (final t in tasks.take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text(mdw(t.credit!.at), style: T.caption),
          ),
      ],
    );
  }
}
