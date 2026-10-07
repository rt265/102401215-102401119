import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/app_info.dart';
import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/settings_repository.dart';
import 'package:lost_and_found/data/settings_store.dart';
import 'package:lost_and_found/data/user_store.dart';
import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/models/user_account.dart';
import 'package:lost_and_found/pages/settings_page.dart';
import 'package:lost_and_found/utils/time_format.dart';

const String _name = '张同学';
const String _contact = '微信 umbrella_zhang';

/// 记下每次写入的设置仓库：用来确认「改了设置真的落库了」。
class RecordingSettingsRepository implements SettingsRepository {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async {
    values[name] = value;
  }
}

/// 造一条信息（默认不是自己发的）。
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

/// 只装设置界面：不经过「我的」界面，测试用起来更直接。
Widget buildSettings({
  PostStore? posts,
  UserStore? users,
  SettingsStore? settings,
}) {
  return PostScope(
    store: posts ?? PostStore(initialPosts: <ItemPost>[]),
    child: UserScope(
      store: users ?? UserStore(),
      child: SettingsScope(
        store: settings ?? SettingsStore(),
        child: const MaterialApp(home: SettingsPage()),
      ),
    ),
  );
}

/// 装一个能「推入设置界面」的最小宿主：测返回键要用真正在栈上的次级界面。
Widget buildSettingsHost() {
  return PostScope(
    store: PostStore(initialPosts: <ItemPost>[]),
    child: UserScope(
      store: UserStore(),
      child: SettingsScope(
        store: SettingsStore(),
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open-settings'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const SettingsPage(),
                    ),
                  ),
                  child: const Text('打开设置'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 设置页一屏装不下（三个分区），把测试窗口拉高，免得断言时机上还没建出来。
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> tapAt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, Key key, String text) async {
  final Finder field = find.byKey(key);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// 取某个 Key 上那行文字的内容。
String textAt(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  testWidgets('设置界面展示外观、账户与应用信息三个分区', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildSettings());

    expect(find.text('设置'), findsOneWidget);
    expect(find.byKey(const Key('settings-back-button')), findsOneWidget);

    expect(find.byKey(const Key('settings-section-theme')), findsOneWidget);
    expect(find.byKey(const Key('settings-theme-card')), findsOneWidget);
    expect(find.byKey(const Key('settings-theme-selector')), findsOneWidget);

    expect(find.byKey(const Key('settings-section-account')), findsOneWidget);
    expect(find.byKey(const Key('settings-account-card')), findsOneWidget);

    expect(find.byKey(const Key('settings-section-about')), findsOneWidget);
    expect(find.byKey(const Key('settings-about-card')), findsOneWidget);
  });

  testWidgets('应用信息展示应用名称、版本、存储说明与本机数据条数', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      buildSettings(
        posts: PostStore(
          initialPosts: <ItemPost>[
            buildPost(id: 'local-1', isMine: true),
            buildPost(id: 'local-2'),
          ],
        ),
      ),
    );

    expect(textAt(tester, const Key('settings-version')), AppInfo.versionLabel);
    expect(textAt(tester, const Key('settings-storage')), '本机 SQLite，不上传服务器');
    expect(
      textAt(tester, const Key('settings-local-posts')),
      '共 2 条信息 · 我的发布 1 条',
    );
    // 应用名称在「应用名称」那一行上单独出现一次。
    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.byKey(const Key('settings-licenses')), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
  });

  testWidgets('主题提示说明当前是跟随系统还是固定', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      buildSettings(settings: SettingsStore(themeMode: ThemeMode.light)),
    );
    expect(textAt(tester, const Key('settings-theme-hint')), '始终使用浅色主题。');

    await tester.pumpWidget(
      buildSettings(settings: SettingsStore(themeMode: ThemeMode.dark)),
    );
    expect(textAt(tester, const Key('settings-theme-hint')), '始终使用深色主题。');

    await tester.pumpWidget(buildSettings());
    // 测试环境的系统外观是浅色。
    expect(
      textAt(tester, const Key('settings-theme-hint')),
      '当前跟随系统设置，本机为浅色。',
    );
  });

  testWidgets('从「我的」进入设置，切深色后立刻换肤并落库', (WidgetTester tester) async {
    useTallScreen(tester);
    final RecordingSettingsRepository repository =
        RecordingSettingsRepository();
    final SettingsStore settings = SettingsStore(repository: repository);

    await tester.pumpWidget(LostAndFoundApp(settingsStore: settings));
    await openTab(tester, '我的');
    await tapAt(tester, find.byKey(const Key('profile-settings-button')));
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-theme-selector')),
        matching: find.text('深色'),
      ),
    );
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
    expect(repository.values[SettingNames.themeMode], 'dark');
    expect(textAt(tester, const Key('settings-theme-hint')), '始终使用深色主题。');
    // 真的换肤了：设置界面自己就是深色的。
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('返回键能关掉设置界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildSettingsHost());

    await tapAt(tester, find.byKey(const Key('open-settings')));
    expect(find.byType(SettingsPage), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('settings-back-button')));
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
  });

  testWidgets('未登记账户时可以在这里登记，两项都必填', (WidgetTester tester) async {
    useTallScreen(tester);
    final UserStore users = UserStore();
    await tester.pumpWidget(buildSettings(users: users));

    expect(find.byKey(const Key('settings-account-register')), findsOneWidget);
    await tapAt(tester, find.byKey(const Key('settings-account-register')));
    expect(find.byKey(const Key('settings-account-name-field')), findsOneWidget);

    // 两项都是必填，先空提交一次。
    await tapAt(tester, find.byKey(const Key('settings-account-submit')));
    expect(find.text('请填写称呼'), findsOneWidget);
    expect(find.text('请填写联系方式'), findsOneWidget);

    await typeInto(tester, const Key('settings-account-name-field'), _name);
    await typeInto(tester, const Key('settings-account-contact-field'), _contact);
    await tapAt(tester, find.byKey(const Key('settings-account-submit')));

    expect(users.account?.displayName, _name);
    expect(users.account?.contact, _contact);
    // 存完收起表单，卡片上直接变成账户信息。
    expect(find.byKey(const Key('settings-account-name-field')), findsNothing);
    expect(textAt(tester, const Key('settings-account-name')), _name);
    expect(textAt(tester, const Key('settings-account-contact')), _contact);
    expect(find.text('账户资料已保存'), findsOneWidget);
  });

  testWidgets('已登记账户时可以在这里修改资料，首次登记时间不变', (WidgetTester tester) async {
    useTallScreen(tester);
    final DateTime since = DateTime(2026, 5, 1, 12);
    final UserStore users = UserStore(
      initialAccount: UserAccount(
        displayName: _name,
        contact: _contact,
        createdAt: since,
      ),
    );
    await tester.pumpWidget(buildSettings(users: users));

    expect(textAt(tester, const Key('settings-account-name')), _name);
    expect(textAt(tester, const Key('settings-account-since')), formatDate(since));

    await tapAt(tester, find.byKey(const Key('settings-account-edit')));
    expect(find.text('修改资料'), findsOneWidget);
    // 表单回填了原来的值。
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('settings-account-name-field')),
          )
          .controller
          ?.text,
      _name,
    );

    await typeInto(tester, const Key('settings-account-name-field'), '李同学');
    await tapAt(tester, find.byKey(const Key('settings-account-submit')));

    expect(users.account?.displayName, '李同学');
    expect(users.account?.contact, _contact);
    expect(users.account?.createdAt, since);
    expect(textAt(tester, const Key('settings-account-name')), '李同学');
  });

  testWidgets('退出登录要先确认，确认后回到未登记状态', (WidgetTester tester) async {
    useTallScreen(tester);
    final UserStore users = UserStore(
      initialAccount: UserAccount(
        displayName: _name,
        contact: _contact,
        createdAt: DateTime(2026, 5, 1, 12),
      ),
    );
    await tester.pumpWidget(buildSettings(users: users));

    await tapAt(tester, find.byKey(const Key('settings-sign-out')));
    expect(find.byKey(const Key('settings-sign-out-dialog')), findsOneWidget);

    // 先取消：账户还在。
    await tapAt(tester, find.byKey(const Key('settings-dialog-cancel')));
    expect(users.account, isNotNull);
    expect(find.byKey(const Key('settings-sign-out-dialog')), findsNothing);

    await tapAt(tester, find.byKey(const Key('settings-sign-out')));
    await tapAt(tester, find.byKey(const Key('settings-dialog-confirm')));

    expect(users.account, isNull);
    expect(find.byKey(const Key('settings-account-register')), findsOneWidget);
    expect(find.text('已退出登录'), findsOneWidget);
  });
}
