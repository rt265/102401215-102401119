import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lost_and_found/data/app_database.dart';
import 'package:lost_and_found/data/db_schema.dart';
import 'package:lost_and_found/data/search_history_repository.dart';
import 'package:lost_and_found/data/search_history_store.dart';

/// 搜索记录的本地存储测试（本地后端事项 4）。
///
/// 三块：表本身（SQL 仓库读写）、内存仓库（与 SQL 版行为对齐）、
/// 版本迁移（老库补表）与「重开应用还在」。
///
/// 和 sqlite_storage_test.dart 一样走 ffi：`flutter test` 里没有 sqflite 插件，
/// `sqlite3` 直接加载进测试进程，SQL 行为与真机一致。

/// 钉死一个时间，断言顺序时不必担心「跑测试的那一刻」。
final DateTime seedTime = DateTime(2026, 5, 1, 12);

void main() {
  setUpAll(sqfliteFfiInit);

  group('SQL 仓库', () {
    test('记下的词能读回来', () async {
      final AppDatabase database = await openMemory();
      final SqliteSearchHistoryRepository repository =
          SqliteSearchHistoryRepository(database.database);

      expect(await repository.loadKeywords(), isEmpty);

      await repository.addKeyword('雨伞', seedTime);
      expect(await repository.loadKeywords(), <String>['雨伞']);
    });

    test('最近搜的排最前', () async {
      final AppDatabase database = await openMemory();
      final SqliteSearchHistoryRepository repository =
          SqliteSearchHistoryRepository(database.database);

      await repository.addKeyword('雨伞', seedTime);
      await repository.addKeyword('一卡通', seedTime.add(const Duration(minutes: 5)));
      await repository.addKeyword('钥匙', seedTime.add(const Duration(minutes: 9)));

      expect(await repository.loadKeywords(), <String>['钥匙', '一卡通', '雨伞']);
    });

    test('同一个词再搜一次只挪位置，不会多出一行', () async {
      final AppDatabase database = await openMemory();
      final SqliteSearchHistoryRepository repository =
          SqliteSearchHistoryRepository(database.database);

      await repository.addKeyword('雨伞', seedTime);
      await repository.addKeyword('钥匙', seedTime.add(const Duration(minutes: 5)));
      // 再搜一次「雨伞」：关键词是主键，这次写入把时间戳换掉（REPLACE）。
      await repository.addKeyword('雨伞', seedTime.add(const Duration(minutes: 9)));

      expect(await repository.loadKeywords(), <String>['雨伞', '钥匙']);
      expect(await countHistoryRows(database), 2, reason: '关键词是主键，两行就够');
    });

    test('给多少条就最多读回多少条', () async {
      final AppDatabase database = await openMemory();
      final SqliteSearchHistoryRepository repository =
          SqliteSearchHistoryRepository(database.database);

      for (int i = 0; i < 12; i++) {
        await repository.addKeyword('词$i', seedTime.add(Duration(minutes: i)));
      }

      // 库里留着 12 行（条数由上层管），读的时候按 limit 截断。
      expect(await countHistoryRows(database), 12);
      expect(await repository.loadKeywords(limit: 3), <String>['词11', '词10', '词9']);
    });

    test('删掉一条与清空全部', () async {
      final AppDatabase database = await openMemory();
      final SqliteSearchHistoryRepository repository =
          SqliteSearchHistoryRepository(database.database);

      await repository.addKeyword('雨伞', seedTime);
      await repository.addKeyword('钥匙', seedTime.add(const Duration(minutes: 5)));

      await repository.removeKeyword('雨伞');
      expect(await repository.loadKeywords(), <String>['钥匙']);

      // 删一个本来就没有的：悄无声息，不报错。
      await repository.removeKeyword('不存在的词');
      expect(await repository.loadKeywords(), <String>['钥匙']);

      await repository.clearKeywords();
      expect(await repository.loadKeywords(), isEmpty);
    });

    test('重开同一个库（等于重启应用）搜索记录还在，删掉的不回来', () async {
      final String path = p.join(makeTempDir().path, DbSchema.fileName);

      final AppDatabase first = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      final SqliteSearchHistoryRepository firstRepository =
          SqliteSearchHistoryRepository(first.database);
      await firstRepository.addKeyword('雨伞', seedTime);
      await firstRepository.addKeyword('钥匙', seedTime.add(const Duration(minutes: 5)));
      await firstRepository.removeKeyword('雨伞');
      await first.close();

      final AppDatabase second = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(second.close);

      expect(
        await SqliteSearchHistoryRepository(second.database).loadKeywords(),
        <String>['钥匙'],
      );
    });
  });

  group('内存仓库', () {
    test('语义与 SQL 版对齐：重搜挪到最前、只出现一遍', () async {
      final MemorySearchHistoryRepository repository =
          MemorySearchHistoryRepository();

      await repository.addKeyword('雨伞', seedTime);
      await repository.addKeyword('钥匙', seedTime.add(const Duration(minutes: 5)));
      await repository.addKeyword('雨伞', seedTime.add(const Duration(minutes: 9)));

      expect(await repository.loadKeywords(), <String>['雨伞', '钥匙']);
    });

    test('读回时按 limit 截断，且不超过自己的上限', () async {
      final MemorySearchHistoryRepository repository =
          MemorySearchHistoryRepository(readLimit: 3);

      for (int i = 0; i < 5; i++) {
        await repository.addKeyword('词$i', seedTime);
      }

      expect(await repository.loadKeywords(), <String>['词4', '词3', '词2']);
      expect(await repository.loadKeywords(limit: 1), <String>['词4']);
    });

    test('删掉一条与清空全部', () async {
      final MemorySearchHistoryRepository repository =
          MemorySearchHistoryRepository();
      await repository.addKeyword('雨伞', seedTime);
      await repository.addKeyword('钥匙', seedTime);

      await repository.removeKeyword('雨伞');
      expect(await repository.loadKeywords(), <String>['钥匙']);

      await repository.clearKeywords();
      expect(await repository.loadKeywords(), isEmpty);
    });
  });

  group('仓库（Store）', () {
    test('开应用时把上次的记录读进来', () async {
      final MemorySearchHistoryRepository repository =
          MemorySearchHistoryRepository();
      await repository.addKeyword('雨伞', seedTime);
      await repository.addKeyword('钥匙', seedTime.add(const Duration(minutes: 5)));

      final SearchHistoryStore store = SearchHistoryStore(
        repository: repository,
      );
      await store.load();

      expect(store.keywords, <String>['钥匙', '雨伞']);
      expect(store.isEmpty, isFalse);
    });

    test('记录写穿到仓储，重开一个仓库也读得回来', () async {
      final MemorySearchHistoryRepository repository =
          MemorySearchHistoryRepository();
      final SearchHistoryStore store = SearchHistoryStore(
        repository: repository,
      );

      await store.record('雨伞');

      expect(store.keywords, <String>['雨伞']);
      expect(await repository.loadKeywords(), <String>['雨伞']);

      final SearchHistoryStore reopened = SearchHistoryStore(
        repository: repository,
      );
      await reopened.load();
      expect(reopened.keywords, <String>['雨伞']);
    });

    test('同一个词再搜一次挪到最前，大小写不同也算同一个词', () async {
      final SearchHistoryStore store = SearchHistoryStore(
        initialKeywords: <String>['雨伞', 'iPhone', '钥匙'],
      );

      await store.record('雨伞');
      expect(store.keywords, <String>['雨伞', 'iPhone', '钥匙']);

      await store.record('iphone');
      expect(
        store.keywords,
        <String>['iphone', '雨伞', '钥匙'],
        reason: '忽略大小写判重，列表里不该同时出现 iPhone 和 iphone',
      );
    });

    test('首尾空白会被去掉，全是空白的词直接不收', () async {
      final SearchHistoryStore store = SearchHistoryStore();

      await store.record('  雨伞  ');
      await store.record('   ');
      await store.record('');

      expect(store.keywords, <String>['雨伞']);
    });

    test('最多只留 10 个词，最先搜的会被挤掉', () async {
      final SearchHistoryStore store = SearchHistoryStore();

      for (int i = 0; i < 12; i++) {
        await store.record('词$i');
      }

      expect(store.keywords, hasLength(SearchHistoryStore.maxKeywords));
      expect(store.keywords.first, '词11');
      expect(store.keywords, isNot(contains('词0')));
      expect(store.keywords, isNot(contains('词1')));
    });

    test('删掉一条与清空全部', () async {
      final SearchHistoryStore store = SearchHistoryStore(
        initialKeywords: <String>['雨伞', '钥匙'],
      );

      await store.removeKeyword('雨伞');
      expect(store.keywords, <String>['钥匙']);

      await store.clear();
      expect(store.keywords, isEmpty);
      expect(store.isEmpty, isTrue);
    });

    test('记录一变就通知界面', () async {
      final SearchHistoryStore store = SearchHistoryStore();
      int notified = 0;
      store.addListener(() => notified++);

      await store.record('雨伞');
      expect(notified, 1);

      // 已经在最前：屏幕上看不出变化，不必重建。
      await store.record('雨伞');
      expect(notified, 1);

      // 挪位置和删除是真变化，要通知。
      await store.record('钥匙');
      await store.record('雨伞');
      await store.removeKeyword('钥匙');
      expect(notified, 4);
    });

    test('没接仓储时是纯内存实现，照样能用', () async {
      final SearchHistoryStore store = SearchHistoryStore();

      await store.load();
      await store.record('雨伞');

      expect(store.keywords, <String>['雨伞']);
    });
  });

  group('版本迁移', () {
    test('版本 2 的老库升到版本 3 会补上搜索记录表，老数据还在', () async {
      final String path = p.join(makeTempDir().path, DbSchema.fileName);

      // 先用版本 2 的建表语句建一个老库（不会走 onCreate 的示例数据）。
      final Database old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: createVersion2Schema,
        ),
      );
      await old.close();

      final AppDatabase upgraded = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(upgraded.close);

      // 补出来的新表能正常用（能建就能读写）。
      final SqliteSearchHistoryRepository repository =
          SqliteSearchHistoryRepository(upgraded.database);
      await repository.addKeyword('雨伞', seedTime);
      expect(await repository.loadKeywords(), <String>['雨伞']);

      // 升级不是建库：示例数据不该被补写进来。
      expect(await upgraded.database.query(DbSchema.postsTable), isEmpty);

      // 老库里就有的两张表也没被动过。
      expect(await upgraded.database.query(DbSchema.settingsTable), isEmpty);
      expect(await upgraded.database.query(DbSchema.userAccountTable), isEmpty);
    });

    test('版本 1 的老库也能一路补到版本 3（设置表 + 搜索记录表）', () async {
      final String path = p.join(makeTempDir().path, DbSchema.fileName);

      final Database old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: createVersion1Schema,
        ),
      );
      await old.close();

      final AppDatabase upgraded = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        seededAt: seedTime,
      );
      addTearDown(upgraded.close);

      expect(await upgraded.database.query(DbSchema.settingsTable), isEmpty);
      expect(await upgraded.database.query(DbSchema.historyTable), isEmpty);
    });
  });
}

