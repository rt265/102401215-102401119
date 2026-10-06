import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/data/user_store.dart';
import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/pages/post_edit_page.dart';
import 'package:lost_and_found/pages/profile_page.dart';
import 'package:lost_and_found/widgets/post_card.dart';

const String _title = '黑色折叠伞';
const String _location = '图书馆一楼大厅';
const String _contact = '微信 umbrella_zhang';
const String _name = '张同学';

/// 只装「我的」界面：不经过三大主界面外壳，测试用起来更直接。
Widget buildProfile({PostStore? posts, UserStore? users}) {
  return PostScope(
    store: posts ?? PostStore(initialPosts: <ItemPost>[]),
    child: UserScope(
      store: users ?? UserStore(),
      child: MaterialApp(home: ProfilePage(onGoPublish: () {})),
    ),
  );
}

/// 造一条本机用户发布的信息。
ItemPost buildMyPost({
  required String id,
  String title = '蓝色保温杯',
  PostType type = PostType.lost,
  PostStatus status = PostStatus.pending,
}) {
  final DateTime now = DateTime.now();
  return ItemPost(
    id: id,
    type: type,
    title: title,
    category: ItemCategory.daily,
    location: '第二食堂二楼',
    eventTime: now.subtract(const Duration(hours: 3)),
    contact: _contact,
    createdAt: now.subtract(const Duration(hours: 1)),
    description: '杯盖是白色的。',
    status: status,
    isMine: true,
  );
}

/// 先把控件滚进视口再点，避免长页面里的控件在屏幕外点不到。
Future<void> tapAt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 切到某个主界面标签。
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
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

