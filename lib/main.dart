import 'package:flutter/material.dart';

import 'pages/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LostAndFoundApp());
}

/// 应用根组件：统一的 Material 3 主题 + 三大主界面外壳。
class LostAndFoundApp extends StatelessWidget {
  const LostAndFoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校园失物招领',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const MainShell(),
    );
  }
}
