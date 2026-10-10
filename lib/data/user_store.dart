import 'package:flutter/widgets.dart';

import '../models/user_account.dart';
import 'user_repository.dart';

/// 账户仓库。
///
/// 内存里留一份账户给界面**同步**读取（「我的」界面、发布界面的默认联系方式），
/// 有仓储时每次改动都顺手写进本地库，启动时用 [load] 读回上次登记的账户。
class UserStore extends ChangeNotifier {
  /// [repository] 为空时是纯内存实现（测试与预览用）；
  /// [initialAccount] 可以直接给一份初始账户，配合 [repository] 使用时以库里的为准。
  UserStore({UserRepository? repository, UserAccount? initialAccount})
    // 不能写成 `this._repository`：命名参数用私有写法后，`main()` 与测试就没法用
    // `repository:` 传参了。
    // ignore: prefer_initializing_formals
    : _repository = repository,
      _account = initialAccount;

  final UserRepository? _repository;

  UserAccount? _account;

  /// 当前登记的账户；`null` 表示还没登记。
  UserAccount? get account => _account;

  /// 当前账户的常用联系方式，没有账户时为 `null`。
  String? get contact => _account?.contact;

  /// 从本地库读回账户。
  ///
  /// 启动时调一次（`main()`）；纯内存实现下什么都不做。
  Future<void> load() async {
    final UserRepository? repository = _repository;
    if (repository == null) {
      return;
    }

    _account = await repository.loadAccount();
    notifyListeners();
  }

  /// 登记 / 更新账户信息。
  ///
  /// 先改内存并通知界面，再落库——界面不用等磁盘，写库出错会从这个 Future 抛出。
  Future<void> register({
    required String displayName,
    required String contact,
  }) async {
    final UserAccount account = UserAccount(
      id: _account?.id ?? 'user-${DateTime.now().microsecondsSinceEpoch}',
      displayName: displayName.trim(),
      contact: contact.trim(),
      // 已有账户时保留首次登记时间。
      createdAt: _account?.createdAt ?? DateTime.now(),
    );
    _account = account;
    notifyListeners();

    final UserRepository? repository = _repository;
    if (repository != null) {
      await repository.saveAccount(account);
    }
  }

  /// 退出登录（清掉本机账户）。
  Future<void> signOut() async {
    if (_account == null) {
      return;
    }
    _account = null;
    notifyListeners();

    final UserRepository? repository = _repository;
    if (repository != null) {
      await repository.clearAccount();
    }
  }
}

/// 把 [UserStore] 沿 widget 树下发。
///
/// 与 [PostScope] 一样用 [InheritedNotifier]：账户变化后依赖它的界面自动重建。
class UserScope extends InheritedNotifier<UserStore> {
  const UserScope({super.key, required UserStore store, required super.child})
    : super(notifier: store);

  /// 取当前账户仓库并订阅它的变化。
  static UserStore of(BuildContext context) {
    final UserStore? store = maybeOf(context);
    assert(store != null, '未找到 UserScope：页面需要放在 LostAndFoundApp 之下。');
    return store!;
  }

  /// 取当前账户仓库；不在 [UserScope] 之下时返回 `null`。
  ///
  /// 账户只是「发布时带一个默认联系方式」这类锦上添花的功能，
  /// 页面（如发布界面）不该因为它缺席就报错，所以提供这个宽松版本。
  static UserStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UserScope>()?.notifier;
}
