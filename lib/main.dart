import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;

import 'package:sqflite/sqflite.dart';

import 'data/app_database.dart';
import 'data/item_repository.dart';
import 'data/photo_store.dart';
import 'data/post_store.dart';
import 'data/search_history_repository.dart';
import 'data/search_history_store.dart';
import 'data/settings_repository.dart';
import 'data/settings_store.dart';
import 'data/user_repository.dart';
import 'data/user_store.dart';
import 'pages/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // 开本地库要走平台通道，先把绑定初始化好。
  WidgetsFlutterBinding.ensureInitialized();

  // 本地 SQLite：库文件不存在时会建表并写入示例数据（见 AppDatabase）。
  final AppDatabase database = await AppDatabase.open();
  // 图片放在库文件旁边的 `photos/`：两者同生共死，清数据时一起被清掉。
  final PhotoStore photoStore = await PhotoStore.open(
    p.join(await databaseFactory.getDatabasesPath(), 'photos'),
  );

  // 启动时的两件图片杂务，顺序不能反：
  // 1. 先把库里遗留的绝对路径搬进私有目录、改写成文件名（迁移）；
  // 2. 再删掉没有任何信息引用的图片（清理）。
  // 反过来会把刚搬进来、还没被引用上的文件当成垃圾删掉。
  await PhotoStore.applyPendingUpdates(photoStore.files, database.database);
  await photoStore.reconcile(
    await PhotoStore.referencedFilenames(database.database),
  );

  final PostStore postStore = PostStore(
    repository: SqliteItemRepository(database.database),
  );
  final UserStore userStore = UserStore(
    repository: SqliteUserRepository(database.database),
  );
  final SettingsStore settingsStore = SettingsStore(
    repository: SqliteSettingsRepository(database.database),
  );
  final SearchHistoryStore searchHistoryStore = SearchHistoryStore(
    repository: SqliteSearchHistoryRepository(database.database),
  );

  // 先把库里的内容读进内存：首帧就是完整列表，不会先闪一下空列表；
  // 设置也要在这一步读回，否则会先按默认主题画一帧再跳到用户选的主题；
  // 搜索记录同理，否则搜索界面会先闪一下「最近搜索」区块再把它画出来。
  await postStore.load();
  await userStore.load();
  await settingsStore.load();
  await searchHistoryStore.load();

  runApp(
    LostAndFoundApp(
      postStore: postStore,
      userStore: userStore,
      settingsStore: settingsStore,
      photoStore: photoStore,
      searchHistoryStore: searchHistoryStore,
    ),
  );
}

/// 应用根组件：统一的 Material 3 主题 + 三大主界面外壳。
///
/// 几个仓库（信息 [PostStore]、账户 [UserStore]、设置 [SettingsStore]、
/// 图片 [PhotoStore]、搜索记录 [SearchHistoryStore]）在根组件里只下发一次，
/// 所有界面共用同一份数据。传进来的那几个由 `main()` 创建、连着本地 SQLite；
/// 一个都不传时退回内存实现 + 示例数据，测试与预览走这条——那种情况下没有图片
/// 目录，[PhotoStore] 为 `null`，界面按「没有图片」显示。
class LostAndFoundApp extends StatefulWidget {
  const LostAndFoundApp({
    super.key,
    this.postStore,
    this.userStore,
    this.settingsStore,
    this.photoStore,
    this.searchHistoryStore,
  });

  /// 信息仓库；`null` 表示由本组件自己建一个内存仓库。
  final PostStore? postStore;

  /// 账户仓库；`null` 表示由本组件自己建一个内存仓库。
  final UserStore? userStore;

  /// 设置仓库；`null` 表示由本组件自己建一个内存仓库（外观退回跟随系统）。
  final SettingsStore? settingsStore;

  /// 图片仓库；`null` 表示这次运行没有图片目录（纯内存测试），界面退化成占位图。
  final PhotoStore? photoStore;

  /// 搜索记录仓库；`null` 表示由本组件自己建一个内存仓库（没有历史记录）。
  final SearchHistoryStore? searchHistoryStore;

  @override
  State<LostAndFoundApp> createState() => _LostAndFoundAppState();
}

class _LostAndFoundAppState extends State<LostAndFoundApp> {
  // 外面传进来的仓库归外面管（它们的生命周期比本组件长），
  // 这里只释放自己建的那份，避免把还在用的仓库 dispose 掉。
  late final PostStore _postStore = widget.postStore ?? PostStore();
  late final UserStore _userStore = widget.userStore ?? UserStore();
  late final SettingsStore _settingsStore =
      widget.settingsStore ?? SettingsStore();
  late final SearchHistoryStore _searchHistoryStore =
      widget.searchHistoryStore ?? SearchHistoryStore();

  @override
  void dispose() {
    if (widget.postStore == null) {
      _postStore.dispose();
    }
    if (widget.userStore == null) {
      _userStore.dispose();
    }
    if (widget.settingsStore == null) {
      _settingsStore.dispose();
    }
    if (widget.searchHistoryStore == null) {
      _searchHistoryStore.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PostScope(
      store: _postStore,
      child: UserScope(
        store: _userStore,
        child: SettingsScope(
          store: _settingsStore,
          child: PhotoScope(
            store: widget.photoStore,
            child: SearchHistoryScope(
              store: _searchHistoryStore,
              // 主题模式是 MaterialApp 身上的一个参数，设置一变就得重建它，
              // 所以这里显式订阅设置仓库（而不是只靠 SettingsScope 的重建）。
              child: ListenableBuilder(
                listenable: _settingsStore,
                builder: (BuildContext context, Widget? child) => MaterialApp(
                  title: '速拾失',
                  debugShowCheckedModeBanner: false,
                  // 中文化系统级控件（日期/时间选择器、文本选择菜单、返回键 tooltip 等）。
                  // 应用文案本就是中文，直接固定中文 locale，不跟随系统语言。
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  supportedLocales: const <Locale>[Locale('zh')],
                  locale: const Locale('zh'),
                  // 明 / 暗两套配色都由用户挑的那颗种子色派生（默认品牌青）。

                  theme: AppTheme.light(seed: _settingsStore.themeSeed),
                  darkTheme: AppTheme.dark(seed: _settingsStore.themeSeed),
                  themeMode: _settingsStore.themeMode,
                  home: const MainShell(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
