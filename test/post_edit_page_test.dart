import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/post_store.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/pages/post_edit_page.dart';

const String _title = '蓝色保温杯';
const String _location = '第二食堂二楼';
const String _contact = '微信 umbrella_zhang';
const String _description = '杯盖是白色的。';

/// 造一条本机用户发布的信息。
ItemPost buildMyPost({
  String id = 'local-1',
  String title = _title,
  ItemCategory category = ItemCategory.daily,
}) {
  final DateTime now = DateTime.now();
  return ItemPost(
    id: id,
    type: PostType.lost,
    title: title,
    category: category,
    location: _location,
    eventTime: now.subtract(const Duration(hours: 3)),
    contact: _contact,
    createdAt: now.subtract(const Duration(hours: 1)),
    description: _description,
    isMine: true,
  );
}

/// 编辑界面的「上一页」。
///
/// 真实入口是「我的」界面卡片上的「修改」，这里只留下推入 / 弹回这一段，
/// 好把断言集中在这一个界面上。
class _EditorHost extends StatefulWidget {
  const _EditorHost({required this.post, required this.onPoppedBack});

  final ItemPost post;

  /// 编辑界面弹回来时回调：保存时是改好的那条，取消返回时是 null。
  final ValueChanged<ItemPost?> onPoppedBack;

  @override
  State<_EditorHost> createState() => _EditorHostState();
}

class _EditorHostState extends State<_EditorHost> {
  Future<void> _open() async {
    final ItemPost? updated = await Navigator.of(context).push<ItemPost>(
      MaterialPageRoute<ItemPost>(
        builder: (_) => PostEditPage(post: widget.post),
      ),
    );
    if (!mounted) {
      return;
    }
    widget.onPoppedBack(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-editor-button'),
          onPressed: _open,
          child: const Text('修改'),
        ),
      ),
    );
  }
}

