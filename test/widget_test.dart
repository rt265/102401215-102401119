import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/mock_posts.dart';
import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/widgets/post_card.dart';

void main() {
  testWidgets('首页展示标题、搜索栏、筛选器与信息卡片', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    expect(find.text('校园失物招领'), findsOneWidget);
    expect(find.text('搜索物品名称、地点'), findsOneWidget);
    // 分类与排序收在同一个按钮里，按钮上直接显示当前状态。
    expect(find.byKey(const Key('home-filter-menu')), findsOneWidget);
    expect(find.text('全部分类 · 最新发布'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('筛选菜单展开后同时列出物品分类与排序方式', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await tester.tap(find.byKey(const Key('home-filter-menu')));
    await tester.pumpAndSettle();

    expect(find.text('物品分类'), findsOneWidget);
    expect(find.text('排序方式'), findsOneWidget);
    expect(
      find.byKey(const Key('home-filter-category-digital')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-filter-sort-oldest')), findsOneWidget);
  });

  testWidgets('在筛选菜单里切换排序后按时间正序排列', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    final ItemPost oldest = buildMockPosts().reduce(
      (ItemPost a, ItemPost b) => a.createdAt.isBefore(b.createdAt) ? a : b,
    );

    String firstTitle() =>
        tester.widgetList<PostCard>(find.byType(PostCard)).first.post.title;

    expect(firstTitle(), isNot(oldest.title));

    await tester.tap(find.byKey(const Key('home-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-filter-sort-oldest')));
    await tester.pumpAndSettle();

    expect(firstTitle(), oldest.title);
    expect(find.text('全部分类 · 最早发布'), findsOneWidget);
  });

  testWidgets('选择“失物”筛选后不再显示招领信息', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    expect(find.text('黑色自动雨伞'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '失物'));
    await tester.pumpAndSettle();

    expect(find.text('黑色自动雨伞'), findsNothing);
    expect(find.text('校园一卡通（蓝色卡套）'), findsOneWidget);
  });

  testWidgets('在筛选菜单里选择“电子产品”后只保留该分类的信息', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await tester.tap(find.byKey(const Key('home-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-filter-category-digital')));
    await tester.pumpAndSettle();

    expect(find.text('白色无线耳机充电盒'), findsOneWidget);
    expect(find.text('黑色自动雨伞'), findsNothing);
    expect(find.text('电子产品 · 最新发布'), findsOneWidget);
  });

  testWidgets('首页搜索栏跳转到搜索界面', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await tester.tap(find.byKey(const Key('home-search-entry')));
    await tester.pumpAndSettle();

    // 搜索界面（UI 事项 5）已经做出来了：进来是一个等待输入的搜索框。
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.byKey(const Key('search-intro')), findsOneWidget);
  });
}
