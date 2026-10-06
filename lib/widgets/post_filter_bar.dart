import 'package:flutter/material.dart';

import '../models/item_post.dart';
import '../models/post_query.dart';

/// 信息列表的筛选条：类型 chip 条 + 「分类 · 排序」菜单。
///
/// 首页与搜索界面共用同一套筛选——两处的可选项、文案、判定必须一致，
/// 所以控件只留这一份（判定在 [PostQuery]，这里是它的样子）。
///
/// [keyPrefix] 决定控件 Key：`<prefix>-menu`、`<prefix>-category-<name|all>`、
/// `<prefix>-sort-<name>`。首页与搜索界面各用一个前缀，测试里定位互不干扰。
class PostFilterBar extends StatelessWidget {
  const PostFilterBar({
    super.key,
    required this.typeFilter,
    required this.categoryFilter,
    required this.sortBy,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    this.keyPrefix = 'post-filter',
  });

  /// `null` 表示“全部”。
  final PostType? typeFilter;

  /// `null` 表示“全部分类”。
  final ItemCategory? categoryFilter;

  final PostSortBy sortBy;

  final ValueChanged<PostType?> onTypeChanged;
  final ValueChanged<ItemCategory?> onCategoryChanged;
  final ValueChanged<PostSortBy> onSortChanged;

  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ChipFilter<PostType>(
          options: const <PostType?>[null, PostType.lost, PostType.found],
          selected: typeFilter,
          labelOf: (PostType? type) => type?.label ?? '全部',
          onChanged: onTypeChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: _FilterMenuButton(
            keyPrefix: keyPrefix,
            category: categoryFilter,
            sortBy: sortBy,
            onCategoryChanged: onCategoryChanged,
            onSortChanged: onSortChanged,
          ),
        ),
      ],
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
    required this.keyPrefix,
    required this.category,
    required this.sortBy,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  final String keyPrefix;
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
      key: Key('$keyPrefix-menu'),
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
            key: Key('$keyPrefix-category-${option?.name ?? 'all'}'),
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
            key: Key('$keyPrefix-sort-${option.name}'),
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
