import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../models/item_post.dart';
import '../pages/post_edit_page.dart';
import '../utils/time_format.dart';
import 'post_card.dart';

/// 「我的」界面里的一张已发布信息卡片：内容与首页卡片一致，底下多一排管理操作。
///
/// 三项管理操作对应《Basic Info》「Manage」的三条要求：
/// 标记「已找到 / 已归还」、修改发布内容、删除发布。
class MyPostCard extends StatelessWidget {
  const MyPostCard({super.key, required this.post});

  final ItemPost post;

  bool get _resolved => post.status == PostStatus.resolved;

  /// 标记完成后显示的状态文案：失物是「已找到」，招领是「已归还」。
  String get _resolveLabel => post.type.resolvedLabel;

  /// 编辑：进入编辑界面，保存后回到这里。
  Future<void> _edit(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final ItemPost? updated = await navigator.push<ItemPost>(
      MaterialPageRoute<ItemPost>(
        builder: (_) => PostEditPage(post: post),
      ),
    );
    if (updated == null) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('“${updated.title}”已更新')),
    );
  }

  /// 标记已找到 / 已归还（先确认，避免误点）。
  Future<void> _resolve(BuildContext context) async {
    final PostStore store = PostScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool confirmed = await _confirm(
      context,
      key: const Key('profile-resolve-dialog'),
      title: '标记「$_resolveLabel」？',
      message: '标记后这条信息在首页会显示为已完成，你仍然可以改回来或删除它。',
      confirmLabel: '标记$_resolveLabel',
    );
    if (!confirmed) {
      return;
    }

    store.updatePost(post.copyWith(status: PostStatus.resolved));
    messenger.showSnackBar(
      SnackBar(content: Text('已标记为「$_resolveLabel」')),
    );
  }

  /// 删除（先确认，避免误删）。
  Future<void> _delete(BuildContext context) async {
    final PostStore store = PostScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool confirmed = await _confirm(
      context,
      key: const Key('profile-delete-dialog'),
      title: '删除这条信息？',
      message: '“${post.title}”将被移除，删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }

    store.removePost(post.id);
    messenger.showSnackBar(
      SnackBar(content: Text('“${post.title}”已删除')),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required Key key,
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: key,
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('profile-confirm-action'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      key: Key('profile-post-${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PostCard(post: post),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                if (!_resolved)
                  TextButton.icon(
                    key: Key('profile-resolve-${post.id}'),
                    onPressed: () => _resolve(context),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: Text('标记$_resolveLabel'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      '$_resolveLabel · ${formatRelativeTime(post.createdAt)}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                IconButton(
                  key: Key('profile-edit-${post.id}'),
                  tooltip: '修改',
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('profile-delete-${post.id}'),
                  tooltip: '删除',
                  onPressed: () => _delete(context),
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
