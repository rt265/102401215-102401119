import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/item_post.dart';
import 'db_schema.dart';
import 'mock_posts.dart';
import 'post_row.dart';

/// 本地 SQLite 库：开库、建表、第一次建库时把示例数据写进去。
///
/// 应用启动时由 `main()` 开一次，之后整个进程共用同一个句柄：
/// 两个仓储（信息、账户）都挂在它身上，界面层完全见不到 SQL。
class AppDatabase {
  AppDatabase._(this._database);

  /// 已经打开的库。
  final Database _database;

  /// 交给仓储执行 SQL 的句柄。
  Database get database => _database;

  /// 打开本地库；库文件不存在时会建表并写入示例数据。
  ///
  /// [factory] 与 [path] 是留给测试的入口：应用里两个都不传，用平台插件自带的
  /// `databaseFactory` 和系统给应用的数据库目录；测试里传
  /// `databaseFactoryFfi` 加上一个临时路径或 `inMemoryDatabasePath`。
  /// [seededAt] 只用来钉住示例数据里的相对时间（同样只为测试）。
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
    DateTime? seededAt,
  }) async {
    final DatabaseFactory dbFactory = factory ?? databaseFactory;
    final String dbPath =
        path ?? p.join(await dbFactory.getDatabasesPath(), DbSchema.fileName);

    final Database database = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DbSchema.version,
        onCreate: (Database db, int version) async {
          await DbSchema.create(db);
          await _seedSamplePosts(db, seededAt);
        },
        onUpgrade: _upgrade,
      ),
    );

    return AppDatabase._(database);
  }

  /// 关闭数据库。
  ///
  /// 应用整个生命周期只开一次，正常退出时由系统回收，所以目前只有测试会调它。
  Future<void> close() => _database.close();

  /// 首次建库时写入示例数据（`lib/data/mock_posts.dart`）。
  ///
  /// 只在 `onCreate` 里写，所以用户把示例数据删掉之后它们不会再冒出来，
  /// 用户自己发布的信息也不会被这套初始化覆盖。
  static Future<void> _seedSamplePosts(Database db, DateTime? now) async {
    final Batch batch = db.batch();
    for (final ItemPost post in buildMockPosts(now: now)) {
      batch.insert(DbSchema.postsTable, PostRow.toRow(post));
    }
    await batch.commit(noResult: true);
  }

  /// 库版本升级时的迁移。
  ///
  /// 版本 1 → 2：补上应用设置表（版本 1 的库里没有）。
  /// 以后加列加表时按 `from` 逐级补进来（SQLite 的 `ALTER TABLE` 能力有限，
  /// 大改动走「建新表 → 拷数据 → 改名」那套）。
  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      await DbSchema.createSettingsTable(db);
    }
  }
}
