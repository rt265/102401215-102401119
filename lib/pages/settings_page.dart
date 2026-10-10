import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../data/user_store.dart';
import '../models/user_account.dart';
import '../theme/theme_seeds.dart';
import '../widgets/theme_sample.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'appearance_page.dart';

/// 应用设置界面（次级界面）。
///
/// 对应《Basic Info》「UI」优先级列表的第 7 项（构建应用设置界面）与第 12 项
/// （设置界面优化）。入口在「我的」界面右上角的齿轮。
///
/// **本页只当目录**：一屏列清有哪些设置、现在是什么状态，具体调什么在子界面里做。
/// 三个分区（外观 / 账户 / 应用信息）各自有落脚点：
/// - 外观 → [AppearancePage]（主题模式 + 主题色，第 11 项做的取色也在这里）；
/// - 账户 → [AccountPage]（登记 / 修改资料 / 退出登录）；
/// - 应用信息 → [AboutPage]（版本、数据存储说明、用户协议）。
///
/// 本机数据条数留在本页：它是「现在库里有多少东西import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../data/user_store.dart';
import '../models/user_account.dart';
import '../theme/theme_seeds.dart';
import '../widgets/max_width_body.dart';
import '../widgets/theme_sample.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'appearance_page.dart';

/// 应用设置界面（次级界面）。
///
/// 对应《Basic Info》「UI」优先级列表的第 7 项（构建应用设置界面）与第 12 项
/// （设置界面优化）。入口在「我的」界面右上角的齿轮。
///
/// **本页只当目录**：一屏列清有哪些设置、现在是什么状态，具体调什么在子界面里做。
/// 三个分区（外观 / 账户 / 应用信息）各自有落脚点：
/// - 外观 → [AppearancePage]（主题模式 + 主题色，第 11 项做的取色也在这里）；
/// - 账户 → [AccountPage]（登记 / 修改资料 / 退出登录）；
/// - 应用信息 → [AboutPage]（版本、数据存储说明、用户协议）。
///
/// 本机数据条数留在本页：它是「现在库里有多少东西」的状态，不是一项设置。
///
/// 这是单机应用，没有云端账户：这里的「账户」就是本机登记的那一份
/// （见 `UserStore`），「退出登录」只是清掉本机登记。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = SettingsScope.of(context);
    final UserAccount? account = UserScope.of(context).account;

    return Scaffold(
      appBar: AppBar(
        // 返回键沿用自绘的圆角箭头（顺带固定测试 Key）。接入 flutter_localizations 后
        // 系统 BackButton 的 tooltip 已是中文，这里保留自定义只为图标与 Key。
        leading: IconButton(
          key: const Key('settings-back-button'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('设置'),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            const SectionTitle(key: Key('settings-section-theme'), title: '外观'),
            _ThemeSummary(
              seed: settings.themeSeed,
              mode: settings.themeMode,
              onTap: () => _open(context, const AppearancePage()),
            ),
            const SizedBox(height: 20),

            const SectionTitle(
              key: Key('settings-section-account'),
              title: '账户',
            ),
            Card(
              key: const Key('settings-account-entry-card'),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const Key('settings-account-tile'),
                leading: Icon(_accountIcon(account)),
                title: Text(account == null ? '登记账户' : account.displayName),
                subtitle: Text(
                  account == null ? '还没有登记，登记后可自动填充联系方式。' : account.contact,
                  key: const Key('settings-account-summary'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, const AccountPage()),
              ),
            ),
            const SizedBox(height: 20),

            const SectionTitle(
              key: Key('settings-section-about'),
              title: '应用信息',
            ),
            Card(
              key: const Key('settings-about-card'),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  ListTile(
                    key: const Key('settings-about-tile'),
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('关于本应用'),
                    subtitle: const Text('版本、数据说明与用户协议'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(context, const AboutPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _accountIcon(UserAccount? account) =>
      account == null ? Icons.person_outline_rounded : Icons.person_rounded;

  static void _open(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));
  }
}

/// 外观分区：一句说清现在是什么主题，点进去调。
class _ThemeSummary extends StatelessWidget {
  const _ThemeSummary({
    required this.seed,
    required this.mode,
    required this.onTap,
  });

  final Color seed;
  final ThemeMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      key: const Key('settings-theme-card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('settings-theme-preview'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // 当前种子色的色点：改完颜色回到这一页，一眼能对上是哪颗。
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: seed,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ThemeSeeds.nameOf(seed)} · ${_modeLabel(mode)}',
                      key: const Key('settings-theme-hint'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              // 配色样本：不进去也看得出当前主色是什么样。
              IgnorePointer(child: ThemeSample(seed: seed, compact: true)),
            ],
          ),
        ),
      ),
    );
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
}

/// 分区标题。
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// 一行「标签：值」，值上可以挂 Key（测试按 Key 取值）。
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.valueKey});

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
」的状态，不是一项设置。
///
/// 这是单机应用，没有云端账户：这里的「账户」就是本机登记的那一份
/// （见 `UserStore`），「退出登录」只是清掉本机登记。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = SettingsScope.of(context);
    final UserAccount? account = UserScope.of(context).account;

    return Scaffold(
      appBar: AppBar(
        // 返回键沿用自绘的圆角箭头（顺带固定测试 Key）。接入 flutter_localizations 后
        // 系统 BackButton 的 tooltip 已是中文，这里保留自定义只为图标与 Key。
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
          const SectionTitle(key: Key('settings-section-theme'), title: '外观'),
          _ThemeSummary(
            seed: settings.themeSeed,
            mode: settings.themeMode,
            onTap: () => _open(context, const AppearancePage()),
          ),
          const SizedBox(height: 20),

          const SectionTitle(
            key: Key('settings-section-account'),
            title: '账户',
          ),
          Card(
            key: const Key('settings-account-entry-card'),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const Key('settings-account-tile'),
              leading: Icon(_accountIcon(account)),
              title: Text(account == null ? '登记账户' : account.displayName),
              subtitle: Text(
                account == null ? '还没有登记，登记后可自动填充联系方式。' : account.contact,
                key: const Key('settings-account-summary'),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(context, const AccountPage()),
            ),
          ),
          const SizedBox(height: 20),

          const SectionTitle(
            key: Key('settings-section-about'),
            title: '应用信息',
          ),
          Card(
            key: const Key('settings-about-card'),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                ListTile(
                  key: const Key('settings-about-tile'),
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('关于本应用'),
                  subtitle: const Text('版本、数据说明与用户协议'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(context, const AboutPage()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _accountIcon(UserAccount? account) =>
      account == null ? Icons.person_outline_rounded : Icons.person_rounded;

  static void _open(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));
  }
}

/// 外观分区：一句说清现在是什么主题，点进去调。
class _ThemeSummary extends StatelessWidget {
  const _ThemeSummary({
    required this.seed,
    required this.mode,
    required this.onTap,
  });

  final Color seed;
  final ThemeMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      key: const Key('settings-theme-card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('settings-theme-preview'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // 当前种子色的色点：改完颜色回到这一页，一眼能对上是哪颗。
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: seed,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ThemeSeeds.nameOf(seed)} · ${_modeLabel(mode)}',
                      key: const Key('settings-theme-hint'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              // 配色样本：不进去也看得出当前主色是什么样。
              IgnorePointer(child: ThemeSample(seed: seed, compact: true)),
            ],
          ),
        ),
      ),
    );
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
}

/// 分区标题。
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// 一行「标签：值」，值上可以挂 Key（测试按 Key 取值）。
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.valueKey});

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
