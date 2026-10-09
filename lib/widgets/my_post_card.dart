import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../models/item_post.dart';
import '../pages/post_detail_page.dart';
import '../pages/post_edit_page.dart';
import 'post_card.dart';

/// 「我的」界面里的一张已发布信息卡片：内容与首页卡片一致，底下多一排管理操作。
///
/// 三项管理操作对应《Basic Info》「Manage」的三条要求：
/// 标记「已找到 / 已归还」、修改发布内容、删除发布。
///
/// 卡片本体仍可点进详细信息界面（UI 事项 4），与首页卡片行为一致。
class MyPostCard extends StatelessWidget {
  const MyPostCard({super.key, required this.post, this.onGoHome});

  final ItemPost post;

  /// 详细信息界面里「回到首页」的动作，由外壳经「我的」界面传进来。
  final VoidCallback? onGoHome;

  bool get _resolved => post.status == PostStatus.resolved;

  /// 标记完成后显示的状态文案：失物是「已找到」，招领是「已归还」。
  String get _resolveLabel => post.type.resolvedLabel;

  /// 标记 / 改回时确认弹窗里的动作说明。
  static const String _statusHint = '标成已完成的信息在首页会显示为已完成，随时可以改回来。';

  /// 改回进行中之后显示的状态文案。
  static final String _pendingLabel = PostStatus.pending.label;

  /// 查看详细信息（与首页卡片行为一致）。
  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(postId: post.id, onGoHome: onGoHome),
      ),
    );
  }

  /// 编辑：进入编辑界面，保存后回到这里。
  Future<void> _edit(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final ItemPost? updated = await navigator.push<ItemPost>(
      MaterialPageRoute<ItemPost>(builder: (_) => PostEditPage(post: post)),
    );
    if (updated == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('“${updated.title}”已更新')));
  }

  /// 标记已找到 / 已归还（先确认，避免误点）。
  Future<void> _resolve(BuildContext context) async {
    final PostStore store = PostScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool confirmed = await _confirm(
      context,
      key: const Key('profile-resolve-dialog'),
      title: '标记「$_resolveLabel」？',
      message: _statusHint,
      confirmLabel: '标记',
    );
    if (!confirmed) {
      return;
    }

    store.updatePost(post.copyWith(status: PostStatus.resolved));
    messenger.showSnackBar(SnackBar(content: Text('已标记为「$_resolveLabel」')));
  }

  /// 改回「进行中」——标记错了、物品又丢了，都得能退回来。
  Future<void> _revert(BuildContext context) async {
    final PostStore store = PostScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool confirmed = await _confirm(
      context,
      key: const Key('profile-revert-dialog'),
      title: '改回「$_pendingLabel」？',
      message: '这条信息在首页会重新显示为「$_pendingLabel」。',
      confirmLabel: '改回',
    );
    if (!confirmed) {
      return;
    }

    store.updatePost(post.copyWith(status: PostStatus.pending));
    messenger.showSnackBar(SnackBar(content: Text('已改回「$_pendingLabel」')));
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
    messenger.showSnackBar(SnackBar(content: Text('“${post.title}”已删除')));
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
                    foregroundColor: Theme.of(dialogContext)
                        .colorScheme
                        .onError,
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
          PostCard(post: post, onTap: () => _openDetail(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            // 用 Row 而不是 Wrap：底下这排是「一个状态 + 两个图标按钮」，
            // 交给 Wrap 各排各的，状态文字和按钮图标就不在一条水平线上了。
            child: Row(
              children: <Widget>[
                // 状态占满左侧，右对齐到图标按钮那一列。
                if (_resolved)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusChip(
                        key: Key('profile-status-${post.id}'),
                        icon: Icons.task_alt_rounded,
                        label: _resolveLabel,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (_resolved)
                  TextButton.icon(
                    key: Key('profile-revert-${post.id}'),
                    onPressed: () => _revert(context),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: Text('改回$_pendingLabel'),
                  )
                else
                  TextButton.icon(
                    key: Key('profile-resolve-${post.id}'),
                    onPressed: () => _resolve(context),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: Text('标记$_resolveLabel'),
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

/// 已完成状态的「结果」展示：一个对勾 + 状态文案。
///
/// 做成图标 + 文字的小块，是为了和同一排的图标按钮**视觉对齐**——
/// 这里原本只有一行裸文字，和右边的图标按钮凑在一起就显得不在一条线上。
class _StatusChip extends StatelessWidget {
  const _StatusChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      // 对勾与文字按中线对齐，字再大也不会掉下去。
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
