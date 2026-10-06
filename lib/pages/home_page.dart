import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../models/item_post.dart';
import '../models/post_query.dart';
import '../widgets/post_card.dart';
import '../widgets/post_filter_bar.dart';
import 'post_detail_page.dart';
import 'search_page.dart';

/// 首页：集中浏览校园里的失物 / 招领信息，并可通过筛选器与搜索栏缩小范围。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onGoHome});

  /// 详情页发现信息已被删除时，「回到首页」要回到的地方，由外壳注入。
  ///
  /// 首页自己就是「首页」，单独渲染时用不上；但它照样把动作传给详情页，
  /// 换到别的入口（比如「我的」）打开详情时才有得回。
  final VoidCallback? onGoHome;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// `null` 表示“全部”。
  PostType? _typeFilter;

  /// `null` 表示“全部分类”。
  ItemCategory? _categoryFilter;

  PostSortBy _sortBy = PostSortBy.newest;

  /// 当前筛选与排序。
  ///
  /// 判定与排序都交给 [PostQuery]：搜索界面用的是同一个类，
  /// 两处的筛选口径不会各写一套、日后走偏。
  PostQuery get _query =>
      PostQuery(type: _typeFilter, category: _categoryFilter, sortBy: _sortBy);

  void _openSearch() {
    // 在搜索界面里打开详情后，「回到首页」也得回得来，所以把动作继续传下去。
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(onGoHome: widget.onGoHome),
      ),
    );
  }

  /// 点卡片看详细内容（UI 事项 4）。
  void _openDetail(ItemPost post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PostDetailPage(postId: post.id, onGoHome: widget.onGoHome),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _categoryFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 依赖仓库：发布界面新增信息后，这里会自动重建并显示出来。
    final PostQuery query = _query;
    final List<ItemPost> posts = query.apply(PostScope.of(context).posts);

    return Scaffold(
      appBar: AppBar(title: const Text('校园失物招领')),
      body: Column(
        children: <Widget>[
          _SearchEntry(onTap: _openSearch),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: PostFilterBar(
              keyPrefix: 'home-filter',
              typeFilter: _typeFilter,
              categoryFilter: _categoryFilter,
              sortBy: _sortBy,
              onTypeChanged: (PostType? value) =>
                  setState(() => _typeFilter = value),
              onCategoryChanged: (ItemCategory? value) =>
                  setState(() => _categoryFilter = value),
              onSortChanged: (PostSortBy value) =>
                  setState(() => _sortBy = value),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: posts.isEmpty
                ? _EmptyResult(
                    hasFilter: query.hasFilter,
                    onClear: _clearFilters,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: posts.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) => PostCard(
                      post: posts[index],
                      onTap: () => _openDetail(posts[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 首页顶部的搜索栏，点击后进入搜索界面。
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        key: const Key('home-search-entry'),
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: <Widget>[
                Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '搜索物品名称、地点',
                    style: TextStyle(
                      fontSize: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 筛选后没有结果时的提示。
class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.hasFilter, required this.onClear});

  final bool hasFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text('没有符合条件的信息', style: theme.textTheme.titleMedium),
            if (hasFilter) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '换一个关键词或放宽筛选条件试试。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onClear, child: const Text('清除筛选')),
            ],
          ],
        ),
      ),
    );
  }
}
