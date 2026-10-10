import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lost_and_found/data/app_database.dart';
import 'package:lost_and_found/data/db_schema.dart';
import 'package:lost_and_found/data/item_repository.dart';
import 'package:lost_and_found/data/mock_posts.dart';
import 'package:lost_and_found/data/post_row.dart';
import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/search_history_repository.dart';
import 'package:lost_and_found/data/settings_repository.dart';
import 'package:lost_and_found/data/settings_store.dart';
import 'package:lost_and_found/data/user_repository.dart';
import 'package:lost_and_found/data/user_store.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/models/post_query.dart';
import 'package:lost_and_found/models/user_account.dart';
import 'package:lost_and_found/theme/app_theme.dart';

/// 本地存储的测试。
///
/// 应用里连的是平台自带的 sqflite 插件，测试环境（桌面上的 `flutter test`）
/// 没有这个插件，所以这里统一走 ffi 版：`sqlite3` 直接加载进测试进程，
/// 库文件用内存库，跑起来和真机上的 SQL 行为一致。
///
/// 用例分四块：建库与示例数据、读写、查询（与内存版对拍）、写穿（Store + 仓储）。

/// 示例数据里的相对时间以它为准：钉死时间，断言才不会跟着"跑测试的那一刻"变。
final DateTime seedTime = DateTime(2026, 5, 1, 12);

