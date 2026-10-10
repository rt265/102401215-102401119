import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 主界面外壳的标签按钮。
///
/// 外壳按可用宽度换摆法（见 `AppLayout.navigationRailBreakpoint`）：窄屏在底部
/// [NavigationBar] 里，宽屏在左侧 [NavigationRail] 里。测试要点的还是同一个标签，
/// 不该关心这一刻是哪一种摆法，所以两种栏一起找。
///
/// 窄屏是 800×600 的默认视口测不到的（800 ≥ 断点 600，走的是侧边栏），
/// 所以**别**再写死 `find.byType(NavigationBar)`：那样只有把视口调窄才通过。
Finder mainTab(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (Widget widget) => widget is NavigationBar || widget is NavigationRail,
  ),
  matching: find.text(label),
);
