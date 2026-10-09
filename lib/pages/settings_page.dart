import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/post_store.dart';
import '../data/settings_store.dart';
import '../data/user_store.dart';
import '../models/item_post.dart';
import '../models/user_account.dart';
import '../utils/time_format.dart';
import '../widgets/account_form.dart';

/// 应用设置界面（次级界面）。
///
/// 对应《Basic Info》「UI」优先级列表的第 7 项：构建应用设置界面
/// （外观、账户、应用信息）。入口在「我的」界面右上角的齿轮。
///
/// 三个分区：
/// - **外观**：主题模式（跟随系统 / 浅色 / 深色），选完立刻生效并写进本地库；
/// - **账户**：本机账户的查看、登记 / 修改资料、退出登录；
/// - **应用信息**：应用名称、版本、数据存储说明、开源许可。
///
/// 这是单机应用，没有云端账户：这里的「账户」就是本机登记的那一份
/// （见 `UserStore`），「退出登录」只是清掉本机登记。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 账户表单是否展开（未登记时是登记表单，已登记时是修改资料表单）。
  bool _accountFormOpen = false;

  /// 保存账户：登记与修改资料走同一条路径（`UserStore.register` 会保留
  /// 首次登记时间）。
  Future<void> _saveAccount(String displayName, String contact) async {
    final UserStore users = UserScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    await users.register(displayName: displayName, contact: contact);
    if (!mounted) {
      return;
    }
    setState(() => _accountFormOpen = false);
    messenger.showSnackBar(const SnackBar(content: Text('账户资料已保存')));
  }

  /// 退出登录：先确认，再清掉本机账户。
  Future<void> _signOut() async {
    final UserStore users = UserScope.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('settings-sign-out-dialog'),
        title: const Text('退出登录？'),
        content: const Text('只会清掉本机登记的账户信息，已发布的信息不受影响。'),
        actions: <Widget>[
          TextButton(
            key: const Key('settings-dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('settings-dialog-confirm'),
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
    final SettingsStore settings = SettingsScope.of(context);
    final UserStore users = UserScope.of(context);
    final List<ItemPost> posts = PostScope.of(context).posts;
    final UserAccount? account = users.account;

    return Scaffold(
      appBar: AppBar(
        // 项目还没接 flutter_localizations，系统自带的返回按钮 tooltip 是英文，
        // 所以次级界面都自己给一个中文 tooltip 的返回键。
        leading: IconButton(
          key: const Key('settings-back-button'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          const _SectionTitle(key: Key('settings-section-theme'), title: '外观'),
          _ThemeCard(
            mode: settings.themeMode,
            onChanged: (ThemeMode mode) => settings.setThemeMode(mode),
          ),
          const SizedBox(height: 20),

          const _SectionTitle(
            key: Key('settings-section-account'),
            title: '账户',
          ),
          _AccountCard(
            account: account,
            formOpen: _accountFormOpen,
            onOpenForm: () => setState(() => _accountFormOpen = true),
            onCancelForm: () => setState(() => _accountFormOpen = false),
            onSubmit: _saveAccount,
            onSignOut: _signOut,
          ),
          const SizedBox(height: 20),

          const _SectionTitle(
            key: Key('settings-section-about'),
            title: '应用信息',
          ),
          _AboutCard(
            postCount: posts.length,
            myPostCount: posts.where((ItemPost post) => post.isMine).length,
          ),
        ],
      ),
    );
  }
}

/// 分区标题。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// 外观分区：主题模式。
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // 「跟随系统」时说明当前实际跟到的是哪一边。
    final bool systemIsDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final String hint = switch (mode) {
      ThemeMode.system => '当前跟随系统设置，本机为${systemIsDark ? '深色' : '浅色'}。',
      ThemeMode.light => '始终使用浅色主题。',
      ThemeMode.dark => '始终使用深色主题。',
    };

    return Card(
      key: const Key('settings-theme-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '主题模式',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // 只放文字不放图标：三段带图标在窄屏上会挤到换行。
            SegmentedButton<ThemeMode>(
              key: const Key('settings-theme-selector'),
              showSelectedIcon: false,
              segments: <ButtonSegment<ThemeMode>>[
                for (final _ThemeOption option in _themeOptions)
                  ButtonSegment<ThemeMode>(
                    value: option.mode,
                    label: Text(option.label),
                  ),
              ],
              selected: <ThemeMode>{mode},
              onSelectionChanged: (Set<ThemeMode> selection) =>
                  onChanged(selection.first),
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              key: const Key('settings-theme-hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个主题选项：模式 + 按钮上的文案。
class _ThemeOption {
  const _ThemeOption(this.mode, this.label);

  final ThemeMode mode;
  final String label;
}

/// 顺序就是按钮上的顺序：跟随系统、浅色、深色。
const List<_ThemeOption> _themeOptions = <_ThemeOption>[
  _ThemeOption(ThemeMode.system, '跟随系统'),
  _ThemeOption(ThemeMode.light, '浅色'),
  _ThemeOption(ThemeMode.dark, '深色'),
];

/// 账户分区：查看本机账户、登记 / 修改资料、退出登录。
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.formOpen,
    required this.onOpenForm,
    required this.onCancelForm,
    required this.onSubmit,
    required this.onSignOut,
  });

  final UserAccount? account;
  final bool formOpen;
  final VoidCallback onOpenForm;
  final VoidCallback onCancelForm;
  final void Function(String displayName, String contact) onSubmit;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final UserAccount? me = account;

    return Card(
      key: const Key('settings-account-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: formOpen
            ? AccountForm(
                keyPrefix: 'settings-account',
                initial: me,
                title: me == null ? '登记账户' : '修改资料',
                description: me == null
                    ? '只需要一个称呼和常用联系方式，不涉及密码与实名信息。'
                    : '改完在发布信息时会用新的联系方式。',
                submitLabel: me == null ? '完成注册' : '保存修改',
                onCancel: onCancelForm,
                onSubmit: onSubmit,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (me == null)
                    Row(
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
                          key: const Key('settings-account-register'),
                          onPressed: onOpenForm,
                          child: const Text('登记账户'),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _InfoRow(
                      label: '称呼',
                      value: me.displayName,
                      valueKey: const Key('settings-account-name'),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: '联系方式',
                      value: me.contact,
                      valueKey: const Key('settings-account-contact'),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: '登记时间',
                      value: formatDate(me.createdAt),
                      valueKey: const Key('settings-account-since'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('settings-account-edit'),
                            onPressed: onOpenForm,
                            child: const Text('修改资料'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            key: const Key('settings-sign-out'),
                            onPressed: onSignOut,
                            child: const Text('退出登录'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '账户信息只保存在本机，用于自动填充联系方式。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 应用信息分区：名称、版本、数据存储、开源许可。
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.postCount, required this.myPostCount});

  /// 本机库里的信息条数。
  final int postCount;

  /// 其中自己发布的条数。
  final int myPostCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      key: const Key('settings-about-card'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                const _InfoRow(label: '应用名称', value: AppInfo.name),
                const SizedBox(height: 8),
                _InfoRow(
                  label: '版本',
                  value: AppInfo.versionLabel,
                  valueKey: const Key('settings-version'),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: '本机数据',
                  value: '共 $postCount 条信息 · 我的发布 $myPostCount 条',
                  valueKey: const Key('settings-local-posts'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('settings-licenses'),
            leading: Icon(
              Icons.article_outlined,
              color: scheme.onSurfaceVariant,
            ),
            title: const Text('开源许可'),
            subtitle: const Text('应用所用开源组件'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.version,
              applicationLegalese: 'Copyright (c) 2026 rt265, Lqh5',
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行「标签：值」，值上可以挂 Key（测试按 Key 取值）。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, key: valueKey, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
