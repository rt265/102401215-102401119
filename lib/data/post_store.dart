import 'package:flutter/widgets.dart';

import '../models/item_post.dart';
import '../models/post_query.dart';
import 'item_repository.dart';
import 'mock_posts.dart';

/// 信息仓库。
///
/// 界面上的筛选是**即时**的（点一下类型就该出结果，不该等一次异步查询），
/// 所以这里留一份内存快照给三大主界面同步读取，有仓储时每次改动顺手写进本地库，
/// 启动时用 [load] 把库里的信息读进来。
///
/// 接入本地 SQLite 之前，本类就是那个「唯一的仓库」；现在它多了个落库的方向，
/// 界面层的用法一点没变。
class PostStore extends ChangeNotifier {
  /// [repository] 为空时是纯内存实现：不给 [initialPosts] 就用示例数据
  /// （测试与预览走这条）；传了仓储则以库里的内容为准，等 [load] 读回来。
  PostStore({ItemRepository? repository, List<ItemPost>? initialPosts})
    : _repository = repository,
      _posts = List<ItemPost>.of(
        initialPosts ??
            (repository == null ? buildMockPosts() : const <ItemPost>[]),
      );

  final ItemRepository? _repository;

  final List<ItemPost> _posts;

  /// 当前全部信息，最新发布的排在最前。
  List<ItemPost> get posts => List<ItemPost>.unmodifiable(_posts);

  /// 按 id 取一条信息，不存在时返回 `null`。
  ///
  /// 详细信息界面据此订阅仓库：同一条信息被标记或修改后，
  /// 已经打开的详情也会跟着更新；信息被删除则返回 `null`。
  ItemPost? postById(String id) {
    for (final ItemPost post in _posts) {
      if (post.id == id) {
        return post;
      }
    }
    return null;
  }

  /// 从本地库把信息读进内存。
  ///
  /// 启动时调一次（`main()`）；纯内存实现下什么都不做。
  Future<void> load() async {
    final ItemRepository? repository = _repository;
    if (repository == null) {
      return;
    }

    _posts
      ..clear()
      ..addAll(await repository.queryPosts(const PostQuery()));
    notifyListeners();
  }

  /// 新增一条信息，并通知依赖它的界面刷新。
  ///
  /// 内存先改、界面立刻能看到，随后落库。
  Future<void> addPost(ItemPost post) async {
    _posts.insert(0, post);
    notifyListeners();
    await _persist((ItemRepository repository) => repository.insertPost(post));
  }

  /// 整体替换同 id 的信息（编辑保存、标记状态都走这里）。
  ///
  /// 找不到 id 时什么都不做——信息可能刚被删掉，不必抛异常打断界面。
  Future<void> updatePost(ItemPost post) async {
    final int index = _posts.indexWhere((ItemPost item) => item.id == post.id);
    if (index < 0) {
      return;
    }
    _posts[index] = post;
    notifyListeners();
    await _persist((ItemRepository repository) => repository.updatePost(post));
  }

  /// 删除一条信息，并通知依赖它的界面刷新。
  Future<void> removePost(String id) async {
    final int before = _posts.length;
    _posts.removeWhere((ItemPost post) => post.id == id);
    if (_posts.length == before) {
      return;
    }
    notifyListeners();
    await _persist((ItemRepository repository) => repository.deletePost(id));
  }

  /// 把改动落到本地库。
  ///
  /// 纯内存实现（没有仓储）时什么都不做。写库失败不吞：
  /// 内存里的改动还在，错误从这个方法返回的 Future 抛给调用方。
  Future<void> _persist(
    Future<void> Function(ItemRepository repository) write,
  ) async {
    final ItemRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    await write(repository);
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
    final PostScope? scope = context
        .dependOnInheritedWidgetOfExactType<PostScope>();
    assert(scope != null, '未找到 PostScope：页面需要放在 LostAndFoundApp 之下。');
    return scope!.notifier!;
  }
}
