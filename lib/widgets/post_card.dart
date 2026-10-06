import 'package:flutter/material.dart';

import '../models/item_post.dart';
import '../utils/time_format.dart';

/// 首页列表中的单条信息卡片。
///
/// 展示：缩略图、失物 / 招领标签、状态、物品名称、描述摘要、地点与时间。
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final ItemPost post;

  /// 点击进入详细信息界面；详细信息界面（UI 事项 4）尚未实现，先留空。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool resolved = post.status == PostStatus.resolved;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumbnail(category: post.category, dimmed: resolved),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _TypeBadge(type: post.type),
                        if (resolved) ...<Widget>[
                          const SizedBox(width: 6),
                          _StatusBadge(text: post.type.resolvedLabel),
                        ],
                        const Spacer(),
                        Text(
                          formatRelativeTime(post.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: resolved ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (post.description != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        post.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _MetaLine(icon: Icons.place_outlined, text: post.location),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MetaLine(
                            icon: Icons.schedule_outlined,
                            text: formatEventTime(post.eventTime),
                          ),
                        ),
                        Text(
                          post.category.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 左侧缩略图。
///
/// TODO(image): 信息带图片时改用真实缩略图（本地文件），当前统一用分类图标占位。
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.category, required this.dimmed});

  final ItemCategory category;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        category.icon,
        size: 34,
        color: dimmed
            ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
            : scheme.primary,
      ),
    );
  }
}

/// “失物 / 招领”标签。
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final PostType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLost = type == PostType.lost;
    final Color background = isLost
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final Color foreground = isLost
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;

    return _Badge(
      text: type.label,
      background: background,
      foreground: foreground,
      icon: type.icon,
    );
  }
}

/// “已找到 / 已归还”状态标签。
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return _Badge(
      text: text,
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurfaceVariant,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 带前置图标的一行元信息（地点 / 时间）。
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
