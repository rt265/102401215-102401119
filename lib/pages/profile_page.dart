import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../data/user_store.dart';
import '../models/item_post.dart';
import '../models/user_account.dart';
import '../widgets/coming_soon.dart';
import '../widgets/my_post_card.dart';

/// 我的界面（主界面）。
///
/// 对应《Basic Info》「Manage」：用户在这里登记账户，并管理自己发布的内容
/// （标记「已找到 / 已归还」、修改、删除）。
///
/// 只列出**本机用户自己发布的**信息（[ItemPost.isMine]）：示例数据不是用户发的，
/// 混进「我的发布」里会让「修改 / 删除」变得没有归属。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.onGoPublish, this.onGoHome});

  /// 「去发布一条」的动作，由外壳传入（切到发布标签）。
  final VoidCallback? onGoPublish;

  /// 从「我的发布」进入详细信息界面后，「回到首页」的动作，同样由外壳传入。
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // 依赖两个仓库：登记账户、管理信息后这里都会自动重建。
    final UserStore users = UserScope.of(context);
    final List<ItemPost> myPosts = PostScope.of(context)
        .posts
        .where((ItemPost post) => post.isMine)
        .toList();

    final int resolved = myPosts
        .where((ItemPost post) => post.status == PostStatus.resolved)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          AccountCard(account: users.account),
          const SizedBox(height: 20),

          Text('我的发布', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (myPosts.isEmpty)
            const ComingSoon(
              key: Key('profile-empty'),
              icon: Icons.article_outlined,
              title: '还没有发布过信息',
              description: '发布之后可以在这里标记「已找到 / 已归还」、修改或删除。',
            )
          else ...<Widget>[
            _StatsRow(
              published: myPosts.length,
              resolved: resolved,
              pending: myPosts.length - resolved,
            ),
            const SizedBox(height: 12),
            for (final ItemPost post in myPosts) ...<Widget>[
              MyPostCard(post: post, onGoHome: onGoHome),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 8),
          if (onGoPublish != null)
            Center(
              child: FilledButton.tonalIcon(
                key: const Key('profile-go-publish'),
                onPressed: onGoPublish,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('去发布一条'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 「我的发布」的统计：共几条、已完成几条、进行中几条。
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.published,
    required this.resolved,
    required this.pending,
  });

  final int published;
  final int resolved;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('profile-stats'),
      children: <Widget>[
        _StatTile(
          key: const Key('profile-stat-published'),
          value: published,
          label: '全部发布',
        ),
        _StatTile(
          key: const Key('profile-stat-resolved'),
          value: resolved,
          label: '已完成',
        ),
        _StatTile(
          key: const Key('profile-stat-pending'),
          value: pending,
          label: '进行中',
        ),
      ],
    );
  }
}

/// 统计卡里的一格。
class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: <Widget>[
              Text(
                '$value',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 账户卡片：已登记时展示称呼与联系方式，未登记时给出登记入口。
///
/// 「注册」在还没有后端与本地账户表的阶段就是**本机登记**：
/// 只记住称呼和常用联系方式，不做密码与实名（《Basic Info》明确不要求实名认证）。
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account});

  final UserAccount? account;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final UserAccount? me = account;

    return Card(
      key: const Key('profile-account-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: me == null
            ? const _RegisterPrompt()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              me.displayName,
                              key: const Key('profile-account-name'),
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '联系方式：${me.contact}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('profile-sign-out'),
                        tooltip: '退出登录',
                        onPressed: () => _signOut(context),
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '账户信息只保存在本机，用于发布时自动带出联系方式。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final UserStore users = UserScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('profile-sign-out-dialog'),
        title: const Text('退出登录？'),
        content: const Text('只会清掉本机登记的账户信息，已发布的信息不受影响。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('profile-confirm-action'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    users.signOut();
    messenger.showSnackBar(const SnackBar(content: Text('已退出登录')));
  }
}

/// 未登记账户时的入口和执行登记的展开表单。
class _RegisterPrompt extends StatefulWidget {
  const _RegisterPrompt();

  @override
  State<_RegisterPrompt> createState() => _RegisterPromptState();
}

class _RegisterPromptState extends State<_RegisterPrompt> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _editing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    UserScope.of(context).register(
      displayName: _nameController.text,
      contact: _contactController.text,
    );
    // 登记成功后这张卡片会换成账户信息，不需要再收起表单。
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (!_editing) {
      return Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.person_outline_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '还没有账户',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '登记称呼和联系方式，发布时就不用反复填写。',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            key: const Key('profile-register-button'),
            onPressed: () => setState(() => _editing = true),
            child: const Text('注册'),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '登记账户',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '只需要一个称呼和常用联系方式，不涉及密码与实名信息。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profile-name-field'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '称呼',
              hintText: '例如：张同学',
              border: OutlineInputBorder(),
            ),
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? '请填写称呼' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profile-contact-field'),
            controller: _contactController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '常用联系方式',
              hintText: '例如：手机 138****6621',
              helperText: '发布信息时自动带出，之后可以修改',
              border: OutlineInputBorder(),
            ),
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? '请填写联系方式' : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                key: const Key('profile-register-cancel'),
                onPressed: () => setState(() => _editing = false),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('profile-register-submit'),
                onPressed: _submit,
                child: const Text('完成注册'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
