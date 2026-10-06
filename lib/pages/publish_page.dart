import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

/// 发布界面（主界面）。
///
/// UI 事项 2 实现表单与校验。
class PublishPage extends StatelessWidget {
  const PublishPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发布信息')),
      body: const ComingSoon(
        icon: Icons.edit_note_rounded,
        title: '发布界面建设中',
        description: '失物 / 招领信息表单与填写校验将在后续 UI 事项中实现。',
      ),
    );
  }
}
