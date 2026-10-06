import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

/// 搜索界面（次级界面）。
///
/// 首页顶部的搜索栏会跳到这里。搜索逻辑与结果筛选属于 UI 事项 5，
/// 目前先保留导航入口，保证首页的交互闭环。
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: const ComingSoon(
        icon: Icons.search_rounded,
        title: '搜索界面建设中',
        description: '关键词搜索与结果筛选将在后续 UI 事项中实现。',
      ),
    );
  }
}
