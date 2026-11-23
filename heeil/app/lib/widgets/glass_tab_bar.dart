import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'fx.dart';

class TabSpec {
  const TabSpec(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 유리 탭 바 — 페이지 스와이프를 그대로 따라오는 그라데이션 알약
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.controller,
    required this.index,
    required this.tabs,
    required this.onTap,
  });

  final PageController controller;
  final int index;
  final List<TabSpec> tabs;
  final ValueChanged<int> onTap;

  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Glass(
      opacity: 0.8,
      border: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: K.separator, width: 0.5)),
        ),
        padding: EdgeInsets.only(bottom: bottom),
        height: height + bottom,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth / tabs.length;
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final page =
                    controller.hasClients && controller.position.haveDimensions
                    ? controller.page ?? index.toDouble()
                    : index.toDouble();
                return Stack(
                  children: [
                    Positioned(
                      left: page * w + (w - 58) / 2,
                      top: 9,
                      width: 58,
                      height: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: K.duck,
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _Item(
                              spec: tabs[i],
                              t: (1 - (page - i).abs()).clamp(0.0, 1.0),
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.spec, required this.t, required this.onTap});

  final TabSpec spec;
  final double t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = t > 0.5;
    // 탭은 태그 색을 쓰지 않는다 — 같은 색은 어디서나 같은 태그를 뜻해야 하므로.
    // 고른 탭만 강조색, 나머지는 보조 글자색.
    final color = Color.lerp(K.label2, K.blue, t)!;
    return Semantics(
      label: spec.label,
      button: true,
      selected: active,
      child: Tooltip(
        message: spec.label,
        child: Pressable(
          onTap: onTap,
          scale: .88,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Icon(
                active ? spec.activeIcon : spec.icon,
                size: active ? 25 : 23,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 탭 아이콘 모음
const keepyTabs = [
  TabSpec(CupertinoIcons.gear_alt, CupertinoIcons.gear_alt_fill, '설정'),
  TabSpec(
    CupertinoIcons.checkmark_square,
    CupertinoIcons.checkmark_square_fill,
    '메인',
  ),
  TabSpec(CupertinoIcons.calendar, CupertinoIcons.calendar_today, '날짜'),
];
