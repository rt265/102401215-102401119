import 'package:flutter/widgets.dart';

/// 布局级常量（区别于 [AppTheme] 的「配色」——这里管「宽度/断点」）。
///
/// 对应《Basic Info》「UI」优先级列表第 10 项：响应式设计。
/// 应用只有 Android / iOS，所谓「宽屏」就是平板、折叠屏、横屏、iPad——
/// 正文内容不该被拉到整屏宽，超过 [maxContentWidth] 就居中、按此宽度排。
abstract final class AppLayout {
  /// 正文内容列的最大宽度（逻辑像素）。
  ///
  /// 手机（约 360–411dp）不受影响（屏幕本来就比它窄）；平板/横屏等更宽的
  /// 设备上，各页正文由 [MaxWidthBody] 包一层、居中并卡到这个宽度。
  static const double maxContentWidth = 700;
}
