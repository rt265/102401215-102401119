# UI 事项 10 修补：主界面导航按屏幕宽度在底部栏与侧边栏之间切换

对应 [ui-10-responsive.md](./ui-10-responsive.md) 上一轮**明确没做**的那一块。

## 为什么补这一刀

Flutter 文档的原话是：

> 在多种不同尺寸设备上工作时，通常应根据可用屏幕空间在 BottomNavigationBar 与
> NavigationRail 之间切换。

上一轮只做了「正文限宽 `MaxWidthBody`」，并且在文档里把外壳写成了「不改」：

> **不改**：`lib/pages/main_shell.dart`（底部 `NavigationBar` 本就应全宽）

——那句只解决了「栏本身要不要限宽」，绕过了「这个栏该不该以**底部**的形式存在」。
结果是平板 / 折叠屏展开 / 横屏上仍是底部三个标签：整条高度白吃，标签被拉得极散，
而左边那 80dp 的竖条明明空着。本轮补上这一处，限宽那部分原样不动。

`NavigationBar` 是 M3 里 `BottomNavigationBar` 的对应物（`BottomNavigationBar` 属 M2，
本项目全用 M3），所以这里的切换就是 `NavigationBar ⇄ NavigationRail`。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 断点常量 | `lib/theme/app_layout.dart` 加 `AppLayout.navigationRailBreakpoint = 600` |
| 侧边栏主题 | `lib/theme/app_theme.dart` 加 `navigationRailTheme`，配色与 `navigationBarTheme` 一致 |
| 外壳改造 | `lib/pages/main_shell.dart` 按宽度在底部栏 / 左侧栏之间切换 |
| 测试 | 新增 `test/main_shell_test.dart`（5 条）+ `test/helpers/shell_nav.dart`（`mainTab`） |

文件清单：

```
lib/
  theme/app_layout.dart        + navigationRailBreakpoint = 600（改写）
  theme/app_theme.dart         + navigationRailTheme（改写）
  pages/main_shell.dart        LayoutBuilder 分流 + _tabs 共用（改写）
test/
  main_shell_test.dart         断点两侧与切换后的状态保持（新增）
  helpers/shell_nav.dart       mainTab(label)：两种栏里都能找到标签（新增）
  publish_page_test.dart       openTab 改用 mainTab（改写）
  profile_page_test.dart       openTab 改用 mainTab（改写）
  settings_page_test.dart      端到端用例改用 mainTab（改写）
```

## 设计要点

- **断点 600**：Material 3 窗口尺寸分级里 compact（< 600）与 medium（≥ 600）的分界，
  也正好是「手机竖屏 / 平板与横屏」的实际分界——普通手机竖屏约 360–430dp 够不到它，
  平板、折叠屏展开、手机横屏都超过它。判定写成 `maxWidth >= 600`，即**正好 600 算宽屏**。
- **`LayoutBuilder` 包在整个 `Scaffold` 外面**，不是包在 `body` 里：底部栏（`bottomNavigationBar`）
  与侧边栏（`body` 的第一个子节点）是 `Scaffold` 的两个不同槽位，得先量出宽度才能决定这一帧给哪个。
- **三个标签只写一份**：`main_shell.dart` 顶层的 `const List<_Tab> _tabs` 同时喂给
  `NavigationBar` 与 `NavigationRail`，两种摆法的标签、顺序、图标不会写岔。
  `_Tab` 的顺序就是界面在 `IndexedStack` 里的下标（首页 0、发布 1、我的 2）。
- **侧边栏自己让安全区**：窄屏时顶部状态栏由各页自己的 `AppBar` 让开；换成侧边栏后
  这一栏得自己让，所以套了 `SafeArea(right: false)`——横屏下左边缘的刘海 / 挖孔同理。
  `right: false` 是因为右边缘的安全区归正文。
- **条目的 `labelType: NavigationRailLabelType.all`**（写在主题里）：三个标签都只有两个字，
  柱宽 80dp（M3 默认 `minWidth`）放得下，宽屏上没必要再藏起来。
- **配色不动**：`navigationRailTheme` 的 `backgroundColor` / `indicatorColor` 与
  `navigationBarTheme` 取同一对颜色（`surfaceContainer` / `secondaryContainer`）。
  同一套界面在两种尺寸下只是换个摆法，不该跟着换颜色。

## 测试的影响面（这一刀真正的风险点）

`flutter test` 的默认视口是 **800×600**，宽度 800 ≥ 断点 600——也就是说**默认视口就落在宽屏那一侧**。
三个测试文件原本写死了 `find.byType(NavigationBar)` 去找「发布」/「我的」标签，改造后会找不到：

- `test/publish_page_test.dart` 的 `openTab`
- `test/profile_page_test.dart` 的 `openTab`
- `test/settings_page_test.dart` 的端到端用例（那句还先 `useTallScreen` 拉到 1000 宽，更是板上钉钉在宽屏侧）

处置：新增 `test/helpers/shell_nav.dart` 的 `mainTab(label)`，断言范围是
「`NavigationBar` 或 `NavigationRail` 之内的那个标签文字」，点击逻辑一行不改。
**以后凡是要点主界面标签的测试都用它**，别再写死 `NavigationBar`。

`test/main_shell_test.dart` 覆盖 5 条：400 宽用底部栏、1000 宽用侧边栏、599/600 正好跨过断点、
侧边栏能切三个界面、以及宽屏缩回窄屏后选中项与界面状态都不丢（后者是防「把状态挪进
`LayoutBuilder` 的 builder 里」这类回归）。

## 验证

```bash
flutter analyze   # No issues found! (ran in 2.4s)
flutter test      # All tests passed!（145 条）
```

手动：用平板尺寸模拟器或把窗口拉宽，确认左侧出现侧边栏、正文占满剩余宽度且仍 ≤ 700px；
拉窄到 600 以下变回底部栏，且当前选中的标签不跳。

## 留给后续事项

- **更宽（≥ 840）换成常驻 `NavigationDrawer`**：Material 3 在 expanded 级别建议用抽屉，
  但本应用只有三个标签，侧边栏已经够用，没有证据说抽屉更好，故不做。
- **AppBar 标题随内容列居中对齐**：上一轮就留下的瑕疵，本轮不涉及。
- **宽屏双栏分栏**（左列表 + 右详情）：仍是更大的一轮，见 [ui-10-responsive.md](./ui-10-responsive.md)。
