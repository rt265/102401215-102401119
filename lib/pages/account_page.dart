import 'package:flutter/material.dart';

import '../data/user_store.dart';
import '../models/user_account.dart';
import '../utils/time_format.dart';
import '../widgets/account_form.dart';
import '../widgets/max_width_body.dart';
import 'settings_page.dart' show InfoRow;

/// 账户界面（次级界面）。
///
/// 设置界面「账户」那一行的落脚点（UI 事项 12 从设置页拆出来的子界面）：
/// 本机账户的查看、登记 / 修改资料、退出登录。
///
/// 本机账户只是一份「称呼 + 常用联系方式」，用于发布信息时自动带出联系方式，
/// 没有密码与实名（《Basic Info》不要求）。退出登录也只是清掉本机这一份登记，
/// 和「我的」界面上的退出是同一个动作——所以确认弹窗的文案两边一字不差。
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  /// 表单是否展开（未登记时是登记表单，已登记时是修改资料表单）。
  bool _formOpen = false;

  /// 保存账户：登记与修改资料走同一条路径（`UserStore.register` 会保留
  /// 首次登记时间）。
  Future<void> _save(String displayName, String contact) async {
    final UserStore users = UserScope.of(context);
    // 跨 await 用 context 会被 use_build_context_synchronously 拦下，
    // 而且 await 之后 context 确实可能已经失效，所以先取出来。
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    await users.register(displayName: displayName, contact: contact);
    if (!mounted) {
      return;
    }
    setState(() => _formOpen = false);
    messenger.showSnackBar(const SnackBar(content: Text('账户资料已保存')));
  }

  /// 退出登录：先确认，再清掉本机账户。
  Future<void> _signOut() async {
    final UserStore users = UserScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('account-sign-out-dialog'),
        title: const Text('退出登录？'),
        content: const Text('只会清掉本机登记的账户信息，已发布的信息不受影响。'),
        actions: <Widget>[
          TextButton(
            key: const Key('account-dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('account-dialog-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await users.signOut();
    messenger.showSnackBar(const SnackBar(content: Text('已退出登录')));
  }

  @override
  Widget build(BuildContext context) {
    final UserAccount? account = UserScope.of(context).account;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('account-back-button'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('账户'),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            Card(
              key: const Key('account-card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _formOpen
                    ? AccountForm(
                        keyPrefix: 'account',
                        initial: account,
                        title: account == null ? '登记账户' : '修改资料',
                        description: account == null
                            ? '只需要一个称呼和常用联系方式，不涉及密码与实名信息。'
                            : '改完在发布信息时会用新的联系方式。',
                        submitLabel: account == null ? '完成注册' : '保存修改',
                        onCancel: () => setState(() => _formOpen = false),
                        onSubmit: _save,
                      )
                    : _AccountSummary(
                        account: account,
                        onEdit: () => setState(() => _formOpen = true),
                        onSignOut: _signOut,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '账户信息只保存在本机，用于发布信息时自动带出联系方式；'
              '退出登录只清掉这份登记，已发布的信息不受影响。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账户信息（已登记）或登记入口（未登记）。
class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.account,
    required this.onEdit,
    required this.onSignOut,
  });

  final UserAccount? account;
  final VoidCallback onEdit;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final UserAccount? me = account;

    if (me == null) {
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
            child: Text(
              '还没有登记账户。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            key: const Key('account-register'),
            onPressed: onEdit,
            child: const Text('登记账户'),
          ),
        ],
      );
    }

    return Column(
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
                    key: const Key('account-name'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    me.contact,
                    key: const Key('account-contact'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoRow(
          label: '登记时间',
          value: formatDate(me.createdAt),
          valueKey: const Key('account-since'),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                key: const Key('account-edit'),
                onPressed: onEdit,
                child: const Text('修改资料'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                key: const Key('account-sign-out'),
                onPressed: onSignOut,
                child: const Text('退出登录'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