/// 打开一个内存库（当前版本，示例数据照建），并登记用完关掉。
Future<AppDatabase> openMemory() async {
  final AppDatabase database = await AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    seededAt: seedTime,
  );
  addTearDown(database.close);
  return database;
}

/// 搜索记录表现有几行（直接问库，绕开仓库那层的截断）。
Future<int> countHistoryRows(AppDatabase database) async {
  final List<Map<String, Object?>> rows = await database.database.query(
    DbSchema.historyTable,
    columns: <String>[DbSchema.historyKeyword],
  );
  return rows.length;
}

/// 造一个临时目录（用例结束后连目录一起删掉）。
Directory makeTempDir() {
  final Directory dir = Directory.systemTemp.createTempSync('lost_and_found_test');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}

/// 版本 1 的建表语句（照抄当时的 `DbSchema.create`）：`posts` + `user_account`。
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

/// 版本 2 的建表语句：在版本 1 上多一张 `app_settings`。
///
/// 同样故意写死：要的就是「一个还没有搜索记录表的老库」。
Future<void> createVersion2Schema(Database db, int version) async {
  await createVersion1Schema(db, 1);
  await db.execute('''
CREATE TABLE app_settings (
  setting_name TEXT NOT NULL PRIMARY KEY,
  setting_value TEXT NOT NULL
)
''');
}