void main() {
  setUpAll(sqfliteFfiInit);

  group('建库与示例数据', () {
    test('首次打开会建表并写入示例数据', () async {
      final AppDatabase database = await openMemory();
      final List<ItemPost> posts = await SqliteItemRepository(database.database)
          .queryPosts(const PostQuery());

      expect(posts.length, buildMockPosts(now: seedTime).length);
      // 最新发布（示例数据里是两小时前那条一卡通）排在最前。
      expect(posts.first.id, 'p001');
      expect(posts.first.title, '校园一卡通（蓝色卡套）');
    });

    test('示例数据的每个字段都能原样读回来', () async {
      final AppDatabase database = await openMemory();
      final List<ItemPost> posts = await SqliteItemRepository(database.database)
          .queryPosts(const PostQuery());

      final List<ItemPost> expected = buildMockPosts(now: seedTime);
      expect(posts.length, expected.length);
      for (final ItemPost want in expected) {
        expectSamePost(
          posts.firstWhere((ItemPost post) => post.id == want.id),
          want,
        );
      }
    });

    test('重开同一个库不会再写一遍示例数据', () async {
      final String path = p.join(makeTempDir().path, 'lost_and_found.db');

      final AppDatabase first = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      final SqliteItemRepository firstRepository = SqliteItemRepository(
        first.database,
      );
      // 用户删掉一条示例数据……
      await firstRepository.deletePost('p001');
      await first.close();

      // ……重开之后它不该回来，其它示例数据也还在（本地存储确实落了盘）。
      final AppDatabase second = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(second.close);

      final List<ItemPost> posts = await SqliteItemRepository(second.database)
          .queryPosts(const PostQuery());
      expect(posts.map((ItemPost post) => post.id), isNot(contains('p001')));
      expect(posts.length, buildMockPosts(now: seedTime).length - 1);
    });
  });

  group('读写', () {
    test('写入的信息连同每个字段一起落库', () async {
      final AppDatabase database = await openMemory();
      final SqliteItemRepository repository = SqliteItemRepository(
        database.database,
      );
      final ItemPost post = buildRichPost();

      await repository.insertPost(post);

      final ItemPost stored = (await repository.queryPosts(const PostQuery()))
          .firstWhere((ItemPost item) => item.id == post.id);
      expectSamePost(stored, post);
    });

    test('选填字段留空时读回来仍是空的', () async {
      final AppDatabase database = await openMemory();
      final SqliteItemRepository repository = SqliteItemRepository(
        database.database,
      );
      final ItemPost post = buildBarePost();

      await repository.insertPost(post);

      final ItemPost stored = (await repository.queryPosts(const PostQuery()))
          .firstWhere((ItemPost item) => item.id == post.id);
      expect(stored.description, isNull);
      expect(stored.imagePaths, isEmpty);
      expect(stored.status, PostStatus.pending);
      expect(stored.isMine, isFalse);
    });

    test('改动会覆盖原来那一行', () async {
      final AppDatabase database = await openMemory();
      final SqliteItemRepository repository = SqliteItemRepository(
        database.database,
      );
      final ItemPost post = buildBarePost();
      await repository.insertPost(post);

      await repository.updatePost(
        post.copyWith(status: PostStatus.resolved, description: '已经还回去了。'),
      );

      final List<ItemPost> posts = await repository.queryPosts(
        const PostQuery(),
      );
      expect(posts.where((ItemPost item) => item.id == post.id).length, 1);
      final ItemPost stored = posts.firstWhere(
        (ItemPost item) => item.id == post.id,
      );
      expect(stored.status, PostStatus.resolved);
      expect(stored.description, '已经还回去了。');
    });

    test('删掉之后不再出现在查询结果里', () async {
      final AppDatabase database = await openMemory();
      final SqliteItemRepository repository = SqliteItemRepository(
        database.database,
      );
      await repository.insertPost(buildBarePost());

      await repository.deletePost('p002');

      final List<ItemPost> posts = await repository.queryPosts(
        const PostQuery(),
      );
      expect(posts.map((ItemPost post) => post.id), isNot(contains('p002')));
      expect(posts.map((ItemPost post) => post.id), contains('local-3002'));
    });

    test('重开库之后自己写的信息还在', () async {
      final String path = p.join(makeTempDir().path, 'lost_and_found.db');
      final AppDatabase first = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      await SqliteItemRepository(first.database).insertPost(buildRichPost());
      await first.close();

      final AppDatabase second = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(second.close);

      final List<ItemPost> posts = await SqliteItemRepository(second.database)
          .queryPosts(const PostQuery());
      expectSamePost(
        posts.firstWhere((ItemPost post) => post.id == 'local-3001'),
        buildRichPost(),
      );
    });
  });

  group('查询', () {
    test('关键词：命中物品名称 / 地点 / 分类', () async {
      final SqliteItemRepository repository = await seededRepository();

      expect(await idsOf(repository, const PostQuery(keyword: '图书馆')), <String>[
        'p002',
      ]);
      expect(await idsOf(repository, const PostQuery(keyword: '雨伞')), <String>[
        'p002',
      ]);
      expect(await idsOf(repository, const PostQuery(keyword: '食堂')), <String>[
        'p003',
      ]);
      expect(
        await idsOf(repository, const PostQuery(keyword: '电子产品')),
        <String>['p004', 'p009'],
      );
    });

    test('关键词：多个词要全部命中才算命中', () async {
      final SqliteItemRepository repository = await seededRepository();

      expect(
        await idsOf(repository, const PostQuery(keyword: '图书馆 雨伞')),
        <String>['p002'],
      );
      // 「图书馆」和「钥匙」分别命中不同信息，合在一起就该是空结果。
      expect(
        await idsOf(repository, const PostQuery(keyword: '图书馆 钥匙')),
        isEmpty,
      );
      // 多打的空白不算一个词。
      expect(
        await idsOf(repository, const PostQuery(keyword: '  图书馆   雨伞 ')),
        <String>['p002'],
      );
    });

    test('类型 / 分类筛选', () async {
      final SqliteItemRepository repository = await seededRepository();

      expect(
        await idsOf(repository, const PostQuery(type: PostType.lost)),
        <String>['p001', 'p003', 'p004', 'p008', 'p009'],
      );
      expect(
        await idsOf(repository, const PostQuery(category: ItemCategory.card)),
        <String>['p001', 'p008'],
      );
      expect(
        await idsOf(
          repository,
          const PostQuery(type: PostType.lost, category: ItemCategory.digital),
        ),
        <String>['p004', 'p009'],
      );
    });

    test('排序：最新在前 / 最早在前', () async {
      final SqliteItemRepository repository = await seededRepository();

      final List<String> newest = await idsOf(repository, const PostQuery());
      final List<String> oldest = await idsOf(
        repository,
        const PostQuery(sortBy: PostSortBy.oldest),
      );

      expect(newest.first, 'p001');
      expect(newest.last, 'p009');
      expect(oldest, newest.reversed.toList());
    });

    test('SQL 结果与内存版 PostQuery.apply 对得上', () async {
      final SqliteItemRepository repository = await seededRepository();
      final List<ItemPost> inMemory = buildMockPosts(now: seedTime);

      // 每种条件都拿两边跑一遍：改了一边的判定却忘了改另一边，这里就会红。
      final List<(String, PostQuery)> cases = <(String, PostQuery)>[
        ('全部·最新', const PostQuery()),
        ('全部·最早', const PostQuery(sortBy: PostSortBy.oldest)),
        ('关键词·单词', const PostQuery(keyword: '图书馆')),
        ('关键词·多词', const PostQuery(keyword: '图书馆 雨伞')),
        ('关键词·多词落空', const PostQuery(keyword: '图书馆 钥匙')),
        ('关键词·多余空白', const PostQuery(keyword: ' 雨伞  食堂 ')),
        ('关键词·分类名', const PostQuery(keyword: '电子产品')),
        ('关键词·只有空白', const PostQuery(keyword: '   ')),
        ('关键词·大写英文', const PostQuery(keyword: 'A203')),
        ('筛选·类型', const PostQuery(type: PostType.lost)),
        (
          '筛选·类型+排序',
          const PostQuery(type: PostType.found, sortBy: PostSortBy.oldest),
        ),
        ('筛选·分类', const PostQuery(category: ItemCategory.card)),
        (
          '筛选·类型+分类',
          const PostQuery(type: PostType.lost, category: ItemCategory.digital),
        ),
        ('筛选+关键词', const PostQuery(type: PostType.lost, keyword: '手机')),
        // `%` `_` 是 SQL 的通配符，但用户输入里它们只是普通字符：
        // 不转义的话这两个查询会把整个库都捞出来。
        ('关键词·百分号', const PostQuery(keyword: '%')),
        ('关键词·下划线', const PostQuery(keyword: '_')),
        ('关键词·半截通配符', const PostQuery(keyword: '伞%')),
      ];

      for (final (String label, PostQuery query) in cases) {
        expect(
          await idsOf(repository, query),
          query.apply(inMemory).map((ItemPost post) => post.id).toList(),
          reason: '查询「$label」的 SQL 结果与内存版不一致',
        );
      }
    });
  });

  group('账户', () {
    test('保存、覆盖、清空', () async {
      final AppDatabase database = await openMemory();
      final SqliteUserRepository repository = SqliteUserRepository(
        database.database,
      );
      expect(await repository.loadAccount(), isNull);

      await repository.saveAccount(
        UserAccount(
          displayName: '张同学',
          contact: '微信 zhang',
          createdAt: seedTime,
        ),
      );

      UserAccount? stored = await repository.loadAccount();
      expect(stored!.displayName, '张同学');
      expect(stored.contact, '微信 zhang');
      expect(
        stored.createdAt.millisecondsSinceEpoch,
        seedTime.millisecondsSinceEpoch,
      );

      // 改一次账户：只该覆盖那一行，不该攒出第二行。
      await repository.saveAccount(
        UserAccount(displayName: '李同学', contact: '微信 li', createdAt: seedTime),
      );
      stored = await repository.loadAccount();
      expect(stored!.displayName, '李同学');
      final List<Map<String, Object?>> count = await database.database.rawQuery(
        'SELECT COUNT(*) AS total FROM user_account',
      );
      expect(count.first['total'], 1);

      await repository.clearAccount();
      expect(await repository.loadAccount(), isNull);
    });

    test('重开库之后账户还在', () async {
      final String path = p.join(makeTempDir().path, 'lost_and_found.db');
      final AppDatabase first = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      await SqliteUserRepository(first.database).saveAccount(
        UserAccount(
          displayName: '张同学',
          contact: '微信 zhang',
          createdAt: seedTime,
        ),
      );
      await first.close();

      final AppDatabase second = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(second.close);

      final UserAccount? stored = await SqliteUserRepository(second.database)
          .loadAccount();
      expect(stored!.displayName, '张同学');
    });
  });

  group('仓库写穿（Store + 仓储）', () {
    test('PostStore：装载后读到库里的内容，增删改都立刻落库', () async {
      final AppDatabase database = await openMemory();
      final SqliteItemRepository repository = SqliteItemRepository(
        database.database,
      );
      final PostStore store = PostStore(repository: repository);
      addTearDown(store.dispose);

      // 有仓储时内存不塞示例数据，等 load() 从库里读。
      expect(store.posts, isEmpty);
      await store.load();
      expect(store.posts.length, buildMockPosts(now: seedTime).length);
      expect(store.postById('p001'), isNotNull);

      final ItemPost post = buildRichPost();
      final Future<void> adding = store.addPost(post);
      // 内存先改：界面不用等磁盘。
      expect(store.posts.first.id, post.id);
      await adding;
      expect(
        (await repository.queryPosts(const PostQuery()))
            .map((ItemPost item) => item.id),
        contains(post.id),
      );

      await store.updatePost(post.copyWith(status: PostStatus.resolved));
      expect(store.postById(post.id)!.status, PostStatus.resolved);
      expect(
        (await repository.queryPosts(const PostQuery()))
            .firstWhere((ItemPost item) => item.id == post.id)
            .status,
        PostStatus.resolved,
      );

      await store.removePost(post.id);
      expect(store.postById(post.id), isNull);
      expect(
        (await repository.queryPosts(const PostQuery()))
            .map((ItemPost item) => item.id),
        isNot(contains(post.id)),
      );
    });

    test('PostStore：load 会丢掉内存里原有的东西', () async {
      final AppDatabase database = await openMemory();
      final PostStore store = PostStore(
        repository: SqliteItemRepository(database.database),
        initialPosts: <ItemPost>[buildRichPost()],
      );
      addTearDown(store.dispose);

      await store.load();

      expect(store.postById('local-3001'), isNull);
      expect(store.posts.length, buildMockPosts(now: seedTime).length);
    });

    test('UserStore：装载后读到库里的账户，登记与退出都落库', () async {
      final AppDatabase database = await openMemory();
      final SqliteUserRepository repository = SqliteUserRepository(
        database.database,
      );
      final UserStore store = UserStore(repository: repository);
      addTearDown(store.dispose);

      await store.load();
      expect(store.account, isNull);

      final Future<void> registering = store.register(
        displayName: ' 张同学 ',
        contact: ' 微信 zhang ',
      );
      // trim 之后立刻可见。
      expect(store.contact, '微信 zhang');
      await registering;
      expect((await repository.loadAccount())!.displayName, '张同学');

      await store.signOut();
      expect(store.account, isNull);
      expect(await repository.loadAccount(), isNull);
    });

    test('没有仓储时是纯内存仓库，照样能用', () async {
      final PostStore store = PostStore(
        initialPosts: <ItemPost>[buildBarePost()],
      );
      addTearDown(store.dispose);

      // 没有仓储时 load 是空操作，内存里的东西不会被清掉。
      await store.load();
      expect(store.posts.length, 1);

      await store.addPost(buildRichPost());
      expect(store.posts.first.id, 'local-3001');

      await store.updatePost(
        store.postById('local-3001')!.copyWith(status: PostStatus.resolved),
      );
      expect(store.postById('local-3001')!.status, PostStatus.resolved);

      await store.removePost('local-3001');
      expect(store.postById('local-3001'), isNull);
    });
  });

  group('设置', () {
    test('写入、读回、覆盖，不会攒出重复行', () async {
      final AppDatabase database = await openMemory();
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        database.database,
      );

      // 没存过时读出来是 null（上层据此退回默认值）。
      expect(await repository.read(SettingNames.themeMode), isNull);

      await repository.write(SettingNames.themeMode, 'dark');
      expect(await repository.read(SettingNames.themeMode), 'dark');

      // 覆盖：设置名是主键，改一项不会攒出新行。
      await repository.write(SettingNames.themeMode, 'light');
      expect(await repository.read(SettingNames.themeMode), 'light');
      expect(
        await database.database.query(DbSchema.settingsTable),
        hasLength(1),
      );

      // 各设置项互不干扰。
      await repository.write('other_setting', 'x');
      expect(await repository.read(SettingNames.themeMode), 'light');
      expect(await repository.read('other_setting'), 'x');
    });

    test('重开库之后设置还在', () async {
      final String path = p.join(makeTempDir().path, 'lost_and_found.db');

      final AppDatabase first = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      await SqliteSettingsRepository(
        first.database,
      ).write(SettingNames.themeMode, 'dark');
      await first.close();

      final AppDatabase second = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(second.close);

      expect(
        await SqliteSettingsRepository(second.database).read(
          SettingNames.themeMode,
        ),
        'dark',
      );
    });

    test('SettingsStore：装载后读回库里的选择，改动立刻落库', () async {
      final AppDatabase database = await openMemory();
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        database.database,
      );
      final SettingsStore store = SettingsStore(repository: repository);
      addTearDown(store.dispose);

      await store.load();
      expect(store.themeMode, ThemeMode.system);

      final Future<void> setting = store.setThemeMode(ThemeMode.dark);
      // 内存先改：界面不用等磁盘。
      expect(store.themeMode, ThemeMode.dark);
      await setting;
      expect(await repository.read(SettingNames.themeMode), 'dark');
    });

    test('库里存着认不出来的主题名时退回「跟随系统」', () async {
      final AppDatabase database = await openMemory();
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        database.database,
      );
      // 更早的版本写的、或者被手改过的值。
      await repository.write(SettingNames.themeMode, 'neon');

      final SettingsStore store = SettingsStore(repository: repository);
      addTearDown(store.dispose);

      await store.load();
      expect(store.themeMode, ThemeMode.system);
    });

    test('主题种子色：写入读回并跟着 Store 装载，认不出的颜色退回默认', () async {
      final AppDatabase database = await openMemory();
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        database.database,
      );

      // 没存过时读出来是 null（上层据此退回默认种子色）。
      expect(await repository.read(SettingNames.themeSeed), isNull);

      const Color violet = Color(0xFF6750A4);
      await repository.write(
        SettingNames.themeSeed,
        encodeColor(violet),
      );
      expect(await repository.read(SettingNames.themeSeed), '#FF6750A4');

      final SettingsStore store = SettingsStore(repository: repository);
      addTearDown(store.dispose);
      await store.load();
      expect(store.themeSeed, violet);

      // 改动先落内存（界面立刻换肤），再写库。
      const Color rose = Color(0xFFC2185B);
      final Future<void> setting = store.setThemeSeed(rose);
      expect(store.themeSeed, rose);
      await setting;
      expect(await repository.read(SettingNames.themeSeed), '#FFC2185B');
    });

    test('库里存着认不出来的颜色时退回默认种子色', () async {
      final AppDatabase database = await openMemory();
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        database.database,
      );

      for (final String bad in <String>['teal', '#12345', '#00FF0000']) {
        await repository.write(SettingNames.themeSeed, bad);

        final SettingsStore store = SettingsStore(repository: repository);
        addTearDown(store.dispose);
        await store.load();

        // 缺 A 通道（6 位）与全透明都不认：那不是用户挑得到的颜色。
        expect(store.themeSeed, AppTheme.seedColor, reason: '值 $bad');
      }
    });

    test('颜色与字符串互转', () {
      // 一律写成大写的 #AARRGGBB，查库时和设计稿里的写法对得上。
      expect(encodeColor(const Color(0xFF00695C)), '#FF00695C');
      expect(encodeColor(const Color(0x1F6750A4)), '#1F6750A4');
      expect(parseColor('#FF00695C'), const Color(0xFF00695C));
      expect(parseColor('  #ff00695c  '), const Color(0xFF00695C));

      // 认不出来的一律给 null，让上层退回默认值。
      expect(parseColor(null), isNull);
      expect(parseColor(''), isNull);
      expect(parseColor('00695C'), isNull);
      expect(parseColor('#xyz'), isNull);
      expect(parseColor('#00000000'), isNull);
    });

    test('版本 1 的老库升到当前版本会逐级补上后加的表，老数据还在', () async {
      final String path = p.join(makeTempDir().path, 'lost_and_found.db');

      // 先用版本 1 的建表语句建一个老库（不会走 onCreate 的示例数据）。
      final Database old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: createVersion1Schema,
        ),
      );
      await old.insert(DbSchema.postsTable, PostRow.toRow(buildBarePost()));
      await old.close();

      // 用当前版本打开：走 onUpgrade 补设置表、搜索记录表。
      final AppDatabase upgraded = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(upgraded.close);

      // 老数据原样还在（升级没有重建表）。
      final List<ItemPost> posts = await SqliteItemRepository(upgraded.database)
          .queryPosts(const PostQuery());
      expect(posts.map((ItemPost post) => post.id), <String>['local-3002']);
      // 账户表也还在，老库里是空的。
      expect(await SqliteUserRepository(upgraded.database).loadAccount(), isNull);
      // 升级不是建库：示例数据不该被补写进来。
      expect(posts, hasLength(1));

      // 新表能正常用了。
      final SqliteSettingsRepository repository = SqliteSettingsRepository(
        upgraded.database,
      );
      await repository.write(SettingNames.themeMode, 'dark');
      expect(await repository.read(SettingNames.themeMode), 'dark');

      // 版本 3 加的搜索记录表也补上了（更细的迁移用例见 search_history_test.dart）。
      final SqliteSearchHistoryRepository history =
          SqliteSearchHistoryRepository(upgraded.database);
      await history.addKeyword('雨伞', seedTime);
      expect(await history.loadKeywords(), <String>['雨伞']);
    });
  });
}

