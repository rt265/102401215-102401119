import 'package:flutter/widgets.dart';

import '../models/item_post.dart';
import 'mock_posts.dart';

/// UI 构建阶段的信息仓库（内存实现）。
///
/// 三大主界面共用同一份信息：发布界面写入，首页读取，
/// 这样在还没有本地存储的情况下，「发布 → 浏览」的流程也能走通。
///
/// TODO(storage): 接入本地 SQLite 后，本类由 `ItemRepository` 取代
/// （[posts] 变成查询结果，[addPost] 变成插入 + 落库），界面层用法不变。
class PostStore extends ChangeNotifier {
  PostStore({List<ItemPost>? initialPosts})
      : _posts = List<ItemPost>.of(initialPosts ?? buildMockPosts());

  final List<ItemPost> _posts;

  /// 当前全部信息，最新发布的排在最前。
  List<ItemPost> get posts => List<ItemPost>.unmodifiable(_posts);

  /// 新增一条信息，并通知依赖它的界面刷新。
  void addPost(ItemPost post) {
    _posts.insert(0, post);
    notifyListeners();
  }

  /// 整体替换同 id 的信息（编辑保存、标记状态都走这里）。
  ///
  /// 找不到 id 时什么都不做——信息可能刚被删掉，不必抛异常打断界面。
  void updatePost(ItemPost post) {
    final int index = _posts.indexWhere((ItemPost item) => item.id == post.id);
    if (index < 0) {
      return;
    }
    _posts[index] = post;
    notifyListeners();
  }

  /// 删除一条信息，并通知依赖它的界面刷新。
  void removePost(String id) {
    final int before = _posts.length;
    _posts.removeWhere((ItemPost post) => post.id == id);
    if (_posts.length != before) {
      notifyListeners();
    }
  }
}

/// 把 [PostStore] 沿 widget 树下发。
///
/// 用 [InheritedNotifier] 而不是引入第三方状态管理：仓库变化时，
/// 通过 [PostScope.of] 取过仓库的页面（首页）会自动重建。
class PostScope extends InheritedNotifier<PostStore> {
  const PostScope({super.key, required PostStore store, required super.child})
      : super(notifier: store);

  /// 取当前仓库并订阅它的变化。
  static PostStore of(BuildContext context) {
    final PostScope? scope =
        context.dependOnInheritedWidgetOfExactType<PostScope>();
    assert(scope != null, '未找到 PostScope：页面需要放在 LostAndFoundApp 之下。');
    return scope!.notifier!;
  }
}
