import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/user_store.dart';
import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/pages/post_detail_page.dart';
import 'package:lost_and_found/pages/profile_page.dart';
import 'package:lost_and_found/widgets/post_card.dart';

/// 别人发布的一条招领信息：详情页的主要使用场景。
ItemPost buildSample({
  String id = 'd001',
  PostType type = PostType.found,
  String title = '黑色折叠伞',
  String location = '图书馆一楼大厅',
  String contact = '微信 umbrella_zhang',
  String? description = '伞柄上有一圈透明胶带。',
  PostStatus status = PostStatus.pending,
  bool isMine = false,
  Duration age = const Duration(hours: 2),
  Duration eventAge = const Duration(hours: 5),
}) {
  final DateTime now = DateTime.now();
  return ItemPost(
    id: id,
    type: type,
    title: title,
    category: ItemCategory.daily,
    location: location,
    eventTime: now.subtract(eventAge),
    contact: contact,
    createdAt: now.subtract(age),
    description: description,
    status: status,
    isMine: isMine,
  );
}

/// 查看详情时把测试视口调高，让整页内容一次渲染出来。
///
/// 详情页是 `ListView`（长内容才懒加载），默认 800×600 的视口装不下，
/// 联系方式会在屏幕外而根本不进 widget 树，`find` 自然找不到。
/// 只调视口不动页面结构，测试才是在验真实的布局。
///
/// 详情页只认 [PostStore] 里现查的那一份数据（这样改了、删了都能同步），
/// 所以每条用例都得把信息真的放一份进仓库。
Future<void> pumpDetail(
  WidgetTester tester,
  ItemPost post, {
  PostStore? store,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    PostScope(
      store: store ?? PostStore(initialPosts: <ItemPost>[post]),
      child: MaterialApp(
        home: PostDetailPage(postId: post.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 先把控件滚进视口再点，长页面里的控件在屏幕外点不到。
Future<void> tapAt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 往某个输入框里填文字。
Future<void> typeInto(WidgetTester tester, Key key, String text) async {
  final Finder field = find.byKey(key);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  // 测试环境没有真的系统剪贴板：不接管这个通道，`Clipboard.setData` 的
  // Future 永远不会完成，复制按钮后面的提示就再也不会出现。
  // 平台通道上还有别的调用（系统 UI、无障碍等），所以只记剪贴板那一条。
  final List<MethodCall> clipboardCalls = <MethodCall>[];
  setUp(() {
    clipboardCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboardCalls.add(call);
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('首页点卡片进入详细信息界面', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    // 首页第一条是示例数据里最新发布的那条。
    await tapAt(tester, find.byType(PostCard).first);

    expect(find.byType(PostDetailPage), findsOneWidget);
    expect(find.text('校园一卡通（蓝色卡套）'), findsWidgets);
    // 首页的筛选器不该跟到详情页上来。
    expect(find.byKey(const Key('home-filter-menu')), findsNothing);
  });

  testWidgets('详细信息界面集中展示物品信息与发布者联系方式', (WidgetTester tester) async {
    await pumpDetail(tester, buildSample());

    expect(find.byKey(const Key('detail-title')), findsOneWidget);
    expect(find.text('招领'), findsOneWidget);
    // 物品分类、地点、时间在同一张信息卡里。
    expect(find.byKey(const Key('detail-info-card')), findsOneWidget);
    expect(find.text('生活用品'), findsOneWidget);
    expect(find.text('图书馆一楼大厅'), findsOneWidget);
    expect(find.textContaining('小时前'), findsWidgets);
    expect(find.text('伞柄上有一圈透明胶带。'), findsOneWidget);
    // 联系方式与复制入口。
    expect(find.byKey(const Key('detail-contact-card')), findsOneWidget);
    expect(find.text('微信 umbrella_zhang'), findsOneWidget);
    expect(find.byKey(const Key('detail-copy-contact')), findsOneWidget);
    expect(find.text('发布者留下的联系方式'), findsOneWidget);
  });

  testWidgets('失物信息的字段文案与招领区分', (WidgetTester tester) async {
    await pumpDetail(
      tester,
      buildSample(type: PostType.lost, title: '蓝色保温杯'),
    );

    expect(find.text('失物'), findsOneWidget);
    expect(find.text('丢失地点'), findsOneWidget);
    expect(find.text('丢失时间'), findsOneWidget);
    expect(find.textContaining('请直接联系失主'), findsOneWidget);
  });

  testWidgets('复制按钮把联系方式写进剪贴板并提示', (WidgetTester tester) async {
    await pumpDetail(tester, buildSample());

    await tapAt(tester, find.byKey(const Key('detail-copy-contact')));

    expect(find.text('联系方式已复制'), findsOneWidget);
    final MethodCall call = clipboardCalls.single;
    expect((call.arguments as Map<Object?, Object?>)['text'], '微信 umbrella_zhang');
  });

  testWidgets('页脚按钮同样能复制联系方式', (WidgetTester tester) async {
    await pumpDetail(tester, buildSample());

    await tapAt(tester, find.byKey(const Key('detail-copy-contact-button')));

    expect(find.text('联系方式已复制'), findsOneWidget);
    expect(clipboardCalls, hasLength(1));
  });

  testWidgets('已完成的信息给出「已归还」说明，标记随类型变化', (WidgetTester tester) async {
    await pumpDetail(
      tester,
      buildSample(
        type: PostType.found,
        status: PostStatus.resolved,
        contact: '手机 139****2200',
      ),
    );

    expect(find.byKey(const Key('detail-resolved-notice')), findsOneWidget);
    expect(find.textContaining('已归还'), findsWidgets);
  });

  testWidgets('自己发布的信息在详情页标注「你留下的联系方式」', (WidgetTester tester) async {
    await pumpDetail(tester, buildSample(isMine: true));

    expect(find.text('你留下的联系方式'), findsOneWidget);
    expect(find.text('发布者留下的联系方式'), findsNothing);
  });

  testWidgets('描述为空时给出说明而不是空白', (WidgetTester tester) async {
    await pumpDetail(tester, buildSample(description: null));

    expect(find.text('发布者没有填写物品描述。'), findsOneWidget);
  });

  testWidgets('仓库里改动同一条信息后，已打开的详情随之更新', (WidgetTester tester) async {
    final ItemPost mine = buildSample(id: 'd002', isMine: true);
    final PostStore store = PostStore(initialPosts: <ItemPost>[mine]);
    await pumpDetail(tester, mine, store: store);

    expect(find.text('你留下的联系方式'), findsOneWidget);

    // 相当于在「我的」里改了内容：详情页读的是仓库，不是进来时的快照。
    store.updatePost(mine.copyWith(description: '伞面印着校徽。'));
    await tester.pumpAndSettle();

    expect(find.text('伞面印着校徽。'), findsOneWidget);
    expect(find.text('伞柄上有一圈透明胶带。'), findsNothing);
  });

  testWidgets('查看期间信息被删除时给出空态', (WidgetTester tester) async {
    final ItemPost post = buildSample(id: 'd003');
    final PostStore store = PostStore(initialPosts: <ItemPost>[post]);
    await pumpDetail(tester, post, store: store);

    expect(find.byKey(const Key('detail-deleted')), findsNothing);

    // 相当于在「我的」里把这条删了：详情页读的是仓库，不是进来时的快照。
    store.removePost(post.id);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-deleted')), findsOneWidget);
    expect(find.text('这条信息已被删除'), findsOneWidget);
  });

  testWidgets('返回后回到首页列表', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await tapAt(tester, find.byType(PostCard).first);
    expect(find.byType(PostDetailPage), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('detail-back-button')));

    expect(find.byType(PostDetailPage), findsNothing);
    expect(find.byType(PostCard), findsWidgets);
  });

  testWidgets('从「我的发布」点卡片进详情，改完描述后详情同步更新', (WidgetTester tester) async {
    final ItemPost mine = buildSample(id: 'd004', isMine: true);
    final PostStore store = PostStore(initialPosts: <ItemPost>[mine]);
    await pumpDetail(tester, mine, store: store);

    // 从「我的」进入详情：卡片本体就是入口（管理操作仍留在卡片底部那排按钮）。
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pumpWidget(
      PostScope(
        store: store,
        child: UserScope(
          store: UserStore(),
          // 「我的」要给详情页传「回到首页」，单独渲染时用不着。
          child: const MaterialApp(home: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapAt(tester, find.byKey(const Key('profile-post-d004')));
    expect(find.byType(PostDetailPage), findsOneWidget);
    expect(find.text('黑色折叠伞'), findsWidgets);

    // 返回「我的」改描述，再进详情，看到的应当是改后的内容。
    await tapAt(tester, find.byKey(const Key('detail-back-button')));
    await tapAt(tester, find.byKey(const Key('profile-edit-d004')));
    await typeInto(
      tester,
      const Key('publish-description-field'),
      '伞面印着校徽。',
    );
    await tapAt(tester, find.byKey(const Key('publish-submit-button')));

    await tapAt(tester, find.byKey(const Key('profile-post-d004')));
    expect(find.text('伞面印着校徽。'), findsOneWidget);
  });

  testWidgets('点详情页图片打开全屏查看器，再点关闭返回', (WidgetTester tester) async {
    final ItemPost withPhotos = ItemPost(
      id: 'd010',
      type: PostType.found,
      title: '蓝色保温杯',
      category: ItemCategory.daily,
      location: '食堂二楼',
      eventTime: DateTime.now().subtract(const Duration(hours: 3)),
      contact: '微信 test',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      imagePaths: const <String>['fake-photo-1.jpg', 'fake-photo-2.jpg'],
    );
    await pumpDetail(tester, withPhotos);

    // 轮播里第一张图片可以点。
    final Finder firstPhoto = find.byKey(const Key('detail-photo-0'));
    expect(firstPhoto, findsOneWidget);

    await tapAt(tester, firstPhoto);
    await tester.pumpAndSettle();

    // 全屏查看器出来了：有关闭按钮和页码。
    expect(find.byKey(const Key('gallery-close')), findsOneWidget);
    expect(find.byKey(const Key('gallery-indicator')), findsOneWidget);

    // 点关闭回到详情页。
    await tapAt(tester, find.byKey(const Key('gallery-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gallery-close')), findsNothing);
    expect(find.byKey(const Key('detail-photo-0')), findsOneWidget);
  });
}
