import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'basics.dart';

/// 하단 탭 바 [설정] - [메인] - [날짜] (UI 설계서 04-2).
/// iOS 처럼 반투명 흐림 배경 위에, 선택된 탭만 그라데이션.
class KeepyTabBar extends StatelessWidget {
  const KeepyTabBar({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, IconData, String)>[
    (CupertinoIcons.slider_horizontal_3, CupertinoIcons.slider_horizontal_3, '설정'),
    (CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill, '메인'),
    (CupertinoIcons.calendar, CupertinoIcons.calendar, '날짜'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(bottom: bottom > 0 ? bottom - 6 : 4, top: 6),
          decoration: BoxDecoration(
            color: KeepyColors.bar,
            border: Border(top: BorderSide(color: KeepyColors.separator, width: 0.5)),
          ),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    key: Key('tab-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: SizedBox(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          AnimatedScale(
                            scale: i == index ? 1.08 : 1,
                            duration: KeepyMotion.fast,
                            curve: KeepyMotion.settle,
                            child: i == index
                                ? GradientIcon(_items[i].$2, size: 24)
                                : Icon(_items[i].$1, size: 24, color: KeepyColors.secondaryLabel),
                          ),
                          const SizedBox(height: 3),
                          i == index
                              ? GradientText(
                                  _items[i].$3,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
                                )
                              : Text(
                                  _items[i].$3,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: KeepyColors.secondaryLabel,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