/// 版本 1 的建表语句（照抄当时的 `DbSchema.create`）。
///
/// 故意写死在这里，不调 `DbSchema.create`：迁移测试要的正是「一个老库」，
/// 用当前版本的建表语句建出来的库就不是老库了——那样测不出「补表」这件事。
Future<void> createVersion1Schema(Database db, int version) async {
  await db.execute('''
CREATE TABLE posts (
  id TEXT NOT NULL PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  location TEXT NOT NULL,
  event_time INTEGER NOT NULL,
  contact TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  description TEXT,
  image_paths TEXT NOT NULL,
  status TEXT NOT NULL,
  is_mine INTEGER NOT NULL,
  search_text TEXT NOT NULL
)
''');
  await db.execute('CREATE INDEX idx_posts_created_at ON posts (created_at)');
  await db.execute('''
CREATE TABLE user_account (
  id INTEGER NOT NULL PRIMARY KEY CHECK (id = 1),
  display_name TEXT NOT NULL,
  contact TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''');
}

/// 打开一个内存库，并登记用完关掉。
///
/// 每个用例一个全新的空库（示例数据照建），彼此不干扰。
Future<AppDatabase> openMemory() async {
  final AppDatabase database = await AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    seededAt: seedTime,
  );
  addTearDown(database.close);
  return database;
}

