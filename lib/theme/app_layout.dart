/// 布局级常量（区别于 [AppTheme] 的「配色」——这里管「宽度/断点」）。
///
/// 对应《Basic Info》「UI」优先级列表第 10 项：响应式设计。
/// 应用只有 Android / iOS，所谓「宽屏」就是平板、折叠屏、横屏、iPad——
/// 正文内容不该被拉到整屏宽，超过 [maxContentWidth] 就居中、按此宽度排。
///
/// 本文件只有常量，`MaxWidthBody` 只出现在文档注释里（dartdoc 引用不算使用），
/// 所以这里**不要** import `package:flutter/widgets.dart`——那样 `flutter analyze`
/// 会报 `unused_import`。
abstract final class AppLayout {
  /// 正文内容列的最大宽度（逻辑像素）。
  ///
  /// 手机（约 360–411dp）不受影响（屏幕本来就比它窄）；平板/横屏等更宽的
  /// 设备上，各页正文由 [MaxWidthBody] 包一层、居中并卡到这个宽度。
  static const double maxContentWidth = 700;

  /// 主界面导航从底部栏切成侧边栏的宽度阈值（逻辑像素）。
  ///
  /// 低于它用底部 [NavigationBar]（手机竖屏），达到或超过它用左侧 `NavigationRail`
  /// ——这是 Flutter 对「同一套界面跑在不同尺寸设备上」的常规做法：宽屏上底部导航栏
  /// 会把三个标签拉得极散、还白吃掉一整条高度，换成侧边栏就把这段空间还给了正文。
  ///
  /// 600 是 Material 3 窗口尺寸分级里 compact（< 600）与 medium（≥ 600）的分界，
  /// 也是「手机竖屏 / 平板与横屏」的实际分界：普通手机竖屏约 360–430dp，够不到它；
  /// 平板、折叠屏展开、手机横屏都超过了它。
  ///
  /// 本文件只有常量，所以**不要** import `package:flutter/material.dart`——那样
  /// `flutter analyze` 会报 `unused_import`（[NavigationBar] 只是文档引用，不算使用）。
  static const double navigationRailBreakpoint = 600;
}
