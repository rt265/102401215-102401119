import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

/// 我的界面（主界面）。
///
/// UI 事项 3 实现账户与已发布内容的管理入口。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: const ComingSoon(
        icon: Icons.person_outline_rounded,
        title: '我的界面建设中',
        description: '账户信息与发布内容管理将在后续 UI 事项中实现。',
      ),
    );
  }
}
