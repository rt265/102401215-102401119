import 'package:flutter/material.dart';

import '../data/mock_posts.dart';
import '../models/item_post.dart';
import '../widgets/post_card.dart';
import 'search_page.dart';

/// 首页信息的排序方式。
enum PostSortBy {
  newest('最新发布'),
  oldest('最早发布');

  const PostSortBy(this.label);

  final String label;
}

/// 首页：集中浏览校园里的失物 / 招领信息，并可通过筛选器与搜索栏缩小范围。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// UI 构建阶段使用示例数据；接入 SQLite 后替换为仓储查询结果。
  final List<ItemPost> _allPosts = buildMockPosts();

  /// `null` 表示“全部”。
  PostType? _typeFilter;

  /// `null` 表示“全部分类”。
  ItemCategory? _categoryFilter;

  PostSortBy _sortBy = PostSortBy.newest;

  /// 当前筛选条件下的信息，已按 [_sortBy] 排序。
  List<ItemPost> get _visiblePosts {
    final List<ItemPost> posts = _allPosts
        .where(
          (ItemPost post) => post.matchesFilter(
            type: _typeFilter,
            category: _categoryFilter,
          ),
        )
        .toList();

    posts.sort((ItemPost a, ItemPost b) {
      final int result = b.createdAt.compareTo(a.createdAt);
      return _sortBy == PostSortBy.newest ? result : -result;
    });

    return posts;
  }

  bool get _hasFilter => _typeFilter != null || _categoryFilter != null;

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchPage()),
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
    final ThemeData theme = Theme.of(context);
    final List<ItemPost> posts = _visiblePosts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('校园失物招领'),
        actions: <Widget>[
          PopupMenuButton<PostSortBy>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: '排序方式',
            initialValue: _sortBy,
            onSelected: (PostSortBy value) => setState(() => _sortBy = value),
            itemBuilder: (BuildContext context) => PostSortBy.values
                .map(
                  (PostSortBy value) => PopupMenuItem<PostSortBy>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _SearchEntry(onTap: _openSearch),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _ChipFilter<PostType>(
                    options: const <PostType?>[
                      null,
                      PostType.lost,
                      PostType.found,
                    ],
                    selected: _typeFilter,
                    labelOf: (PostType? type) => type?.label ?? '全部',
                    onChanged: (PostType? value) =>
                        setState(() => _typeFilter = value),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '共 ${posts.length} 条',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: _ChipFilter<ItemCategory>(
              options: <ItemCategory?>[null, ...ItemCategory.values],
              selected: _categoryFilter,
              labelOf: (ItemCategory? category) => category?.label ?? '全部分类',
              onChanged: (ItemCategory? value) =>
                  setState(() => _categoryFilter = value),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: posts.isEmpty
                ? _EmptyResult(hasFilter: _hasFilter, onClear: _clearFilters)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: posts.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) =>
                        PostCard(post: posts[index]),
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

/// 一行横向滚动的单选筛选条，`null` 选项代表“全部”。
class _ChipFilter<T> extends StatelessWidget {
  const _ChipFilter({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T?> options;
  final T? selected;
  final String Function(T? option) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final T? option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labelOf(option)),
                selected: option == selected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (bool _) => onChanged(option),
              ),
            ),
        ],
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
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
