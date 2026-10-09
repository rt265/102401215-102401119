/// 全应用通用的界面文案（多个界面共用的那几个词）。
///
/// 文案集中放在 `lib/l10n/` 下，**界面与测试引用同一份常量**：
/// 改文案只改这里一处，测试不会再因为「换了个说法」而失败
/// （约定见 docs/agents/dev-01-copy-decoupling.md）。
///
/// 只放「多个界面都要用」的词；只属于某个界面的文案放在它自己的
/// `*_strings.dart` 里。枚举自带的 `label`（如 `PostType.lost.label`）
/// 本身就是常量，不再搬到这里。
abstract final class CommonStrings {
  /// 各次级界面 AppBar 上返回键的 tooltip。
  static const String backTooltip = '返回';

  /// 详情页图片查看器右上角关闭键的 tooltip。
  static const String closeTooltip = '关闭';

  /// 各类确认弹窗的取消按钮。
  static const String cancel = '取消';

  /// 退出登录确认弹窗的确认按钮。
  static const String exit = '退出';

  /// 「我的」界面右上角齿轮的 tooltip，同时是设置界面的标题。
  static const String settings = '设置';

  /// 底部导航栏的三项。
  static const String tabHome = '首页';
  static const String tabPublish = '发布';
  static const String tabProfile = '我的';
}
