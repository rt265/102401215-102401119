import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/app_info.dart';
import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/settings_store.dart';
import 'package:lost_and_found/data/user_store.dart';
import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/models/user_account.dart';
import 'package:lost_and_found/pages/about_page.dart';
import 'package:lost_and_found/pages/account_page.dart';
import 'package:lost_and_found/pages/appearance_page.dart';
import 'package:lost_and_found/pages/settings_page.dart'
    show InfoRow, SettingsPage;
import 'package:lost_and_found/theme/theme_seeds.dart';

import 'helpers/page_harness.dart';

const String _name = '张同学';
const String _contact = '微信 umbrella_zhang';

ItemPost buildPost({required String id, bool isMine = false}) {
  final DateTime now = DateTime(2026, 5, 1, 12);
  return ItemPost(
    id: id,
    type: PostType.lost,
    title: '黑色折叠伞',
    category: ItemCategory.daily,
    location: '图书馆一楼大厅',
    eventTime: now.subtract(const Duration(hours: 3)),
    contact: _contact,
    createdAt: now.subtract(const Duration(hours: 1)),
    status: PostStatus.pending,
    isMine: isMine,
  );
}

/// 只装设置界面：不经过「我的」，测试用起来更直接。
Widget buildSettingsPage({
  PostStore? posts,
  UserStore? users,
  SettingsStore? settings,
}) {
  return buildSettingsHost(
    posts: posts,
    users: users,
    settings: settings,
    home: const SettingsPage(),
  );
}

void main() {
  // UI 事项 12 之后，设置界面不再是「所有设置都在这一页」，而是目录页：
  // 分区齐全，每一项都能进到自己的子界面。
  testWidgets('设置界面列出外观、账户与应用信息三个分区', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildSettingsPage());

    expect(find.text('设置'), findsOneWidget);
    expect(find.byKey(const Key('settings-back-button')), findsOneWidget);

    expect(find.byKey(const Key('settings-section-theme')), findsOneWidget);
    expect(find.byKey(const Key('settings-theme-card')), findsOneWidget);

    expect(find.byKey(const Key('settings-section-account')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-account-entry-card')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('settings-section-about')), findsOneWidget);
    expect(find.byKey(const Key('settings-about-card')), findsOneWidget);
    expect(find.byKey(const Key('settings-about-tile')), findsOneWidget);
  });

  // 目录页只回答「有什么可以进去」，不回答「里面是什么」：
  // 应用名称、版本这些分条信息都在「关于」里，设置页上不再重复一遍。
  testWidgets('应用信息分区只给入口，不重复关于界面的分条信息', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      buildSettingsPage(
        posts: PostStore(
          initialPosts: <ItemPost>[
            buildPost(id: 'local-1', isMine: true),
            buildPost(id: 'local-2'),
          ],
        ),
      ),
    );

    expect(find.widgetWithText(ListTile, '关于本应用'), findsOneWidget);
    expect(find.text('版本、数据说明与用户协议'), findsOneWidget);
    // 分条信息（InfoRow）不该再出现在目录页上。
    expect(find.byType(InfoRow), findsNothing);
    expect(find.byKey(const Key('settings-version')), findsNothing);
    expect(find.text(AppInfo.versionLabel), findsNothing);
  });

  // 目录页上那一行要把「现在是什么主题、什么颜色」说清，否则每次都得点进去看。
  testWidgets('外观摘要显示当前主题色与主题模式', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      buildSettingsPage(
        settings: SettingsStore(
          themeMode: ThemeMode.dark,
          themeSeed: ThemeSeeds.presets[2].color,
        ),
      ),
    );

    expect(
      textAt(tester, const Key('settings-theme-hint')),
      '${ThemeSeeds.presets[2].name} · 深色',
    );
    expect(find.byKey(const Key('settings-theme-preview')), findsOneWidget);
  });

  testWidgets('账户分区摘要跟着登记状态变', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildSettingsPage());
    expect(
      textAt(tester, const Key('settings-account-summary')),
      '还没有登记，登记后可自动填充联系方式。',
    );

    await tester.pumpWidget(
      buildSettingsPage(
        users: UserStore(
          initialAccount: UserAccount(
            displayName: _name,
            contact: _contact,
            createdAt: DateTime(2026, 5, 1, 12),
          ),
        ),
      ),
    );
    expect(find.text(_name), findsOneWidget);
    expect(textAt(tester, const Key('settings-account-summary')), _contact);
  });

  testWidgets('点外观摘要进外观界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildSettingsPage());

    await tapAt(tester, find.byKey(const Key('settings-theme-preview')));
    expect(find.byType(AppearancePage), findsOneWidget);
  });

  testWidgets('点账户分区进账户界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildSettingsPage());

    await tapAt(tester, find.byKey(const Key('settings-account-tile')));
    expect(find.byType(AccountPage), findsOneWidget);
  });

  testWidgets('点关于本应用进关于界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildSettingsPage());

    await tapAt(tester, find.byKey(const Key('settings-about-tile')));
    expect(find.byType(AboutPage), findsOneWidget);
  });

  testWidgets('返回键能关掉设置界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      buildPushHost(() => const SettingsPage()),
    );

    await tapAt(tester, find.byKey(const Key('open-page')));
    expect(find.byType(SettingsPage), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('settings-back-button')));
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byKey(const Key('open-page')), findsOneWidget);
  });

  // 端到端：从「我的」进设置 → 进外观 → 切深色，整棵树立刻换肤并落库。
  testWidgets('从「我的」进外观切深色，立刻换肤并落库', (WidgetTester tester) async {
    useTallScreen(tester);
    final RecordingSettingsRepository repository =
        RecordingSettingsRepository();
    final SettingsStore settings = SettingsStore(repository: repository);

    await tester.pumpWidget(LostAndFoundApp(settingsStore: settings));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('我的'),
      ),
    );
    await pumpBriefly(tester);
    await tapAt(tester, find.byKey(const Key('profile-settings-button')));
    expect(find.byType(SettingsPage), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('settings-theme-preview')));
    expect(find.byType(AppearancePage), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('appearance-theme-selector')),
        matching: find.text('深色'),
      ),
    );
    await pumpBriefly(tester);

    expect(settings.themeMode, ThemeMode.dark);
    expect(repository.values[SettingNames.themeMode], 'dark');
    expect(
      textAt(tester, const Key('appearance-theme-hint')),
      '始终使用深色主题。',
    );
    // 真的换肤了：外观界面自己就是深色的。
    expect(
      Theme.of(tester.element(find.byType(AppearancePage))).brightness,
      Brightness.dark,
    );
  });
}
