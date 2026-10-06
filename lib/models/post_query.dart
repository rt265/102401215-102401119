import 'item_post.dart';

/// 信息列表的排序方式。
enum PostSortBy {
  newest('最新发布'),
  oldest('最早发布');

  const PostSortBy(this.label);

  final String label;
}

/// 一次「浏览 / 搜索」查询：关键词 + 类型 + 分类 + 排序。
///
/// 首页与搜索界面用的是同一套判定——首页只填类型 / 分类 / 排序，搜索界面再多个关键词。
/// 判定写在 [ItemPost.matchesKeyword] / [ItemPost.matchesFilter] 里，
/// 这里只负责「按顺序筛一遍再排一次」，免得两个页面各抄一遍、日后行为跑偏。
///
/// 接入本地 SQLite 之后列表页仍然走 [apply]：筛选要即时出结果，本地这点数据
/// 不值得为它加一次异步查询。同一套条件另有一个 SQL 版
/// （`SqliteItemRepository.queryPosts`，启动装载时用），两者的一致性由
/// `test/sqlite_storage_test.dart` 里的对拍测试兜住——改判定时两处都要改。
class PostQuery {
  const PostQuery({
    this.keyword = '',
    this.type,
    this.category,
    this.sortBy = PostSortBy.newest,
  });

  /// 搜索关键词。空串表示不按关键词筛选。
  final String keyword;

  /// `null` 表示“全部”。
  final PostType? type;

  /// `null` 表示“全部分类”。
  final ItemCategory? category;

  final PostSortBy sortBy;

  /// 是否有正在生效的筛选条件（不含关键词）。
  ///
  /// 空结果提示据此决定要不要给「清除筛选」——没有筛选可清时不给。
  bool get hasFilter => type != null || category != null;

  /// 关键词是不是空的（去掉首尾空白后）。
  bool get hasKeyword => keyword.trim().isNotEmpty;

  /// 对 [source] 应用关键词与筛选，再按 [sortBy] 排序。
  List<ItemPost> apply(List<ItemPost> source) {
    final List<ItemPost> result = source
        .where(
          (ItemPost post) =>
              post.matchesKeyword(keyword) &&
              post.matchesFilter(type: type, category: category),
        )
        .toList();

    result.sort((ItemPost a, ItemPost b) {
      final int result = b.createdAt.compareTo(a.createdAt);
      return sortBy == PostSortBy.newest ? result : -result;
    });

    return result;
  }
}
