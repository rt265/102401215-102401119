import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/main.dart';

void main() {
  testWidgets('首页展示标题、搜索栏、筛选器与信息卡片', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    expect(find.text('校园失物招领'), findsOneWidget);
    expect(find.text('搜索物品名称、地点'), findsOneWidget);
    expect(find.text('全部分类'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('选择“失物”筛选后不再显示招领信息', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    expect(find.text('黑色自动雨伞'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '失物'));
    await tester.pumpAndSettle();

    expect(find.text('黑色自动雨伞'), findsNothing);
    expect(find.text('校园一卡通（蓝色卡套）'), findsOneWidget);
  });

  testWidgets('按“电子产品”分类筛选后只保留该分类的信息', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await tester.tap(find.widgetWithText(ChoiceChip, '电子产品'));
    await tester.pumpAndSettle();

    expect(find.text('白色无线耳机充电盒'), findsOneWidget);
    expect(find.text('黑色自动雨伞'), findsNothing);
  });

  testWidgets('首页搜索栏跳转到搜索界面', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await tester.tap(find.byKey(const Key('home-search-entry')));
    await tester.pumpAndSettle();

    expect(find.text('搜索界面建设中'), findsOneWidget);
  });
}
