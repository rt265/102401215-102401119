import 'package:flutter/widgets.dart';

import '../theme/app_layout.dart';

/// 把正文内容卡到一个最大宽度并水平居中（见 [AppLayout.maxContentWidth]）。
///
/// 手机屏幕比这个宽度窄，包上它等于没变化；平板/横屏等更宽的设备上，正文
/// 不再被拉满，而是居中成一列。内部 16px 边距照旧由各页自己写。
///
/// 用 `Align(topCenter)` 而不是 `Center`：`Center` 会把高度收缩的
/// `SingleChildScrollView`（发布/编辑表单）垂直顶到中间，而 `topCenter` 让
/// 所有正文都贴顶——对 `ListView`、带 `Expanded` 的 `Column`、`SingleChildScrollView`
/// 三种正文都成立。
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
        child: child,
      ),
    );
  }
}