/// 打开一个已经装好示例数据的内存库，取它的信息仓储。
Future<SqliteItemRepository> seededRepository() async {
  final AppDatabase database = await openMemory();
  return SqliteItemRepository(database.database);
}

/// 跑一次查询，只要 id（断言顺序时看着清楚）。
Future<List<String>> idsOf(
  SqliteItemRepository repository,
  PostQuery query,
) async {
  final List<ItemPost> posts = await repository.queryPosts(query);
  return posts.map((ItemPost post) => post.id).toList();
}

/// 造一条「字段全用上」的信息：描述、图片、已完成、我发的，样样都有。
ItemPost buildRichPost() => ItemPost(
  id: 'local-3001',
  type: PostType.found,
  title: '银色保温杯',
  category: ItemCategory.daily,
  location: '第二食堂二楼',
  eventTime: seedTime.subtract(const Duration(hours: 3)),
  contact: '微信 bottle_li',
  createdAt: seedTime.subtract(const Duration(minutes: 30)),
  description: '杯底贴着一张写了我名字的贴纸。',
  imagePaths: const <String>['cup-front.jpg', 'cup-bottom.jpg'],
  status: PostStatus.resolved,
  isMine: true,
);

/// 造一条只填必填字段的信息（没有描述、没有图片）。
ItemPost buildBarePost() => ItemPost(
  id: 'local-3002',
  type: PostType.lost,
  title: '图书馆借书证',
  category: ItemCategory.card,
  location: '图书馆三楼',
  eventTime: seedTime,
  contact: '手机 13800000000',
  createdAt: seedTime,
);

/// 逐字段比对，用来确认「写进去的」和「读回来的」是同一条信息。
void expectSamePost(ItemPost got, ItemPost want) {
  expect(got.id, want.id);
  expect(got.type, want.type);
  expect(got.title, want.title);
  expect(got.category, want.category);
  expect(got.location, want.location);
  expect(
    got.eventTime.millisecondsSinceEpoch,
    want.eventTime.millisecondsSinceEpoch,
  );
  expect(got.contact, want.contact);
  expect(
    got.createdAt.millisecondsSinceEpoch,
    want.createdAt.millisecondsSinceEpoch,
  );
  expect(got.description, want.description);
  expect(got.imagePaths, want.imagePaths);
  expect(got.status, want.status);
  expect(got.isMine, want.isMine);
}

/// 建一个用完就删的临时目录（放库文件用）。
Directory makeTempDir() {
  final Directory dir = Directory.systemTemp.createTempSync(
    'lost_and_found_test',
  );
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}
