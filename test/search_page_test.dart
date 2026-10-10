import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/mock_posts.dart';
import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/search_history_store.dart';
import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/pages/search_page.dart';
import 'package:lost_and_found/widgets/post_card.dart';

import 'helpers/page_harness.dart';

/// 造一条信息，默认是一把别人捡到的伞（搜索界面最常用的场景）。
ItemPost buildPost({
  String id = 's001',
  PostType type = PostType.found,
  String title = '黑色折叠伞',
  ItemCategory category = ItemCategory.daily,
  String location = '图书馆一楼大厅',
  String? description = '伞柄上有一圈透明胶带。',
  String contact = '微信 umbrella_zhang',
  Duration age = const Duration(hours: 2),
}) {
  final DateTime now = DateTime.now();
  return ItemPost(
    id: id,
    type: type,
    title: title,
    category: category,
    location: location,
    eventTime: now.subtract(age),
    contact: contact,
    createdAt: now.subtract(age),
    description: description,
  );
}

/// 单独渲染搜索界面。
///
/// 搜索界面只认 [PostStore] 里现查的数据（这样别处改了 / 删了它都跟着变），
/// 所以每条用例都得把数据真的放一份进仓库；要验“结果会跟着仓库变”时
/// 就把仓库拿在手上（[store] 传出去）。
///
/// 「最近搜索」这一块单独在 search_page_history_test.dart 里测，
/// 这里的仓库默认是空的——引导态里不会多出那一区块，老用例的断言不受影响。
Future<PostStore> pumpSearch(
  WidgetTester tester, {
  List<ItemPost>? posts,
}) async {
  final PostStore store = PostStore(initialPosts: posts ?? buildMockPosts());

  await tester.pumpWidget(
    buildSearchHost(
      posts: store,
      history: SearchHistoryStore(),
      home: const SearchPage(),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// 往搜索框里输入关键词（输入即搜，不必再点按钮）。
Future<void> search(WidgetTester tester, String keyword) async {
  await tester.enterText(find.byKey(const Key('search-field')), keyword);
  await tester.pumpAndSettle();
}

/// 当前结果列表里第一条的标题。
String firstResultTitle(WidgetTester tester) =>
    tester.widgetList<PostCard>(find.byType(PostCard)).first.post.title;

/// 结果列表里的全部标题。
List<String> resultTitles(WidgetTester tester) => tester
    .widgetList<PostCard>(find.byType(PostCard))
    .map((PostCard card) => card.post.title)
    .toList();

void main() {
  testWidgets('首页搜索栏进入搜索界面：输入框就位，给的是引导而不是“建设中”', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await tester.tap(find.byKey(const Key('home-search-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.byKey(const Key('search-intro')), findsOneWidget);
    expect(find.text('搜索界面建设中'), findsNothing);
    // 还没输入关键词时不该摆出筛选条——没有结果可筛。
    expect(find.byKey(const Key('search-filter-menu')), findsNothing);
  });

  testWidgets('输入物品名称后只剩匹配的信息', (WidgetTester tester) async {
    await pumpSearch(tester);

    await search(tester, '雨伞');

    expect(resultTitles(tester), <String>['黑色自动雨伞']);
    expect(find.text('找到 1 条相关信息'), findsOneWidget);
    expect(find.byKey(const Key('search-results')), findsOneWidget);
  });

  testWidgets('关键词不只看物品名称，地点与描述里的词也算', (WidgetTester tester) async {
    await pumpSearch(tester);

    // 地点命中：图书馆一楼大厅。
    await search(tester, '图书馆');
    expect(resultTitles(tester), <String>['黑色自动雨伞']);

    // 描述命中：伞柄上有一圈透明胶带。
    await search(tester, '胶带');
    expect(resultTitles(tester), <String>['黑色自动雨伞']);

    // 分类名命中：证件卡类。默认按最新发布排，所以 2 小时前的一卡通在前。
    await search(tester, '证件');
    expect(resultTitles(tester), <String>['校园一卡通（蓝色卡套）', '学生证（李同学）']);
  });

  testWidgets('多个关键词是“都要沾边”，多打一个词是收窄结果', (WidgetTester tester) async {
    await pumpSearch(tester);

    await search(tester, '图书馆 雨伞');
    expect(resultTitles(tester), <String>['黑色自动雨伞']);

    // 顺序不影响结果。
    await search(tester, '雨伞 图书馆');
    expect(resultTitles(tester), <String>['黑色自动雨伞']);

    // 两个词各只落在不同信息上时，什么也匹配不到。
    await search(tester, '图书馆 保温杯');
    expect(find.byType(PostCard), findsNothing);
    expect(find.byKey(const Key('search-empty-keyword')), findsOneWidget);
  });

  testWidgets('英文关键词不分大小写', (WidgetTester tester) async {
    await pumpSearch(
      tester,
      posts: <ItemPost>[
        buildPost(
          id: 'e001',
          type: PostType.lost,
          title: 'iPhone 15 手机壳',
          category: ItemCategory.digital,
          description: '深蓝色，摄像头处有划痕。',
        ),
      ],
    );

    await search(tester, 'iphone');
    expect(resultTitles(tester), <String>['iPhone 15 手机壳']);

    await search(tester, 'IPHONE');
    expect(resultTitles(tester), <String>['iPhone 15 手机壳']);
  });

  testWidgets('没有匹配时给出空态，并给几个能点的关键词', (WidgetTester tester) async {
    await pumpSearch(tester);

    await search(tester, '自行车');

    expect(find.byKey(const Key('search-empty-keyword')), findsOneWidget);
    expect(find.text('没有找到与「自行车」相关的信息'), findsOneWidget);
    expect(find.byKey(const Key('search-results')), findsNothing);

    // 空态里的建议词点了就能直接搜。
    await tester.tap(find.byKey(const Key('search-suggestion-雨伞')));
    await tester.pumpAndSettle();

    expect(resultTitles(tester), <String>['黑色自动雨伞']);
  });

  testWidgets('引导页的“试试这些关键词”点了就填入并出结果', (WidgetTester tester) async {
    await pumpSearch(tester);

    await tester.tap(find.byKey(const Key('search-suggestion-耳机')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search-field')))
          .controller
          ?.text,
      '耳机',
    );
    expect(resultTitles(tester), <String>['白色无线耳机充电盒']);
    expect(find.byKey(const Key('search-intro')), findsNothing);
  });

  testWidgets('清空关键词回到引导态', (WidgetTester tester) async {
    await pumpSearch(tester);

    await search(tester, '雨伞');
    expect(find.byKey(const Key('search-results')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-intro')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search-field')))
          .controller
          ?.text,
      '',
    );
    expect(find.byKey(const Key('search-filter-menu')), findsNothing);
  });

  testWidgets('搜索结果也能换排序', (WidgetTester tester) async {
    await pumpSearch(tester);

    // 「电子产品」是分类名，两条都在这个分类里，正好用来验排序。
    await search(tester, '电子产品');
    expect(resultTitles(tester), <String>['白色无线耳机充电盒', '银色手机']);

    await tester.tap(find.byKey(const Key('search-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-filter-sort-oldest')));
    await tester.pumpAndSettle();

    expect(firstResultTitle(tester), '银色手机');
    expect(find.text('全部分类 · 最早发布'), findsOneWidget);
  });

  testWidgets('筛选把结果筛空时给的是“清除筛选”而不是“没找到”', (WidgetTester tester) async {
    await pumpSearch(tester);

    await search(tester, '电子产品');

    await tester.tap(find.byKey(const Key('search-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-filter-category-key')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-empty-filter')), findsOneWidget);
    expect(find.byKey(const Key('search-empty-keyword')), findsNothing);

    await tester.tap(find.byKey(const Key('search-clear-filters')));
    await tester.pumpAndSettle();

    expect(resultTitles(tester), <String>['白色无线耳机充电盒', '银色手机']);
    expect(find.text('全部分类 · 最新发布'), findsOneWidget);
  });

  testWidgets('清空关键词会把筛选一起复位，不留看不见的条件', (WidgetTester tester) async {
    await pumpSearch(tester);

    await search(tester, '电子产品');
    await tester.tap(find.byKey(const Key('search-filter-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-filter-category-key')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-empty-filter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();

    // 重新搜一次，上一轮选的分类不该阴魂不散。
    await search(tester, '电子产品');
    expect(resultTitles(tester), <String>['白色无线耳机充电盒', '银色手机']);
    expect(find.text('全部分类 · 最新发布'), findsOneWidget);
  });

  testWidgets('点搜索结果进详细信息界面，返回后搜索内容还在', (WidgetTester tester) async {
    // 详情页的联系方式卡在页面下半截，视口高一点才建得出来。
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSearch(tester);

    await search(tester, '雨伞');
    await tester.tap(find.byType(PostCard).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-content')), findsOneWidget);
    expect(find.byKey(const Key('detail-contact')), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-back-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-results')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search-field')))
          .controller
          ?.text,
      '雨伞',
    );
  });

  testWidgets('结果是活视图：仓库里新发布的信息，正在搜的人也能搜到', (WidgetTester tester) async {
    final PostStore store = await pumpSearch(
      tester,
      posts: <ItemPost>[buildPost(id: 's001', title: '黑色雨伞')],
    );

    await search(tester, '雨伞');
    expect(find.text('找到 1 条相关信息'), findsOneWidget);

    // 别人刚发布了一条，正在搜索的人不必退出重进。
    store.addPost(
      buildPost(
        id: 's002',
        type: PostType.lost,
        title: '格子雨伞',
        location: '第二食堂二楼',
        age: const Duration(minutes: 5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('找到 2 条相关信息'), findsOneWidget);
    expect(resultTitles(tester), <String>['格子雨伞', '黑色雨伞']);
  });
}
