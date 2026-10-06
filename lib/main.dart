import 'package:flutter/material.dart';

import 'data/post_store.dart';
import 'data/user_store.dart';
import 'pages/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LostAndFoundApp());
}

/// 应用根组件：统一的 Material 3 主题 + 三大主界面外壳。
///
/// 两个仓库（信息 [PostStore]、账户 [UserStore]）都在根组件里创建一次并下发，
/// 三个主界面共用同一份数据；换成 SQLite 仓储时，只需替换这里创建的实例。
class LostAndFoundApp extends StatefulWidget {
  const LostAndFoundApp({super.key});

  @override
  State<LostAndFoundApp> createState() => _LostAndFoundAppState();
}

class _LostAndFoundAppState extends State<LostAndFoundApp> {
  final PostStore _postStore = PostStore();
  final UserStore _userStore = UserStore();

  @override
  void dispose() {
    _postStore.dispose();
    _userStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PostScope(
      store: _postStore,
      child: UserScope(
        store: _userStore,
        child: MaterialApp(
          title: '校园失物招领',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const MainShell(),
        ),
      ),
    );
  }
}
