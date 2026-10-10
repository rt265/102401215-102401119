import 'package:flutter/material.dart';

import '../theme/app_layout.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'publish_page.dart';

/// 一个主界面标签：[MainShell] 的底部栏与侧边栏共用同一份。
class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 三个标签的顺序就是各界面在 `IndexedStack` 里的下标：首页 0、发布 1、我的 2。
const List<_Tab> _tabs = <_Tab>[
  _Tab('首页', Icons.home_outlined, Icons.home_rounded),
  _Tab('发布', Icons.add_circle_outline, Icons.add_circle_rounded),
  _Tab('我的', Icons.person_outline_rounded, Icons.person_rounded),
];

/// 三大主界面的外壳：首页 / 发布 / 我的。
///
/// 导航按可用宽度换摆法（见 [AppLayout.navigationRailBreakpoint]）：手机竖屏用底部
/// [NavigationBar]，平板 / 折叠屏展开 / 横屏 / iPad 换成左侧 [NavigationRail]。
/// Flutter 对「同一套界面跑在多种尺寸设备上」的常规做法就是如此——宽屏上底部导航栏
/// 会把三个标签拉得极散、还白吃掉一整条高度，侧边栏把这段空间还给了正文。
///
/// 两种摆法的标签、顺序、选中态完全共用 [_tabs]：宽度一变只换外壳，
/// 三个界面本身与其滚动位置 / 输入状态都不动。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 首页在标签中的位置，发布成功后要切回它。
  static const int _homeIndex = 0;

  /// 「发布」标签的位置：「我的」界面里「去发布一条」要切到它。
  static const int _publishIndex = 1;

  int _index = _homeIndex;

  void _goHome() => setState(() => _index = _homeIndex);

  void _goPublish() => setState(() => _index = _publishIndex);

  void _select(int value) => setState(() => _index = value);

  /// 底部导航栏（窄屏）。
  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _select,
      destinations: <NavigationDestination>[
        for (final _Tab tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
      ],
    );
  }

  /// 侧边导航栏（宽屏）。
  ///
  /// 外面套一层 `SafeArea(right: false)`：窄屏时顶部的状态栏由各页自己的 `AppBar`
  /// 让开，换成侧边栏后就轮到这一栏自己让——横屏下左边缘的刘海 / 挖孔同理。
  Widget _buildNavigationRail() {
    return SafeArea(
      right: false,
      child: NavigationRail(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: <NavigationRailDestination>[
          for (final _Tab tab in _tabs)
            NavigationRailDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: Text(tab.label),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 断点判定放在整个 Scaffold 外面：底部栏和侧边栏是 Scaffold 的两个不同槽位，
    // 得先量出这一帧的可用宽度，才能决定该给哪个。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide =
            constraints.maxWidth >= AppLayout.navigationRailBreakpoint;

        // IndexedStack 让三个界面各自保留滚动位置与输入状态——换导航摆法时也一样。
        final Widget content = IndexedStack(
          index: _index,
          children: <Widget>[
            HomePage(onGoHome: _goHome),
            // 发布成功弹窗里的「去首页看看」由外壳负责切换标签。
            PublishPage(onGoHome: _goHome),
            // 「我的」界面里没有发布入口，用「去发布一条」切到发布标签；
            // 详细信息界面（从「我的发布」点进去）的「回到首页」也回到这里。
            ProfilePage(onGoPublish: _goPublish, onGoHome: _goHome),
          ],
        );

        return Scaffold(
          body: wide
              ? Row(
                  children: <Widget>[
                    _buildNavigationRail(),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: wide ? null : _buildNavigationBar(),
        );
      },
    );
  }
}