/// 装好宿主并推进编辑界面。
Future<void> openEditor(
  WidgetTester tester, {
  ItemPost? post,
  PostStore? posts,
  ValueChanged<ItemPost?>? onPoppedBack,
}) async {
  await tester.pumpWidget(
    PostScope(
      store: posts ?? PostStore(initialPosts: <ItemPost>[]),
      child: MaterialApp(
        home: _EditorHost(
          post: post ?? buildMyPost(),
          onPoppedBack: onPoppedBack ?? (_) {},
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-editor-button')));
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

/// 改标题。
Future<void> retitle(WidgetTester tester, String title) =>
    typeInto(tester, const Key('publish-title-field'), title);

/// 读标题输入框里当前的文字。
String titleText(WidgetTester tester) {
  final EditableText editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('publish-title-field')),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

/// 某个分类是否被选中。
bool chipSelected(WidgetTester tester, ItemCategory category) => tester
    .widget<ChoiceChip>(find.byKey(Key('publish-category-${category.name}')))
    .selected;

/// 「还原」按钮当前能不能点。
bool restoreEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.byKey(const Key('edit-restore-button')))
        .onPressed !=
    null;

/// 编辑界面还在不在。
bool editorOpen() => find.byType(PostEditPage).evaluate().isNotEmpty;

void main() {
  testWidgets('打开编辑界面时回填原信息，没改动可以直接返回', (WidgetTester tester) async {
    ItemPost? returned;
    bool cameBack = false;
    await openEditor(
      tester,
      onPoppedBack: (ItemPost? updated) {
        returned = updated;
        cameBack = true;
      },
    );

    expect(find.text('修改信息'), findsOneWidget);
    expect(titleText(tester), _title);
    expect(find.text(_location), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);

    // 一个字没改：「还原」没什么可还原的，置灰；返回也不追问。
    expect(restoreEnabled(tester), isFalse);
    await tapAt(tester, find.byKey(const Key('edit-cancel-button')));

    expect(find.byKey(const Key('edit-discard-dialog')), findsNothing);
    expect(editorOpen(), isFalse);
    expect(cameBack, isTrue);
    expect(returned, isNull);
  });

  testWidgets('改动后「还原」要先确认，取消则保留改动', (WidgetTester tester) async {
    await openEditor(tester);

    await retitle(tester, '蓝色保温杯（已换杯盖）');
    await tapAt(tester, find.byKey(const Key('publish-category-digital')));

    // 有改动了，「还原」可以点了。
    expect(restoreEnabled(tester), isTrue);

    await tapAt(tester, find.byKey(const Key('edit-restore-button')));
    expect(find.byKey(const Key('edit-restore-dialog')), findsOneWidget);
    expect(find.text('还原为打开时的内容？'), findsOneWidget);

    // 选「继续编辑」：表单保持改过的样子。
    await tapAt(tester, find.byKey(const Key('edit-dialog-cancel')));
    expect(editorOpen(), isTrue);
    expect(titleText(tester), '蓝色保温杯（已换杯盖）');
    expect(chipSelected(tester, ItemCategory.digital), isTrue);
    expect(restoreEnabled(tester), isTrue);
  });

  testWidgets('确认「还原」后表单退回打开时的内容', (WidgetTester tester) async {
    final PostStore store = PostStore(initialPosts: <ItemPost>[buildMyPost()]);
    await openEditor(tester, posts: store);

    await retitle(tester, '蓝色保温杯（已换杯盖）');
    await tapAt(tester, find.byKey(const Key('publish-category-digital')));

    await tapAt(tester, find.byKey(const Key('edit-restore-button')));
    await tapAt(tester, find.byKey(const Key('edit-dialog-confirm')));

    expect(titleText(tester), _title);
    expect(find.text(_description), findsOneWidget);
    expect(chipSelected(tester, ItemCategory.daily), isTrue);
    expect(chipSelected(tester, ItemCategory.digital), isFalse);
    expect(find.text('已还原为打开时的内容'), findsOneWidget);

    // 还原只是把表单改回去：仓库里的信息一直没动，改动标记也随之收回。
    expect(store.posts.single.title, _title);
    expect(restoreEnabled(tester), isFalse);

    // 还原之后返回，同样不再追问。
    await tapAt(tester, find.byKey(const Key('edit-cancel-button')));
    expect(find.byKey(const Key('edit-discard-dialog')), findsNothing);
    expect(editorOpen(), isFalse);
  });

  testWidgets('有未保存的改动时返回先确认，选「继续编辑」就留下', (WidgetTester tester) async {
    await openEditor(tester);

    await retitle(tester, '蓝色保温杯（已换杯盖）');
    await tapAt(tester, find.byKey(const Key('edit-cancel-button')));

    expect(find.byKey(const Key('edit-discard-dialog')), findsOneWidget);
    expect(find.text('放弃这次修改？'), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('edit-dialog-cancel')));

    expect(editorOpen(), isTrue);
    expect(titleText(tester), '蓝色保温杯（已换杯盖）');
  });

  testWidgets('确认「放弃修改」后才离开编辑界面，仓库不变', (WidgetTester tester) async {
    final PostStore store = PostStore(initialPosts: <ItemPost>[buildMyPost()]);
    ItemPost? returned;
    bool cameBack = false;
    await openEditor(
      tester,
      posts: store,
      onPoppedBack: (ItemPost? updated) {
        returned = updated;
        cameBack = true;
      },
    );

    await retitle(tester, '蓝色保温杯（已换杯盖）');
    await tapAt(tester, find.byKey(const Key('edit-cancel-button')));
    await tapAt(tester, find.byKey(const Key('edit-dialog-confirm')));

    expect(editorOpen(), isFalse);
    expect(store.posts.single.title, _title);
    // 没保存就返回，上一页拿到的是 null，不会误报「已更新」。
    expect(cameBack, isTrue);
    expect(returned, isNull);
  });

  testWidgets('系统返回键同样被拦下并确认', (WidgetTester tester) async {
    await openEditor(tester);

    await retitle(tester, '蓝色保温杯（已换杯盖）');

    // 模拟系统返回（返回键 / 返回手势）：走的是 PopScope，不是界面上的返回按钮。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-discard-dialog')), findsOneWidget);
    expect(editorOpen(), isTrue);

    await tapAt(tester, find.byKey(const Key('edit-dialog-confirm')));
    expect(editorOpen(), isFalse);
  });

  testWidgets('保存后更新仓库，并把改好的信息交回上一页', (WidgetTester tester) async {
    final PostStore store = PostStore(initialPosts: <ItemPost>[buildMyPost()]);
    ItemPost? returned;
    await openEditor(
      tester,
      posts: store,
      onPoppedBack: (ItemPost? updated) => returned = updated,
    );

    await retitle(tester, '蓝色保温杯（已换杯盖）');
    await tapAt(tester, find.byKey(const Key('publish-submit-button')));

    // 保存是「直接走」：不会弹「放弃修改？」。
    expect(find.byKey(const Key('edit-discard-dialog')), findsNothing);
    expect(editorOpen(), isFalse);
    expect(store.posts.single.title, '蓝色保温杯（已换杯盖）');
    expect(returned?.title, '蓝色保温杯（已换杯盖）');
  });

  testWidgets('只是多打了空格不算改动', (WidgetTester tester) async {
    await openEditor(tester);

    await retitle(tester, '$_title ');
    expect(restoreEnabled(tester), isFalse);

    // 改掉又改回来，同样不算改动。
    await retitle(tester, '蓝色折叠伞');
    expect(restoreEnabled(tester), isTrue);
    await retitle(tester, _title);
    expect(restoreEnabled(tester), isFalse);

    await tapAt(tester, find.byKey(const Key('edit-cancel-button')));
    expect(find.byKey(const Key('edit-discard-dialog')), findsNothing);
    expect(editorOpen(), isFalse);
  });
}
