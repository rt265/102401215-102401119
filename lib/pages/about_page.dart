import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/post_store.dart';
import '../widgets/max_width_body.dart';
import 'settings_page.dart' show InfoRow, SectionTitle;

/// 关于界面（次级界面）。
///
/// 对应《Basic Info》「Setting → 应用信息」里「用户协议、关于」要求
/// 「放在次级界面」的那一层（UI 事项 12 从设置页拆出来）。
///
/// 本应用是单机应用：没有服务端、没有账号体系，数据全在本机 SQLite 里。
/// 所以「关于」要讲清的第一件事不是团队与版权，而是**数据在哪、怎么没的**
/// （卸载即清除），其次才是用户协议（即所用开源组件的许可条款）。
///
/// **应用名称 / 版本 / 数据存放位置都只在本页出现**：设置页那张卡不再重复这些分条信息，
/// 那里只留一个进本页的入口（UI 事项 12 的后续调整）。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int postCount = PostScope.of(context).posts.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('about-back-button'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('关于'),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            // 应用标识：图标 + 名称 + 版本，一眼看清自己在用哪一版。
            Column(
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 36,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppInfo.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppInfo.versionLabel,
                  key: const Key('about-version'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SectionTitle(title: '介绍'),
            Card(
              key: const Key('about-card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '基于 Flutter 的简洁失物招领交流应用',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const SectionTitle(title: '本机数据'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InfoRow(label: '存放模式', value: '本机应用目录的 SQLite 数据库'),
                    const SizedBox(height: 8),
                    InfoRow(
                      label: '当前数量',
                      value: '$postCount 条信息',
                      valueKey: const Key('about-storage'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '卸载应用或在系统设置里清除应用数据，这些内容会一并消失，'
                      '本应用没有云端备份，请注意自行备份',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 用户协议就用 Flutter 自带的开源许可页：本应用没有后端与账号体系，
            // 没有需要用户单独同意的服务条款，真正约束双方的是所用开源许可以及底部这句署名。
            // 与其编一份没人看的协议文本，不如直接把许可页给出来——它也是应用里唯一
            // 「用户应当知道并且能被约束」的条款来源。
            const SectionTitle(title: '用户协议'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const Key('about-licenses'),
                leading: Icon(
                  Icons.description_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                title: const Text('用户协议与开源许可'),
                subtitle: const Text('本应用所用开源组件及其许可条款'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showLicenses(context),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Copyright (c) 2026 rt265, Lqh5',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: AppInfo.name,
      applicationVersion: AppInfo.version,
      applicationLegalese: 'Copyright (c) 2026 rt265, Lqh5',
    );
  }
}
