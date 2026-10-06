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
    final List<ItemPost> posts = _visiblePosts;

    return Scaffold(
      appBar: AppBar(title: const Text('校园失物招领')),
      body: Column(
        children: <Widget>[
          _SearchEntry(onTap: _openSearch),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _ChipFilter<PostType>(
              options: const <PostType?>[null, PostType.lost, PostType.found],
              selected: _typeFilter,
              labelOf: (PostType? type) => type?.label ?? '全部',
              onChanged: (PostType? value) =>
                  setState(() => _typeFilter = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _FilterMenuButton(
                category: _categoryFilter,
                sortBy: _sortBy,
                onCategoryChanged: (ItemCategory? value) =>
                    setState(() => _categoryFilter = value),
                onSortChanged: (PostSortBy value) =>
                    setState(() => _sortBy = value),
              ),
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

/// 筛选菜单里被选中的一项：要么改物品分类，要么改排序方式。
sealed class _FilterChoice {
  const _FilterChoice();
}

class _CategoryChoice extends _FilterChoice {
  const _CategoryChoice(this.category);

  /// `null` 代表“全部分类”。
  final ItemCategory? category;
}

class _SortChoice extends _FilterChoice {
  const _SortChoice(this.sortBy);

  final PostSortBy sortBy;
}

/// 筛选与排序入口。
///
/// 物品分类与排序方式收进同一个按钮，点击后展开成分组菜单；
/// 按钮上直接显示当前的“分类 · 排序”，不必展开就能看到筛选状态。
class _FilterMenuButton extends StatelessWidget {
  const _FilterMenuButton({
    required this.category,
    required this.sortBy,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  final ItemCategory? category;
  final PostSortBy sortBy;
  final ValueChanged<ItemCategory?> onCategoryChanged;
  final ValueChanged<PostSortBy> onSortChanged;

  /// 菜单里的分组标题，不可点击。
  static PopupMenuEntry<_FilterChoice> _header(String title) {
    return PopupMenuItem<_FilterChoice>(
      enabled: false,
      height: 34,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  void _onSelected(_FilterChoice choice) {
    switch (choice) {
      case _CategoryChoice(category: final ItemCategory? value):
        onCategoryChanged(value);
      case _SortChoice(sortBy: final PostSortBy value):
        onSortChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool active = category != null;
    final Color foreground = active ? scheme.primary : scheme.onSurfaceVariant;
    final String categoryLabel = category?.label ?? '全部分类';

    return PopupMenuButton<_FilterChoice>(
      key: const Key('home-filter-menu'),
      tooltip: '筛选与排序',
      position: PopupMenuPosition.under,
      onSelected: _onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_FilterChoice>>[
        _header('物品分类'),
        for (final ItemCategory? option in <ItemCategory?>[
          null,
          ...ItemCategory.values,
        ])
          PopupMenuItem<_FilterChoice>(
            key: Key('home-filter-category-${option?.name ?? 'all'}'),
            value: _CategoryChoice(option),
            child: _FilterMenuRow(
              icon: option?.icon ?? Icons.apps_rounded,
              label: option?.label ?? '全部分类',
              selected: option == category,
            ),
          ),
        const PopupMenuDivider(),
        _header('排序方式'),
        for (final PostSortBy option in PostSortBy.values)
          PopupMenuItem<_FilterChoice>(
            key: Key('home-filter-sort-${option.name}'),
            value: _SortChoice(option),
            child: _FilterMenuRow(
              icon: option == PostSortBy.newest
                  ? Icons.schedule_rounded
                  : Icons.history_rounded,
              label: option.label,
              selected: option == sortBy,
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.tune_rounded, size: 18, color: foreground),
            const SizedBox(width: 6),
            Text(
              '$categoryLabel · ${sortBy.label}',
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 20, color: foreground),
          ],
        ),
      ),
    );
  }
}

/// 筛选菜单里的一行：图标 + 文案 + 选中对勾。
class _FilterMenuRow extends StatelessWidget {
  const _FilterMenuRow({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 24,
          child: Icon(
            icon,
            size: 20,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 88),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.primary : null,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 20,
          child: selected
              ? Icon(Icons.check_rounded, size: 18, color: scheme.primary)
              : null,
        ),
      ],
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
