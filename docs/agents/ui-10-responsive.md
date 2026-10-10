# UI 事项 10：响应式设计（统一限宽 + 自适应网格）

> **后续修补**：本轮把 `lib/pages/main_shell.dart` 写成了「不改」，只做了正文限宽。
> 之后的 [ui-10-navigation-rail.md](./ui-10-navigation-rail.md) 补上了「主界面导航按宽度
> 在底部 `NavigationBar` 与左侧 `NavigationRail` 之间切换」那部分；本文中「不改 main_shell.dart」
> 一句**已被那一轮推翻**，其余内容仍然有效。

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 10 项
「优化面向平板等视口宽度较长设备的响应式设计」。

## 本轮目标

应用只面向 Android / iOS（无 web / desktop），所谓「宽屏」就是平板、折叠屏、横屏、iPad。
此前所有页面正文都是**全宽**的 `ListView` / `Column` / `SingleChildScrollView`，唯一的横向
控制是各处手写重复的 16px 边距，没有任何 `LayoutBuilder` / `maxWidth` / 断点。结果是宽屏上
文字、卡片、表单字段被拉到整屏宽，固定尺寸元素（照片九宫格固定 3 列、详情页头图固定 240 高）
也显得过宽。

本轮按用户选择「**统一限宽 + 自适应网格**」实施：给所有页面正文加一个共享的最大内容宽度容器，
并把照片九宫格从固定列数改成按可用宽度自适应。

范围决策（**不做宽屏双栏分栏**）：不把列表页拆成「左列表 + 右详情」这类多栏布局，那是后续更大
的一轮。本轮只解决「内容不该被拉到整屏宽」这一件事，改动小、回归风险低。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 布局常量 | 新增 `lib/theme/app_layout.dart`：`AppLayout.maxContentWidth = 700` |
| 限宽容器 | 新增 `lib/widgets/max_width_body.dart`：`MaxWidthBody` 把正文卡到最大宽度并居中 |
| 各页正文 | 9 个页面 / 表单的正文包进 `MaxWidthBody`，内部 16px 边距保持不变 |
| 照片网格 | 发布表单的九宫格从固定 3 列改为 `SliverGridDelegateWithMaxCrossAxisExtent` |

## 文件清单

```
lib/
  theme/app_layout.dart        最大内容宽度常量（新增）
  widgets/max_width_body.dart  限宽 + 居中的共享容器（新增）
  pages/home_page.dart         正文 Column 包 MaxWidthBody（改写）
  pages/search_page.dart       正文 Column 包 MaxWidthBody（改写）
  pages/profile_page.dart      正文 ListView 包 MaxWidthBody（改写）
  pages/post_detail_page.dart  主 ListView + 删除态两处包 MaxWidthBody（改写）
  pages/settings_page.dart     正文 ListView 包 MaxWidthBody（改写）
  pages/appearance_page.dart   正文 ListView 包 MaxWidthBody（改写）
  pages/account_page.dart      正文 ListView 包 MaxWidthBody（改写）
  pages/about_page.dart        正文 ListView 包 MaxWidthBody（改写）
  widgets/post_form.dart       正文 SingleChildScrollView 包 MaxWidthBody + 网格自适应（改写）
```

**当时不改**（底部 `NavigationBar` 全宽）**、后由 [ui-10-navigation-rail.md](./ui-10-navigation-rail.md)
推翻**：`lib/pages/main_shell.dart`。`lib/pages/publish_page.dart` 与
`lib/pages/post_edit_page.dart` 至今仍不改（都直接放 `PostForm`，
由 `post_form.dart` 那一处覆盖）。

## 设计要点

- **用 `Align(topCenter)` 而不是 `Center`**：两者都能水平居中并掐宽度，但 `Center` 会把高度
  收缩的 `SingleChildScrollView`（发布 / 编辑表单）**垂直顶到屏幕中间**，表单像浮在半空；
  `Align(alignment: Alignment.topCenter)` 让所有正文都贴顶。对 `ListView`、带 `Expanded` 的
  `Column`、`SingleChildScrollView` 三种正文，`topCenter` 都成立。
- **`maxContentWidth = 700`**：手机（约 360–411dp）本来就比它窄，包上等于没变化；平板 / 横屏等
  更宽的设备上正文居中成一列。700 是「正文可读行宽」的一个常用上限，也不至于让详情页头图（240 高）
  显得过窄。
- **AppBar 保持全宽不动**：这是 Material 的常规行为。代价是宽屏上 AppBar 标题仍靠左、
  不与内容列居中对齐，属可接受的小瑕疵，记入「留给后续」。
- **九宫格 `maxCrossAxisExtent: 140`**：手机（360–411dp，内容列宽约 328–379px）仍约 3 列
  （格子 ~110–130px，与现状一致）；内容列上限 700px 时自动长到约 5 列（格子 ~130px），
  不再出现平板上一排 3 个巨格。间距 8、正方形（`childAspectRatio: 1`）不变。

## 验证

本机 Flutter 不在 PATH，尚未在本机跑；需在有 Flutter 的环境执行：

```bash
flutter pub get
flutter analyze
flutter test
```

预期测试全绿：测试套件**没有任何宽度 / 坐标断言**，点击都是相对控件中心的
（`getCenter` / `tester.tap`），限宽居中不改变查找逻辑。唯一一处垂直 `.dy` 几何断言
（`test/profile_page_test.dart`「状态与图标同一水平线」）在 800px 默认视口下正文只窄 100px、
仍是一行，风险低；若因纵向换行失败，按现状放宽那行的宽即可。

手动：用平板尺寸模拟器或把窗口拉宽，确认首页 / 详情 / 发布表单 / 设置等正文居中且 ≤700px、
九宫格在宽屏下变为 4–5 列。

## 留给后续事项

- 宽屏**双栏分栏**（如列表页左栏列表 + 右栏详情）：本轮未做，属更大一轮。
- AppBar 标题随内容列居中对齐：本轮接受「标题靠左」的小瑕疵。
