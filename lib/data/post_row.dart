import 'dart:convert';

import '../models/item_post.dart';
import 'db_schema.dart';

/// `posts` 表的一行 ↔ [ItemPost] 的编解码。
///
/// 两边字段名字不同（`event_time` / `eventTime`）、类型也不同（枚举存名字、
/// 时间存毫秒、图片列表存 JSON 字符串），转换只在这里写一遍：
/// 仓储只管拼 SQL，界面层只认 [ItemPost]。
abstract final class PostRow {
  /// 把一条信息编成可以直接 insert / update 的一行。
  ///
  /// 每次写入都重新算一遍 [searchText]，改过标题或描述的信息
  /// 不会留下搜不到的关键词。
  static Map<String, Object?> toRow(ItemPost post) =>
      <String, Object?>{
        DbSchema.postId: post.id,
        DbSchema.postType: post.type.name,
        DbSchema.postTitle: post.title,
        DbSchema.postCategory: post.category.name,
        DbSchema.postLocation: post.location,
        DbSchema.postEventTime: post.eventTime.millisecondsSinceEpoch,
        DbSchema.postContact: post.contact,
        DbSchema.postCreatedAt: post.createdAt.millisecondsSinceEpoch,
        DbSchema.postDescription: post.description,
        DbSchema.postImagePaths: jsonEncode(post.imagePaths),
        DbSchema.postStatus: post.status.name,
        DbSchema.postIsMine: post.isMine ? 1 : 0,
        DbSchema.postSearchText: searchText(post),
      }..addAll(
        post.authorId == null
            ? const <String, Object?>{}
            : <String, Object?>{DbSchema.postAuthorId: post.authorId},
      );

  /// 把查询回来的一行还原成 [ItemPost]。
  ///
  /// 枚举按名字读回，读到库里没有的名字时退回一个默认值：数据是本应用自己写的，
  /// 正常不会出现；万一有脏数据，也不该让整页列表打不开。
  static ItemPost fromRow(Map<String, Object?> row, {String? currentUserId}) =>
      ItemPost(
        id: row[DbSchema.postId]! as String,
        type: _enumByName(
          PostType.values,
          row[DbSchema.postType],
          PostType.lost,
        ),
        title: row[DbSchema.postTitle]! as String,
        category: _enumByName(
          ItemCategory.values,
          row[DbSchema.postCategory],
          ItemCategory.other,
        ),
        location: row[DbSchema.postLocation]! as String,
        eventTime: _timeOf(row[DbSchema.postEventTime]),
        contact: row[DbSchema.postContact]! as String,
        createdAt: _timeOf(row[DbSchema.postCreatedAt]),
        description: row[DbSchema.postDescription] as String?,
        imagePaths: _imagePathsOf(row[DbSchema.postImagePaths]),
        status: _enumByName(
          PostStatus.values,
          row[DbSchema.postStatus],
          PostStatus.pending,
        ),
        isMine: currentUserId == null
            ? (row[DbSchema.postIsMine] as int? ?? 0) != 0
            : row[DbSchema.postAuthorId] == currentUserId,
        authorId: row[DbSchema.postAuthorId] as String?,
      );

  /// 关键词搜索用的冗余列：物品名称 / 地点 / 描述 / 分类拼成的一段小写文本。
  ///
  /// 存在的理由只有一个——让 SQL 里的 `LIKE` 和 [ItemPost.matchesKeyword]
  /// 判的是同一批字段。SQLite 没法在一列里跨字段搜索，所以写入时先拼好。
  /// 用换行连接，保证一个词不会跨两个字段"接"上；`toString` 出的空值问题
  /// （description 为 null）在此处补成空串，与 [ItemPost.matchesKeyword] 一致。
  static String searchText(ItemPost post) => <String>[
    post.title,
    post.location,
    post.description ?? '',
    post.category.label,
  ].join('\n').toLowerCase();

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? stored,
    T fallback,
  ) {
    if (stored is String) {
      for (final T value in values) {
        if (value.name == stored) {
          return value;
        }
      }
    }
    return fallback;
  }

  static DateTime _timeOf(Object? stored) =>
      DateTime.fromMillisecondsSinceEpoch(stored! as int);

  static List<String> _imagePathsOf(Object? stored) {
    if (stored is! String || stored.isEmpty) {
      return const <String>[];
    }
    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // 同理：坏掉的图片列不该让一条信息整个读不出来。
    }
    return const <String>[];
  }
}
