import 'package:flutter/foundation.dart';

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
