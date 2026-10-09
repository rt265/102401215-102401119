import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/settings_repository.dart';
import 'package:lost_and_found/data/settings_store.dart';
import 'package:lost_and_found/data/user_store.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/theme/app_theme.dart';
import 'package:lost_and_found/theme/theme_seeds.dart';

/// 设置相关界面（设置 / 外观 / 账户 / 关于）测试共用的小工具。
///
/// UI 事项 12 把设置页拆成「目录页 + 三个子界面」之后，四个界面要搭同一套
/// 仓库环境、都要走「进子界面 → 操作 → 断言」，所以这些脚手架集中放这里。

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

/// 搭一整套界面环境：四个仓库（内存实现）+ 按当前设置派生主题的 [MaterialApp]。
///
/// 用 [AppTheme.light] / [AppTheme.dark] 而不是默认主题：外观界面测的是
/// 「换了种子色，整个应用的配色跟着变」，宿主主题必须是同一套派生规则，
/// 否则测出来的颜色和应用里看到的是两回事。
///
/// 三个 Scope 都在 `MaterialApp` **外面**（和 `LostAndFoundApp` 一样）：
/// 页面里 `Navigator.push` 出来的子界面在 Navigator / Overlay 之下（也就是
/// `MaterialApp` 之下），如果 Scope 放在 `home` 里面，子界面就找不到它们。
Widget buildSettingsHost({
  PostStore? posts,
  UserStore? users,
  SettingsStore? settings,
  required Widget home,
  bool dark = false,
}) {
  final SettingsStore store = settings ?? SettingsStore();

  return PostScope(
    store: posts ?? PostStore(initialPosts: <ItemPost>[]),
    child: UserScope(
      store: users ?? UserStore(),
      child: SettingsScope(
        store: store,
        child: ListenableBuilder(
          listenable: store,
          builder: (BuildContext context, Widget? child) => MaterialApp(
            theme: AppTheme.light(seed: store.themeSeed),
            darkTheme: AppTheme.dark(seed: store.themeSeed),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: home,
          ),
        ),
      ),
    ),
  );
}

/// 装一个能「推入某个界面」的最小宿主。
///
/// 测返回键必须让界面真的在导航栈上（`MaterialApp.home: 界面` 时 `pop()` 无处可去）。
Widget buildPushHost(Widget Function() page) {
  return buildSettingsHost(
    home: Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('open-page'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => page(),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
}

/// 界面一屏装不下时把测试窗口拉高，免得断言时机上还没建出来
/// （`ListView` 懒加载，屏幕外的分区不进 widget 树）。
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 先滚进可视区再点击：目标可能在折叠下方。
///
/// 关于「点完怎么推进时间」和「怎么发点击」，这里踩过两个坑，都写下来：
/// 1. 点完**不能**用 `pumpAndSettle`：页面里的主题色样本（[ThemeSample]）
///    带一个一直在转的进度圈，`pumpAndSettle` 会一直等到超时；
///    `pumpFrames` 也不行——它会把传进去的 widget 当成新的根重新挂整棵树
///    （`widget_tester.dart:739`），界面会被整个换掉。所以按固定步长手推几帧。
/// 2. 点击用 `startGesture` 手动「按下 → 停一帧 → 抬起」，不能用
///    `tester.tap` / `tapAt(坐标)`：带 tooltip 的返回键在后者下收不到点击
///    （界面纹丝不动，也不报「点空了」），换成手动手势立刻就正常了。
Future<void> tapAt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await pumpBriefly(tester);
  // 坐标要在动画落定之后再算：页面刚推出来时还在过场动画里，
  // 那时 `getCenter` 量到的是动画中途的位置，差几像素就点空了。
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(finder),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await pumpBriefly(tester);
}

/// 手推 700ms 的帧，绕开「永远在转的进度圈」让 `pumpAndSettle` 超时的问题。
///
/// 700ms 是按过场动画留的余量：`MaterialPageRoute` 的转场 300ms 上下，
/// 推入 / 弹出都走完，断言才不会落在「两个界面同时在树上」的中间态
/// （曾经因为只推 400ms，弹出动画还没结束，`findsNothing` 就失败了）。
Future<void> pumpBriefly(WidgetTester tester) async {
  for (int i = 0; i < 7; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> typeInto(WidgetTester tester, Key key, String text) async {
  final Finder field = find.byKey(key);
  await tester.ensureVisible(field);
  await pumpBriefly(tester);
  await tester.enterText(field, text);
  await pumpBriefly(tester);
}

/// 取某个 Key 上那行文字的内容。
String textAt(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// 预设种子色对应的 Key（与 `AppearancePage` 里的一致）。
Key seedSwatchKey(int value) =>
    Key('appearance-seed-${value.toRadixString(16)}');

/// 主题色网格里第 [index] 颗预设色的 Key。
Key presetSeedKey(int index) => seedSwatchKey(ThemeSeeds.presets[index].value);
