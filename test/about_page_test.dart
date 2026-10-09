import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/app_info.dart';
import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/pages/about_page.dart';

import 'helpers/page_harness.dart';

ItemPost buildPost(String id) {
  final DateTime now = DateTime(2026, 5, 1, 12);
  return ItemPost(
    id: id,
    type: PostType.lost,
    title: '黑色折叠伞',
    category: ItemCategory.daily,
    location: '图书馆一楼大厅',
    eventTime: now.subtract(const Duration(hours: 3)),
    contact: '微信 umbrella_zhang',
    createdAt: now.subtract(const Duration(hours: 1)),
    status: PostStatus.pending,
  );
}

/// 只装关于界面（UI 事项 12 从设置页拆出来的子界面）。
Widget buildAboutPage({PostStore? posts}) {
  return buildSettingsHost(posts: posts, home: const AboutPage());
}

void main() {
  testWidgets('关于界面展示应用名称、版本与数据说明', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildAboutPage());

    expect(find.text('关于'), findsOneWidget);
    expect(find.byKey(const Key('about-back-button')), findsOneWidget);
    expect(find.byKey(const Key('about-card')), findsOneWidget);
    // 名称在标题处出现一次，版本单独一行。
    expect(find.text(AppInfo.name), findsOneWidget);
    expect(textAt(tester, const Key('about-version')), AppInfo.versionLabel);
    expect(find.text('本机数据'), findsOneWidget);
    expect(textAt(tester, const Key('about-storage')), '0 条信息');
  });

  testWidgets('关于界面里的信息条数跟着本机数据走', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      buildAboutPage(
        posts: PostStore(
          initialPosts: <ItemPost>[buildPost('a'), buildPost('b')],
        ),
      ),
    );

    expect(textAt(tester, const Key('about-storage')), '2 条信息');
  });

  // 用户协议就用 Flutter 自带的开源许可页，没有另写一份协议文本。
  testWidgets('用户协议入口能打开许可页', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildAboutPage());

    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('用户协议与开源许可'), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('about-licenses')));
    // showLicensePage 推入的是 Flutter 自带的许可页。
    expect(find.byType(LicensePage), findsOneWidget);
    // 署名在本页底部与许可页上各有一处。
    expect(find.text('Copyright (c) 2026 rt265, Lqh5'), findsWidgets);
  });

  testWidgets('返回键能关掉关于界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildPushHost(() => const AboutPage()));

    await tapAt(tester, find.byKey(const Key('open-page')));
    expect(find.byType(AboutPage), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('about-back-button')));
    expect(find.byType(AboutPage), findsNothing);
  });
}
