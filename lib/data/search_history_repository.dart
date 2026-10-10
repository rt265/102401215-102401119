import 'package:sqflite/sqflite.dart';

import 'db_schema.dart';

/// 搜索记录仓库：读回最近搜过的关键词、记下一个新词、删掉一条或全部。
///
/// 关键词是表的主键，所以「记下同一个词」只是把它挪到最前，
/// 不区分大小写地排掉重复这件事留给上层（上层拿 [loadKeywords] 里的词去比对）。
abstract interface class SearchHistoryRepository {
  /// 读回搜索记录，最近搜的排在最前，最多 [limit] 条。
  ///
  /// 库里可能留着比 [limit] 更多的老词（见 `SearchHistoryStore` 对条数的处置），
  /// 所以读的时候要真的截断，不能只指望写入端。
  Future<List<String>> loadKeywords({int limit = 10});

  /// 记下一个关键词（已经有的话覆盖它的时间，也就是挪到最前）。
  ///
  /// 写之前要把词 `trim` 干净；空词不该进库，由上层挡掉。
  Future<void> addKeyword(String keyword, DateTime searchedAt);

  /// 删掉一个关键词；本来就没有时什么都不发生。
  Future<void> removeKeyword(String keyword);

  /// 清空全部搜索记录。
  Future<void> clearKeywords();
}

/// 落到本地 SQLite 的 [SearchHistoryRepository]。
class SqliteSearchHistoryRepository implements SearchHistoryRepository {
  SqliteSearchHistoryRepository(this._database);

  /// 执行 SQL 的句柄，通常是 [AppDatabase.database]。
  final DatabaseExecutor _database;

  @override
  Future<List<String>> loadKeywords({int limit = 10}) async {
    final List<Map<String, Object?>> rows = await _database.query(
      DbSchema.historyTable,
      columns: <String>[DbSchema.historyKeyword],
      // `rowid` 是兜底的次序：同一毫秒里连着记两个词时时间戳会一样，
      // 只按时间排就分不出先后（顺序会变成「看 SQLite 心情」）。
      orderBy: '${DbSchema.historySearchedAt} DESC, rowid DESC',
      limit: limit,
    );
    return rows
        .map((Map<String, Object?> row) => row[DbSchema.historyKeyword]! as String)
        .toList();
  }

  @override
  Future<void> addKeyword(String keyword, DateTime searchedAt) async {
    // REPLACE：主键撞上就换成新行（时间戳更新），没撞上就正常插入。
    await _database.insert(DbSchema.historyTable, <String, Object?>{
      DbSchema.historyKeyword: keyword,
      DbSchema.historySearchedAt: searchedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> removeKeyword(String keyword) async {
    await _database.delete(
      DbSchema.historyTable,
      where: '${DbSchema.historyKeyword} = ?',
      whereArgs: <Object?>[keyword],
    );
  }

  @override
  Future<void> clearKeywords() async {
    await _database.delete(DbSchema.historyTable);
  }
}

/// 纯内存的 [SearchHistoryRepository]（测试与预览用）。
///
/// 行为与 SQL 版对齐：同一个词再记一次只是挪到最前，
/// 读回来时也是「最近在前、最多 [readLimit] 条」。
class MemorySearchHistoryRepository implements SearchHistoryRepository {
  /// [readLimit] 是读回时的条数上限，默认与 `SearchHistoryStore.maxKeywords` 一致。
  ///
  /// 参数名与字段名不同（字段是私有的 `_readLimit`），所以这里不能用
  /// `this._readLimit` 那种初始化形参。
  // ignore: prefer_initializing_formals
  MemorySearchHistoryRepository({int readLimit = 10}) : _readLimit = readLimit;

  /// 读回时最多给几条；默认与 `SearchHistoryStore.maxKeywords` 一致。
  final int _readLimit;

  final List<String> _keywords = <String>[];

  @override
  Future<List<String>> loadKeywords({int limit = 10}) async {
    final int take = limit < _readLimit ? limit : _readLimit;
    return _keywords.take(take).toList();
  }

  @override
  Future<void> addKeyword(String keyword, DateTime searchedAt) async {
    _keywords
      ..removeWhere((String word) => word == keyword)
      ..insert(0, keyword);
  }

  @override
  Future<void> removeKeyword(String keyword) async {
    _keywords.removeWhere((String word) => word == keyword);
  }

  @override
  Future<void> clearKeywords() async {
    _keywords.clear();
  }
}
