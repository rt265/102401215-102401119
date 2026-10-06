import 'package:flutter/material.dart';

import 'home_page.dart';
import 'profile_page.dart';
import 'publish_page.dart';

/// 三大主界面的外壳：首页 / 发布 / 我的。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 首页在 [NavigationBar] 中的位置，发布成功后要切回它。
  static const int _homeIndex = 0;

  /// 「发布」标签的位置：「我的」界面里「去发布一条」要切到它。
  static const int _publishIndex = 1;

  int _index = _homeIndex;

  void _goHome() => setState(() => _index = _homeIndex);

  void _goPublish() => setState(() => _index = _publishIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 让三个界面各自保留滚动位置与输入状态。
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          const HomePage(),
          // 发布成功弹窗里的「去首页看看」由外壳负责切换标签。
          PublishPage(onGoHome: _goHome),
          // 「我的」界面里没有发布入口，用「去发布一条」切到发布标签。
          ProfilePage(onGoPublish: _goPublish),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: '发布',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