void main() {
  testWidgets('我的界面展示账户入口与「我的发布」区块', (WidgetTester tester) async {
    await tester.pumpWidget(buildProfile());

    expect(find.text('我的'), findsOneWidget);
    expect(find.byKey(const Key('profile-account-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-register-button')), findsOneWidget);
    expect(find.text('我的发布'), findsOneWidget);
    // 没有发布过任何信息时给出去发布的入口。
    expect(find.byKey(const Key('profile-empty')), findsOneWidget);
    expect(find.text('还没有发布过信息'), findsOneWidget);
    expect(find.byKey(const Key('profile-go-publish')), findsOneWidget);
    expect(find.byKey(const Key('profile-stats')), findsNothing);
  });

  testWidgets('示例数据不会出现在「我的发布」里', (WidgetTester tester) async {
    // 默认仓库里是 9 条示例数据，但它们都不是本机用户发的。
    await tester.pumpWidget(buildProfile(posts: PostStore()));

    expect(find.byKey(const Key('profile-empty')), findsOneWidget);
    expect(find.byKey(const Key('profile-stats')), findsNothing);
    expect(find.text('校园一卡通（蓝色卡套）'), findsNothing);
  });

  testWidgets('注册账户后卡片显示称呼与联系方式', (WidgetTester tester) async {
    final UserStore users = UserStore();
    await tester.pumpWidget(buildProfile(users: users));

    await tapAt(tester, find.byKey(const Key('profile-register-button')));
    expect(find.text('登记账户'), findsOneWidget);

    // 两项都是必填，先空提交一次。
    await tapAt(tester, find.byKey(const Key('profile-register-submit')));
    expect(find.text('请填写称呼'), findsOneWidget);
    expect(find.text('请填写联系方式'), findsOneWidget);

    await typeInto(tester, const Key('profile-name-field'), _name);
    await typeInto(tester, const Key('profile-contact-field'), _contact);
    await tapAt(tester, find.byKey(const Key('profile-register-submit')));

    expect(find.byKey(const Key('profile-account-name')), findsOneWidget);
    expect(find.text(_name), findsOneWidget);
    expect(find.text('联系方式：$_contact'), findsOneWidget);
    // 仓库里也记下了账户。
    expect(users.account?.displayName, _name);
    expect(users.account?.contact, _contact);
  });

  testWidgets('登记账户后发布界面带出默认联系方式', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await openTab(tester, '我的');
    await tapAt(tester, find.byKey(const Key('profile-register-button')));
    await typeInto(tester, const Key('profile-name-field'), _name);
    await typeInto(tester, const Key('profile-contact-field'), _contact);
    await tapAt(tester, find.byKey(const Key('profile-register-submit')));

    await openTab(tester, '发布');

    final TextFormField contact = tester.widget<TextFormField>(
      find.byKey(const Key('publish-contact-field')),
    );
    expect(contact.controller?.text, _contact);
  });

  testWidgets('我的发布列出自己发布的信息与统计', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[
        buildMyPost(id: 'local-1', title: '蓝色保温杯'),
        buildMyPost(
          id: 'local-2',
          title: '黑色雨伞',
          type: PostType.found,
          status: PostStatus.resolved,
        ),
      ],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    expect(find.byKey(const Key('profile-stats')), findsOneWidget);
    expect(find.byKey(const Key('profile-empty')), findsNothing);
    expect(find.text('蓝色保温杯'), findsOneWidget);
    expect(find.text('黑色雨伞'), findsOneWidget);

    // 两条信息，其中一条已完成。
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-stat-published')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-stat-resolved')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('标记已找到后状态写入仓库', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[buildMyPost(id: 'local-1', title: '蓝色保温杯')],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    await tapAt(tester, find.byKey(const Key('profile-resolve-local-1')));

    // 先确认再执行，避免误点。
    expect(find.byKey(const Key('profile-resolve-dialog')), findsOneWidget);
    expect(find.text('标记「已找到」？'), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('profile-confirm-action')));

    expect(posts.posts.single.status, PostStatus.resolved);
    // 标记之后不再给「标记」按钮，改为展示结果 + 「改回进行中」。
    expect(find.byKey(const Key('profile-resolve-local-1')), findsNothing);
    expect(find.byKey(const Key('profile-revert-local-1')), findsOneWidget);
    expect(find.textContaining('已找到'), findsWidgets);
  });

  testWidgets('标记完成后状态与图标按钮在同一水平线上', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[
        buildMyPost(id: 'local-1', status: PostStatus.resolved),
      ],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    // 结果块（对勾 + 文字）和右边的图标按钮中线对齐。
    // 断言收进卡片里：页面上方的统计卡也有图标，别误伤。
    Finder inCard(Finder matching) => find.descendant(
      of: find.byKey(const Key('profile-post-local-1')),
      matching: matching,
    );
    final double iconCenter = tester
        .getCenter(
          inCard(
            find.descendant(
              of: find.byKey(const Key('profile-edit-local-1')),
              matching: find.byIcon(Icons.edit_outlined),
            ),
          ),
        )
        .dy;
    expect(
      tester.getCenter(inCard(find.byIcon(Icons.task_alt_rounded))).dy,
      moreOrLessEquals(iconCenter, epsilon: 1.0),
    );
    expect(
      tester.getCenter(inCard(find.textContaining('已找到 · '))).dy,
      moreOrLessEquals(iconCenter, epsilon: 1.0),
    );
  });

  testWidgets('标记后可以改回进行中', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[
        buildMyPost(id: 'local-1', status: PostStatus.resolved),
      ],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    // 已完成的卡片上能看到「改回进行中」这个入口。
    expect(find.text('改回进行中'), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('profile-revert-local-1')));
    expect(find.byKey(const Key('profile-revert-dialog')), findsOneWidget);
    expect(find.text('改回「进行中」？'), findsOneWidget);

    // 先取消：状态不动。
    await tapAt(tester, find.text('取消'));
    expect(posts.posts.single.status, PostStatus.resolved);

    await tapAt(tester, find.byKey(const Key('profile-revert-local-1')));
    await tapAt(tester, find.byKey(const Key('profile-confirm-action')));

    expect(posts.posts.single.status, PostStatus.pending);
    // 回到未完成的样子：又能标记了。
    expect(find.byKey(const Key('profile-resolve-local-1')), findsOneWidget);
    expect(find.text('标记已找到'), findsOneWidget);
  });

  testWidgets('招领信息标记的是「已归还」', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[
        buildMyPost(id: 'local-1', title: '黑色雨伞', type: PostType.found),
      ],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    expect(find.text('标记已归还'), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('profile-resolve-local-1')));
    await tapAt(tester, find.byKey(const Key('profile-confirm-action')));

    expect(posts.posts.single.status, PostStatus.resolved);
  });

  testWidgets('修改发布内容后回到我的界面并更新仓库', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[buildMyPost(id: 'local-1', title: '蓝色保温杯')],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    await tapAt(tester, find.byKey(const Key('profile-edit-local-1')));

    expect(find.byType(PostEditPage), findsOneWidget);
    expect(find.text('修改信息'), findsOneWidget);

    // 表单已用原信息回填。
    final TextFormField title = tester.widget<TextFormField>(
      find.byKey(const Key('publish-title-field')),
    );
    expect(title.controller?.text, '蓝色保温杯');

    await typeInto(tester, const Key('publish-title-field'), '蓝色保温杯（已换杯盖）');
    await typeInto(tester, const Key('publish-location-field'), _location);
    await tapAt(tester, find.byKey(const Key('publish-submit-button')));

    // 回到「我的」，卡片与仓库都是新内容。
    expect(find.byType(PostEditPage), findsNothing);
    expect(posts.posts.single.title, '蓝色保温杯（已换杯盖）');
    expect(posts.posts.single.location, _location);
    expect(find.text('蓝色保温杯（已换杯盖）'), findsOneWidget);
  });

  testWidgets('编辑时必填项被清空则拦下并留在编辑界面', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[buildMyPost(id: 'local-1', title: '蓝色保温杯')],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    await tapAt(tester, find.byKey(const Key('profile-edit-local-1')));
    await typeInto(tester, const Key('publish-title-field'), '');
    await tapAt(tester, find.byKey(const Key('publish-submit-button')));

    expect(find.text('请填写物品名称'), findsOneWidget);
    expect(find.byType(PostEditPage), findsOneWidget);
    expect(posts.posts.single.title, '蓝色保温杯');
  });

  testWidgets('删除前先确认，确认后从仓库移除', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[buildMyPost(id: 'local-1', title: '蓝色保温杯')],
    );
    await tester.pumpWidget(buildProfile(posts: posts));

    await tapAt(tester, find.byKey(const Key('profile-delete-local-1')));
    expect(find.byKey(const Key('profile-delete-dialog')), findsOneWidget);

    // 先取消：什么都不该发生。
    await tapAt(tester, find.text('取消'));
    expect(posts.posts, hasLength(1));
    expect(find.text('蓝色保温杯'), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('profile-delete-local-1')));
    await tapAt(tester, find.byKey(const Key('profile-confirm-action')));

    expect(posts.posts, isEmpty);
    expect(find.text('蓝色保温杯'), findsNothing);
    // 删完后回到空状态。
    expect(find.byKey(const Key('profile-empty')), findsOneWidget);
  });

  testWidgets('退出登录后回到未登记状态，发布内容不受影响', (WidgetTester tester) async {
    final PostStore posts = PostStore(
      initialPosts: <ItemPost>[buildMyPost(id: 'local-1', title: '蓝色保温杯')],
    );
    final UserStore users = UserStore();
    await tester.pumpWidget(buildProfile(posts: posts, users: users));

    await tapAt(tester, find.byKey(const Key('profile-register-button')));
    await typeInto(tester, const Key('profile-name-field'), _name);
    await typeInto(tester, const Key('profile-contact-field'), _contact);
    await tapAt(tester, find.byKey(const Key('profile-register-submit')));

    await tapAt(tester, find.byKey(const Key('profile-sign-out')));
    expect(find.byKey(const Key('profile-sign-out-dialog')), findsOneWidget);
    await tapAt(tester, find.byKey(const Key('profile-confirm-action')));

    expect(users.account, isNull);
    expect(find.byKey(const Key('profile-register-button')), findsOneWidget);
    expect(find.text('蓝色保温杯'), findsOneWidget);
  });

  testWidgets('从「我的」界面可以直接去发布', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());
    await openTab(tester, '我的');

    await tapAt(tester, find.byKey(const Key('profile-go-publish')));

    // IndexedStack 会把三个标签都挂在树上，所以按键认表单，别按文案认。
    expect(find.byKey(const Key('publish-submit-button')), findsOneWidget);
    expect(find.text('带 * 的为必填项。'), findsOneWidget);
  });

  testWidgets('发布的信息会出现在「我的发布」并计入统计', (WidgetTester tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    await openTab(tester, '发布');
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
    // 时间：系统日期 / 时间选择器还没中文化，按英文 OK 确认。
    await tapAt(tester, find.byKey(const Key('publish-time-picker')));
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await typeInto(tester, const Key('publish-contact-field'), _contact);
    await tapAt(tester, find.byKey(const Key('publish-submit-button')));
    await tapAt(tester, find.byKey(const Key('publish-success-confirm')));

    await openTab(tester, '我的');

    expect(find.byKey(const Key('profile-empty')), findsNothing);
    expect(find.text(_title), findsOneWidget);
    expect(find.byType(PostCard), findsWidgets);

    final PostCard card = tester.widget<PostCard>(find.byType(PostCard).first);
    expect(card.post.isMine, isTrue);
  });
}
