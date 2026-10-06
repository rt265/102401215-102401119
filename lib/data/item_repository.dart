import 'package:sqflite/sqflite.dart';

import '../models/item_post.dart';
import '../models/post_query.dart';
import 'db_schema.dart';
import 'post_row.dart';

/// 信息仓库：界面层只跟它打交道，不关心底下是 SQLite 还是内存。
///
/// 界面上的筛选是**即时**的（点一下类型就要出结果），所以列表页仍然拿
/// [PostStore] 内存里的快照自己筛；这里的方法供启动时装载、
/// 以及 [PostStore] 有仓储时的落库使用。
///
/// TODO: 数据量大到内存放不下时，把列表页改成直接 `await queryPosts(...)`，
/// 界面层构造 [PostQuery] 的用法不用变。
abstract interface class ItemRepository {
  /// 按 [query] 里的关键词 / 类型 / 分类筛选，并按排序方式返回。
  Future<List<ItemPost>> queryPosts(PostQuery query);

  /// 新写一条信息。同 id 已存在时覆盖（id 由发布时的时间戳生成，正常不会撞）。
  Future<void> insertPost(ItemPost post);

  /// 整体替换同 id 的信息；id 不存在时什么都不做。
  Future<void> updatePost(ItemPost post);

  /// 删除一条信息；id 不存在时什么都不做。
  Future<void> deletePost(String id);
}

/// 落到本地 SQLite 的 [ItemRepository]。
///
/// 筛选与排序都在 SQL 里做，**判定口径要和内存版对齐**
/// （[ItemPost.matchesKeyword] / [ItemPost.matchesFilter] / [PostQuery.apply]）：
/// 关键词靠 `posts.search_text` 这一冗余列实现，拆分与转义见 [_conditionFor]。
/// `test/sqlite_storage_test.dart` 里有一组「SQL 结果 == 内存筛出来的结果」的对拍测试。
class SqliteItemRepository implements ItemRepository {
  SqliteItemRepository(this._database);

  /// 执行 SQL 的句柄，通常是 [AppDatabase.database]。
  final DatabaseExecutor _database;

  @override
  Future<List<ItemPost>> queryPosts(PostQuery query) async {
    final _Condition condition = _conditionFor(query);

    // 并列（发布时间相同）时不保证顺序——内存版的 List.sort 同样不保证，
    // 所以这里也不加第二排序键，免得两边对不上。
    final List<Map<String, Object?>> rows = await _database.query(
      DbSchema.postsTable,
      where: condition.sql.isEmpty ? null : condition.sql,
      whereArgs: condition.args.isEmpty ? null : condition.args,
      orderBy:
          '${DbSchema.postCreatedAt} '
          '${query.sortBy == PostSortBy.newest ? 'DESC' : 'ASC'}',
    );

    return rows.map(PostRow.fromRow).toList();
  }

  @override
  Future<void> insertPost(ItemPost post) async {
    await _database.insert(
      DbSchema.postsTable,
      PostRow.toRow(post),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updatePost(ItemPost post) async {
    await _database.update(
      DbSchema.postsTable,
      PostRow.toRow(post),
      where: '${DbSchema.postId} = ?',
      whereArgs: <Object?>[post.id],
    );
  }

  @override
  Future<void> deletePost(String id) async {
    await _database.delete(
      DbSchema.postsTable,
      where: '${DbSchema.postId} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 把 [query] 翻成 `WHERE` 片段与参数（与 [PostQuery.apply] 同口径）。
  static _Condition _conditionFor(PostQuery query) {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    final PostType? type = query.type;
    if (type != null) {
      clauses.add('${DbSchema.postType} = ?');
      args.add(type.name);
    }

    final ItemCategory? category = query.category;
    if (category != null) {
      clauses.add('${DbSchema.postCategory} = ?');
      args.add(category.name);
    }

    // 与 ItemPost.matchesKeyword 同款：按空白拆词，多一个词是收窄结果，
    // 所以每个词一条 LIKE、用 AND 串起来。
    if (query.hasKeyword) {
      for (final String token in _tokensOf(query.keyword)) {
        clauses.add("${DbSchema.postSearchText} LIKE ? ESCAPE '\\'");
        args.add('%${_escapeLike(token)}%');
      }
    }

    return _Condition(clauses.join(' AND '), args);
  }

  /// 关键词拆词，口径同 [ItemPost.matchesKeyword]。
  static List<String> _tokensOf(String keyword) => keyword
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);

  /// 转义 `LIKE` 的通配符，让用户输入的 `%` `_` 按普通字符比
  /// （否则 `%` 会变成"任意内容"，搜出来的东西比该有的多）。
  static String _escapeLike(String token) => token
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// 拼好的 `WHERE` 片段与它的参数。
class _Condition {
  const _Condition(this.sql, this.args);

  /// 空的表示不筛任何条件（取全部）。
  final String sql;

  final List<Object?> args;
}
