import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/widgets/post_card.dart';

const String _title = '蓝色折叠伞';
const String _location = '图书馆一楼大厅';
const String _description = '伞骨是黑色的，伞柄缠了一圈胶带。';
const String _contact = '微信 umbrella_zhang';

/// 切到某个主界面标签。
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// 先把控件滚进视口再点，避免长表单里的控件在屏幕外点不到。
Future<void> tapAt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 往里填一段文字。
Future<void> typeInto(WidgetTester tester, Key key, String text) async {
  final Finder field = find.byKey(key);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// 点系统日期 / 时间选择器里的确认按钮。
///
/// 项目还没接入 flutter_localizations，系统控件仍然是英文。
Future<void> confirmPicker(WidgetTester tester) async {
  final Finder ok = find.text('OK');
  expect(ok, findsWidgets, reason: '未本地化的系统选择器应显示英文 OK 按钮');
  await tester.tap(ok.last);
  await tester.pumpAndSettle();
}

/// 选择「时间」字段：先选日期，再选时刻，各确认一次。
Future<void> pickEventTime(WidgetTester tester) async {
  await tapAt(tester, find.byKey(const Key('publish-time-picker')));
  await confirmPicker(tester);
  await confirmPicker(tester);
}

/// 把表单填成合规状态。
Future<void> fillForm(WidgetTester tester) async {
  await tapAt(
    tester,
    find.descendant(
      of: find.byKey(const Key('publish-type-selector')),
      matching: find.text('失物'),
    ),
  );
  await typeInto(tester, const Key('publish-title-field'), _title);
  await tapAt(tester, find.byKey(const Key('publish-category-digital')));
  await typeInto(tester, const Key('publish-location-field'), _location);
  await pickEventTime(tester);
  await typeInto(tester, const Key('publish-description-field'), _description);
  await typeInto(tester, const Key('publish-contact-field'), _contact);
}

void main() {
  testWidgets('发布界面列出全部表单项与发布按钮', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());
    await openTab(tester, '发布');

    for (final String label in <String>[
      '信息类型',
      '物品名称',
      '物品分类',
      '地点',
      '时间',
      '描述',
      '联系方式',
      '图片',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '缺少表单项：$label');
    }

    for (final ItemCategory category in ItemCategory.values) {
      expect(
        find.byKey(Key('publish-category-${category.name}')),
        findsOneWidget,
        reason: '缺少分类选项：${category.label}',
      );
    }

    expect(find.byKey(const Key('publish-submit-button')), findsOneWidget);
    expect(find.byKey(const Key('publish-reset-button')), findsOneWidget);
  });

  testWidgets('空表单提交时逐项提醒，且不会发布', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());
    await openTab(tester, '发布');

    await tapAt(tester, find.byKey(const Key('publish-submit-button')));

    for (final String message in <String>[
      '请选择信息类型',
      '请填写物品名称',
      '请选择物品分类',
      '请填写地点',
      '请选择时间',
      '请填写联系方式',
    ]) {
      expect(find.text(message), findsOneWidget, reason: '缺少提醒：$message');
    }
    expect(find.text('发布成功'), findsNothing);
  });

  testWidgets('只填名称仍然被拦下', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());
    await openTab(tester, '发布');

    await typeInto(tester, const Key('publish-title-field'), '一张饭卡');
    await tapAt(tester, find.byKey(const Key('publish-submit-button')));

    expect(find.text('请填写物品名称'), findsNothing);
    expect(find.text('请选择信息类型'), findsOneWidget);
    expect(find.text('请填写联系方式'), findsOneWidget);
    expect(find.text('发布成功'), findsNothing);
  });

  testWidgets('填写完整后发布成功并弹窗，表单随后清空', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());
    await openTab(tester, '发布');
    await fillForm(tester);

    await tapAt(tester, find.byKey(const Key('publish-submit-button')));

    expect(find.byKey(const Key('publish-success-dialog')), findsOneWidget);
    expect(find.text('发布成功'), findsOneWidget);
    expect(find.textContaining(_title), findsWidgets, reason: '弹窗应复述物品名称');

    await tapAt(tester, find.byKey(const Key('publish-success-confirm')));

    expect(find.text('发布成功'), findsNothing);
    // 表单已清空，可以接着发下一条。
    expect(find.text(_title), findsNothing);
    expect(find.text(_location), findsNothing);
  });

  testWidgets('发布成功后可从弹窗回到首页并看到新信息', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());
    await openTab(tester, '发布');
    await fillForm(tester);

    await tapAt(tester, find.byKey(const Key('publish-submit-button')));
    await tapAt(tester, find.byKey(const Key('publish-success-go-home')));

    expect(find.text('发布成功'), findsNothing);
    expect(find.text(_title), findsOneWidget, reason: '新信息应出现在首页列表里');

    final PostCard first =
        tester.widgetList<PostCard>(find.byType(PostCard)).first;
    expect(first.post.title, _title);
    expect(first.post.type, PostType.lost);
    expect(first.post.category, ItemCategory.digital);
    expect(first.post.location, _location);
    expect(first.post.contact, _contact);
    expect(first.post.description, _description);
  });

  testWidgets('清空按钮清掉已填内容与提醒', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());
    await openTab(tester, '发布');

    await tapAt(tester, find.byKey(const Key('publish-submit-button')));
    expect(find.text('请填写物品名称'), findsOneWidget);

    await typeInto(tester, const Key('publish-title-field'), '临时内容');
    await tester.tap(find.byKey(const Key('publish-reset-button')));
    await tester.pumpAndSettle();

    expect(find.text('临时内容'), findsNothing);
    expect(find.text('请填写物品名称'), findsNothing);
    expect(find.text('请选择信息类型'), findsNothing);
  });
}
