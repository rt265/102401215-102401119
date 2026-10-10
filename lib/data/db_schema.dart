import 'package:sqflite/sqflite.dart';

/// 本地 SQLite 的表结构：表名、列名与建表语句。
///
/// 整个应用的库表布局只在这一个文件里定义：列名写成常量，仓储拼 SQL、
/// 行编解码引用这些常量，建表语句也用同一批常量拼出来——名字只写一遍，
/// 不会出现「代码里叫 created_at、建表时写成 create_time」这种对不上的错。
///
/// 表结构改动时：升 [version]，在 [create] 之外补一段迁移
/// （见 `AppDatabase.open` 的 `onUpgrade`）。
abstract final class DbSchema {
  /// 库版本，写进 SQLite 的 `user_version`。
  ///
  /// 版本 1：首版，`posts` + `user_account`。
  /// 版本 2：加 `app_settings`（应用设置的键值表，见 [createSettingsTable]）。
  /// 版本 3：加 `search_history`（搜索记录，见 [createSearchHistoryTable]）。
  static const int version = 3;

  /// 库文件名，落在系统给本应用的数据库目录下。
  static const String fileName = 'lost_and_found.db';

  // ---------------------------------------------------------------- posts --

  /// 失物 / 招领信息表，一条信息一行。
  static const String postsTable = 'posts';

  static const String postId = 'id';
  static const String postType = 'type';
  static const String postTitle = 'title';
  static const String postCategory = 'category';
  static const String postLocation = 'location';
  static const String postEventTime = 'event_time';
  static const String postContact = 'contact';
  static const String postCreatedAt = 'created_at';
  static const String postDescription = 'description';
  static const String postImagePaths = 'image_paths';
  static const String postStatus = 'status';
  static const String postIsMine = 'is_mine';
  static const String postSearchText = 'search_text';

  /// 按发布时间排序 / 取最新的那条时走这个索引。
  static const String postsCreatedAtIndex = 'idx_posts_created_at';

  // --------------------------------------------------------- user_account --

  /// 本机账户表。应用是单机自用的，只存一行，用固定主键 [accountId] = 1 兜住。
  static const String userAccountTable = 'user_account';

  /// 账户表固定主键值（单行表）。
  static const int accountRowId = 1;

  static const String accountRowKey = 'id';
  static const String accountDisplayName = 'display_name';
  static const String accountContact = 'contact';
  static const String accountCreatedAt = 'created_at';

  // ---------------------------------------------------------- app_settings --

  /// 应用设置表：一个设置项一行，只存用户改过的那些项。
  ///
  /// 做成键值表而不是给每项设置开一列：设置项以后只会越来越多（外观、通知……），
  /// 每加一项都给表加一列，就等于每加一项都要写一次迁移。
  static const String settingsTable = 'app_settings';

  static const String settingName = 'setting_name';
  static const String settingValue = 'setting_value';

  // -------------------------------------------------------- search_history --

  /// 搜索记录表：搜过的一个关键词一行。
  ///
  /// 关键词本身就是主键：同一个词再搜一次只是挪到最前（写入用 `REPLACE`，
  /// 时间戳覆盖成新的），表里不会攒出两行相同的词。
  /// 「最多留几条」由 `SearchHistoryStore` 管（见该类），库表只负责存。
  static const String historyTable = 'search_history';

  static const String historyKeyword = 'keyword';
  static const String historySearchedAt = 'searched_at';

  /// 建表 + 建索引。
  ///
  /// 只在库文件**第一次**创建时被调用（`onCreate`），所以直接用 `CREATE TABLE`
  /// 而不是 `IF NOT EXISTS`：表结构要是和代码对不上，宁可当场报错。
  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE $postsTable (
  $postId TEXT NOT NULL PRIMARY KEY,
  $postType TEXT NOT NULL,
  $postTitle TEXT NOT NULL,
  $postCategory TEXT NOT NULL,
  $postLocation TEXT NOT NULL,
  $postEventTime INTEGER NOT NULL,
  $postContact TEXT NOT NULL,
  $postCreatedAt INTEGER NOT NULL,
  $postDescription TEXT,
  $postImagePaths TEXT NOT NULL,
  $postStatus TEXT NOT NULL,
  $postIsMine INTEGER NOT NULL,
  $postSearchText TEXT NOT NULL
)
''');

    await db.execute(
      'CREATE INDEX $postsCreatedAtIndex ON $postsTable ($postCreatedAt)',
    );

    // 单行表：CHECK 兜住主键，写入时用 REPLACE，不会攒出第二行账户。
    await db.execute('''
CREATE TABLE $userAccountTable (
  $accountRowKey INTEGER NOT NULL PRIMARY KEY CHECK ($accountRowKey = $accountRowId),
  $accountDisplayName TEXT NOT NULL,
  $accountContact TEXT NOT NULL,
  $accountCreatedAt INTEGER NOT NULL
)
''');

    await createSettingsTable(db);
    await createSearchHistoryTable(db);
  }

  /// 建应用设置表。
  ///
  /// 单独抽出来是因为它被两处用到：首建库（[create]）与版本 1 → 2 的迁移
  /// （`AppDatabase.open` 的 `onUpgrade`）。迁移里不能调 [create]——那会把已经
  /// 存在的表再建一遍，而且这里的建表语句不带 `IF NOT EXISTS`，会直接报错。
  static Future<void> createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE $settingsTable (
  $settingName TEXT NOT NULL PRIMARY KEY,
  $settingValue TEXT NOT NULL
)
''');
  }

  /// 建搜索记录表。
  ///
  /// 与 [createSettingsTable] 同样的道理单独抽出来：首建库（[create]）与
  /// 版本 2 → 3 的迁移（`AppDatabase.open` 的 `onUpgrade`）都要用它。
  static Future<void> createSearchHistoryTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE $historyTable (
  $historyKeyword TEXT NOT NULL PRIMARY KEY,
  $historySearchedAt INTEGER NOT NULL
)
''');
  }
}
