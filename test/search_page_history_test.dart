import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/search_history_repository.dart';
import 'package:lost_and_found/data/search_history_store.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/pages/search_page.dart';
import 'package:lost_and_found/widgets/post_card.dart';

import 'helpers/page_harness.dart';

/// 「最近搜索」的界面行为（本地后端事项 4）。
///
/// 库里那一半（表结构、仓储读写、版本迁移）在 search_history_test.dart 里测；
/// 这里只管界面上看得见的部分：什么时候摆出这一块、点一下会发生什么、
/// 什么动作才算「搜了一次」。

/// 造一条搜得到的信息：关键词真的出现在字段里才搜得着。
///
/// 名字里得真有「雨伞」两个字——搜的是子串，不是同义词
/// （「折叠伞」里没有「雨伞」，搜「雨伞」是搜不到的，这里踩过）。
ItemPost buildMatchingUmbrella() => ItemPost(
  id: 'h001',
  type: PostType.found,
  title: '黑色自动雨伞',
  category: ItemCategory.daily,
  location: '图书馆一楼大厅',
  eventTime: DateTime.now().subtract(const Duration(hours: 2)),
  contact: '微信 umbrella_zhang',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  description: '伞柄上有一圈透明胶带。',
);

/// 渲染搜索界面，并把「最近搜索」仓库交回给用例（要验它被写成什么样）。
Future<SearchHistoryStore> pumpSearchWithHistory(
  WidgetTester tester, {
  List<String> history = const <String>[],
}) async {
  // 引导态里有图标、说明、最近搜索、示例词，一屏（800×600）放不下，
  // 拉到 1000×1400 免得断言时机上还没建出来。
  useTallScreen(tester);

  final SearchHistoryStore store = SearchHistoryStore(
    initialKeywords: history,
  );

  await tester.pumpWidget(
    buildSearchHost(
      posts: PostStore(initialPosts: <ItemPost>[buildMatchingUmbrella()]),
      history: store,
      home: const SearchPage(),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// 清掉输入框里的词，回到引导态（最近搜索摆在引导态里）。
Future<void> backToIntro(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('search-clear')));
  await tester.pumpAndSettle();
}

/// 「最近搜索」区块里那些词的顺序。
List<String> historyChipLabels(WidgetTester tester) => tester
    .widgetList<InputChip>(
      find.descendant(
        of: find.byKey(const Key('search-history')),
        matching: find.byType(InputChip),
      ),
    )
    .map((InputChip chip) => (chip.label as Text).data!)
    .toList();

/// 结果列表里的全部标题。
List<String> resultTitles(WidgetTester tester) => tester
    .widgetList<PostCard>(find.byType(PostCard))
    .map((PostCard card) => card.post.title)
    .toList();

void main() {
  testWidgets('没搜过任何东西时，引导态不摆「最近搜索」', (WidgetTester tester) async {
    await pumpSearchWithHistory(tester);

    expect(find.byKey(const Key('search-intro')), findsOneWidget);
    expect(find.byKey(const Key('search-history')), findsNothing);
    // 提示词照旧：示例词那一块是老的，不该被这一版改动碰坏。
    expect(find.byKey(const Key('search-suggestion-雨伞')), findsOneWidget);
  });

  testWidgets('搜过的词按「最近在前」摆在引导态里', (WidgetTester tester) async {
    await pumpSearchWithHistory(
      tester,
      history: <String>['钥匙', '一卡通', '雨伞'],
    );

    expect(find.byKey(const Key('search-history')), findsOneWidget);
    expect(historyChipLabels(tester), <String>['钥匙', '一卡通', '雨伞']);
    // 清空按钮就在标题行上，跟着区块一起出现。
    expect(find.byKey(const Key('search-history-clear')), findsOneWidget);
  });

  testWidgets('点最近搜索里的词：填进输入框、真的搜出结果、并把词挪到最前', (WidgetTester tester) async {
    final SearchHistoryStore store = await pumpSearchWithHistory(
      tester,
      history: <String>['钥匙', '雨伞'],
    );

    // 点的是第二条（不是最前那条）：只有真的记了一笔，它才会挪到最前。
    await tester.tap(find.byKey(const Key('search-history-雨伞')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byKey(const Key('search-field'))).controller!.text,
      '雨伞',
    );
    expect(resultTitles(tester), <String>['黑色自动雨伞']);
    expect(store.keywords, <String>['雨伞', '钥匙']);
  });

  testWidgets('键盘上按搜索键才算记一笔；边打字边记是不行的', (WidgetTester tester) async {
    final SearchHistoryStore store = await pumpSearchWithHistory(tester);

    // 边打字不入历史：否则「一」「一卡」「一卡通」会把列表占满。
    await tester.enterText(find.byKey(const Key('search-field')), '雨伞');
    await tester.pumpAndSettle();
    expect(store.keywords, isEmpty);

    // 按下键盘上的搜索键 → 记一笔，并收起键盘。
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(store.keywords, <String>['雨伞']);

    await backToIntro(tester);
    expect(historyChipLabels(tester), <String>['雨伞']);
  });

  testWidgets('点示例关键词也算一次搜索', (WidgetTester tester) async {
    final SearchHistoryStore store = await pumpSearchWithHistory(tester);

    await tester.tap(find.byKey(const Key('search-suggestion-雨伞')));
    await tester.pumpAndSettle();

    expect(store.keywords, <String>['雨伞']);
  });

  testWidgets('点词上的小叉只删掉那一个词', (WidgetTester tester) async {
    final SearchHistoryStore store = await pumpSearchWithHistory(
      tester,
      history: <String>['钥匙', '雨伞'],
    );

    // 小叉本身很窄，点坐标容易飘；直接走它绑的动作。
    tester
        .widget<InputChip>(find.byKey(const Key('search-history-钥匙')))
        .onDeleted!();
    await tester.pumpAndSettle();

    expect(store.keywords, <String>['雨伞']);
    expect(find.byKey(const Key('search-history-钥匙')), findsNothing);
    expect(find.byKey(const Key('search-history-雨伞')), findsOneWidget);
  });

  testWidgets('「清空」先问一句，取消就什么都不动', (WidgetTester tester) async {
    final SearchHistoryStore store = await pumpSearchWithHistory(
      tester,
      history: <String>['钥匙', '雨伞'],
    );

    await tester.tap(find.byKey(const Key('search-history-clear')));
    await tester.pumpAndSettle();
    expect(find.text('清空搜索记录？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-history-clear-cancel')));
    await tester.pumpAndSettle();
    expect(store.keywords, <String>['钥匙', '雨伞']);
  });

  testWidgets('「清空」确认后记录全没了，区块也跟着消失', (WidgetTester tester) async {
    final SearchHistoryStore store = await pumpSearchWithHistory(
      tester,
      history: <String>['钥匙', '雨伞'],
    );

    await tester.tap(find.byKey(const Key('search-history-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-history-clear-confirm')));
    await tester.pumpAndSettle();

    expect(store.keywords, isEmpty);
    expect(find.byKey(const Key('search-history')), findsNothing);
    // 只是没了历史，引导语本身还在。
    expect(find.byKey(const Key('search-intro')), findsOneWidget);
  });

  testWidgets('记下的词会落进仓库（换成真库就是落盘）', (WidgetTester tester) async {
    final MemorySearchHistoryRepository repository =
        MemorySearchHistoryRepository();
    useTallScreen(tester);
    final SearchHistoryStore store = SearchHistoryStore(
      repository: repository,
    );

    await tester.pumpWidget(
      buildSearchHost(
        posts: PostStore(initialPosts: <ItemPost>[buildMatchingUmbrella()]),
        history: store,
        home: const SearchPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), '雨伞');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      await repository.loadKeywords(),
      <String>['雨伞'],
      reason: '记下的词必须写进仓储，否则下次开应用就没了',
    );

    // 另一个仓库从同一个存储读回来：这就是「重启应用」的样子。
    final SearchHistoryStore reopened = SearchHistoryStore(
      repository: repository,
    );
    await reopened.load();
    expect(reopened.keywords, <String>['雨伞']);
  });

  testWidgets('出了结果之后「最近搜索」就收起来，把版面让给结果', (WidgetTester tester) async {
    // 这一条钉住取舍：历史区块只在引导态出现，结果列表才是主角。
    await pumpSearchWithHistory(tester, history: <String>['钥匙']);

    await tester.enterText(find.byKey(const Key('search-field')), '雨伞');
    await tester.pumpAndSettle();

    expect(find.byType(PostCard), findsOneWidget);
    expect(find.byKey(const Key('search-history')), findsNothing);
  });

  testWidgets('还没搜过东西时摆图标和说明：这一屏在解释自己能搜什么', (
    WidgetTester tester,
  ) async {
    await pumpSearchWithHistory(tester);

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('搜索校园里的失物与招领'), findsOneWidget);
    expect(find.text('物品名称、地点、描述里的词都能搜。'), findsOneWidget);
  });

  testWidgets('搜过之后那句说明就让位：图标和标题都收起来，最近搜索顶到最前', (WidgetTester tester) async {
    // 用户已经用过搜索了，再解释「这里能搜什么」只是噪音。
    // 示例词留着——它们仍是有用的入口。
    await pumpSearchWithHistory(tester, history: <String>['钥匙']);

    expect(find.byKey(const Key('search-history')), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsNothing);
    expect(find.text('搜索校园里的失物与招领'), findsNothing);
    expect(find.text('物品名称、地点、描述里的词都能搜。'), findsNothing);
    // 示例词那一排不受影响。
    expect(find.byKey(const Key('search-suggestion-雨伞')), findsOneWidget);
  });

  testWidgets('最近搜索的标题行撑满整行：「清空」贴在右边而不是挤在标题旁', (
    WidgetTester tester,
  ) async {
    await pumpSearchWithHistory(tester, history: <String>['钥匙']);

    final Rect section = tester.getRect(
      find.byKey(const Key('search-history')),
    );
    final Rect row = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('search-history')),
        matching: find.byType(Row),
      ),
    );
    final Rect clear = tester.getRect(
      find.byKey(const Key('search-history-clear')),
    );

    // 标题行的宽度就是区块的宽度（近似等于可用宽度），不是「标题 + 清空」那么一小截。
    expect(row.width, moreOrLessEquals(section.width, epsilon: 0.5));
    // 「清空」右边缘贴到标题行右边缘。
    expect(clear.right, moreOrLessEquals(row.right, epsilon: 0.5));
  });

  testWidgets('没有搜索记录时，那句提示仍然是在屏幕中间', (WidgetTester tester) async {
    // 曾经这里偏左：外层 Column 只按最宽的子控件取宽，子控件又都往左靠，
    // 于是 textAlign: center 无事可做。靠 crossAxisAlignment: stretch 撑满才正。
    await pumpSearchWithHistory(tester);

    final Rect intro = tester.getRect(find.byKey(const Key('search-intro')));
    final Rect title = tester.getRect(find.text('搜索校园里的失物与招领'));

    expect((title.center.dx - intro.center.dx).abs(), lessThan(1.0));
  });
}
