import 'package:flutter/widgets.dart';

/// 本机用户在本机登记的账户信息。
///
/// 《Basic Info》「Manage」要求「我的」界面允许用户注册账户，但明令不实现实名认证；
/// 应用又还没有后端，所以这里只是一份**本机自用**的称呼与联系方式。
@immutable
class UserAccount {
  const UserAccount({
    required this.displayName,
    required this.contact,
    required this.createdAt,
  });

  /// 称呼，例如「张同学」。
  final String displayName;

  /// 常用联系方式，发布信息时作为默认值带过去。
  final String contact;

  /// 登记时间。
  final DateTime createdAt;
}

/// UI 构建阶段的账户仓库（内存实现）。
///
/// TODO(storage): 接入本地 SQLite 后改为持久化账户表 + 登录态，
/// 并给 [ItemPost] 加上发布者 id，用「是不是我发的」替代当前的 `isMine` 标记。
class UserStore extends ChangeNotifier {
  UserStore({UserAccount? initialAccount}) : _account = initialAccount;

  UserAccount? _account;

  /// 当前登记的账户；`null` 表示还没登记。
  UserAccount? get account => _account;

  /// 当前账户的常用联系方式，没有账户时为 `null`。
  String? get contact => _account?.contact;

  /// 登记 / 更新账户信息。
  void register({required String displayName, required String contact}) {
    _account = UserAccount(
      displayName: displayName.trim(),
      contact: contact.trim(),
      // 已有账户时保留首次登记时间。
      createdAt: _account?.createdAt ?? DateTime.now(),
    );
    notifyListeners();
  }

  /// 退出登录（清掉本机账户）。
  void signOut() {
    if (_account == null) {
      return;
    }
    _account = null;
    notifyListeners();
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
