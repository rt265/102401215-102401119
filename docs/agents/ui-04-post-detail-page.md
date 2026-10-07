# UI 事项 4：详细信息界面

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 4 项「构建详细信息界面」，
需求原文见「View Detail」：**用户能够查看物品的详细信息及发布者提供的联系方式**。

## 本轮目标

- 做出详情页主体：一条信息的全部内容（物品信息、描述、联系方式）在一屏里读完。
- **联系方式是本页唯一需要用户动手的地方**，给它一键复制（卡片上的图标按钮 + 底部大按钮）。
- 把入口接上：首页卡片、「我的发布」卡片点进去都是这里。
- 详情页是**活视图**而不是快照：信息在别处被改 / 被删，已经打开的详情要跟着变。
- 明确本轮**不做**的事：详情页不放管理入口（标记 / 修改 / 删除仍只在「我的」），
  不建数据库、不实现图片、不动搜索界面。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 详细信息界面 `PostDetailPage` | `AppBar(物品名称)` + 返回按钮；正文从上到下：图标位 → 类型徽标 → 标题 → 发布时间 → 完成提示（仅已完成）→ 物品信息 → 物品描述 → 联系方式 → 联系须知 → 底部复制按钮 |
| 物品信息卡 `_InfoCard` | 三行：物品分类 / 地点（失物「丢失地点」、招领「拾取地点」）/ 时间（同上规则，值由 `_eventTimeText()` 格式化） |
| 描述卡 `_DescriptionCard` | 空描述显示斜体说明，不留白 |
| 联系方式卡 `_ContactCard` | `primaryContainer` 底色突出；标签随归属变化（「你留下的联系方式」/「发布者留下的联系方式」）；`SelectableText` 可选中；右侧复制图标按钮 |
| 完成提示 `_Notice` | 已完成时给「这条信息已完成（已找到 / 已归还）」+ 说明；另有一块「联系时请注意」，文案随类型变化 |
| 删除空态 `_DeletedState` | 信息被删除后显示「这条信息已被删除」+ 可选「回到首页」 |
| 仓库补全 `PostStore` | 新增 `postById(String id)`，详情页据此订阅仓库 |
| 入口联动 | 首页 `PostCard.onTap`、`MyPostCard` 卡片本体都得跳详情；`MainShell` / `ProfilePage` / `HomePage` 逐层把 `onGoHome` 传给详情页的空态 |

## 文件清单

```
lib/
  pages/post_detail_page.dart   详细信息界面（新增，本轮主体）
  data/post_store.dart          新增 postById()
  pages/home_page.dart          新增 _openDetail()，给 PostCard 接上 onTap；新增 onGoHome 透传
  widgets/my_post_card.dart     卡片本体接上详情入口（管理按钮保持原样）
  pages/main_shell.dart         HomePage(onGoHome: _goHome)
  pages/profile_page.dart       新增 onGoHome 并透传给 MyPostCard
test/
  post_detail_page_test.dart    详情页 12 个 widget 测试（新增）
```

## 设计要点

- **详情页按 id 现查仓库，不认传进来的快照**：`PostDetailPage` 只收一个 `postId`，
  内部 `PostScope.of(context).postById(postId)`。
  一开始的版本多收了一个 `initial`（仓库查不到时的兜底快照），结果它会把「已被删除」这件事
  盖掉——调用方永远传得出快照，空态就永远不出现。
  去掉 `initial` 之后语义只剩一条：**仓库是唯一数据源**。
  好处是三件事一起成立：详情页随仓库变化、信息被删能落到空态、调用方不必关心传什么。
  （测试里也就不用再造一份假数据，`pumpDetail` 把信息放进仓库即可。）
- **空态按钮先退栈再回调**：「回到首页」不能只调外壳给的 `onGoHome`——那样详情页还压在栈上，
  点完看着像没反应。所以动作是 `Navigator.pop()` 再 `onGoHome!()`。
  首页自己进来时 `onGoHome` 也一样传（`HomePage(onGoHome:)`），
  这样从「我的」进来的详情才有得回；`onGoHome` 为 `null`（单独渲染详情页）时不显示这个按钮。
- **返回键用显式 `IconButton` + `Key`**：项目还没接 `flutter_localizations`，
  `BackButton` 的 tooltip 是英文，测试里按文案找不到。自带的 `detail-back-button` 顺带把
  「返回」说得比系统默认更清楚。
- **联系方式的归属用 `isMine` 分辨**，文案跟着变；`SelectableText` 让用户能手动选中，
  但**复制按钮才是主路径**（`Clipboard.setData` + SnackBar「联系方式已复制」），
  底部再放一个大按钮重复同一动作——手机上一屏读完后手指就在底部。
- **时间显示的取舍**：`_eventTimeText()` 只在事件发生在最近两天内用
  `formatEventTime()`（「今天 09:30」这类相对说法更好读），更早则退回 `formatDateTime()`
  的绝对时间——「3 天前 09:30」反而没人算得清是哪天。
- **信息不存在时也给一条出路**：空态除了说明，还提供「回到首页」；
  `AppBar` 标题退化成「信息详情」。
- **测试视口要调高**：详情页是 `ListView`（内容多，用懒加载是对的），
  但 800×600 的默认视口装不下，联系方式**根本不进 widget 树**，
  `find.byKey` 找不到、`ensureVisible` 直接抛 `Bad state: No element`。
  `pumpDetail()` 里 `setSurfaceSize(Size(800, 1600))` + `addTearDown` 复原即可。
  改视口而不是改页面结构，测试验的才是真实布局。

## 尚未实现 / 留给后续事项

- 搜索界面（事项 5）仍是 `ComingSoon` 占位，首页搜索入口进去还是「建设中」。
- 应用设置界面（事项 7）**已完成**（[ui-07-settings-page.md](./ui-07-settings-page.md)）；
  系统级控件（日期 / 时间选择器）仍是英文（中文化未做）。
- 详情页**没有**管理入口（标记 / 修改 / 删除）：这是刻意的，同一条信息不留两套管理入口，
  要改就回「我的」。若将来在详情页加「编辑」，应复用 `PostEditPage`，不要另写表单。
- 图片（选填）未实现：详情页顶部的 `_Hero` 是分类图标占位，`TODO(image)`。
- 数据只在内存里，重启即丢（`TODO(storage)`）；联系方式也只是本机登记的文本，
  没有即时聊天 / 地图定位（《Basic Info》的 WARN 明确不要求）。
- 「联系时请注意」是静态文案，没有做防诈骗 / 举报入口。

## 验证

```bash
flutter analyze
flutter test
```

**最近一次验证结果（本轮）**：

- `flutter analyze` → `No issues found! (ran in 0.9s)`
- `flutter test` → `00:04 +37: All tests passed!`（首页 6 + 发布 6 + 我的 13 + 详情 12 共 37 个）

注意：这两个命令在受限沙箱下会因无法启动分析器 / 测试子进程而失败
（`CreateFile failed 5 ... 拒绝访问。(process_win.cc:744)`），
需在放宽权限（danger-full-access）下运行或由用户手动执行，详见 basic-info.md 的环境备忘。

新增的 `test/post_detail_page_test.dart` 覆盖：

1. 首页点卡片进入详细信息界面（筛选器不跟过来）；
2. 详情页集中展示物品信息与发布者联系方式（分类 / 地点 / 时间 / 描述 / 联系方式 / 复制入口）；
3. 失物信息的字段文案与招领区分（「丢失地点」「丢失时间」「请直接联系失主」）；
4. 复制按钮把联系方式写进剪贴板并提示；
5. 页脚大按钮同样能复制联系方式；
6. 已完成的信息给出「已归还」说明，标记随类型变化；
7. 自己发布的信息在详情页标注「你留下的联系方式」；
8. 描述为空时给出说明而不是空白；
9. 仓库里改动同一条信息后，已打开的详情随之更新；
10. 查看期间信息被删除时给出空态；
11. 返回后回到首页列表；
12. 端到端：从「我的发布」点卡片进详情，回去改完描述再进详情，看到的是改后的内容。

上一轮的 `test/widget_test.dart`（6 个首页测试）、`test/publish_page_test.dart`（6 个发布测试）、
`test/profile_page_test.dart`（13 个我的测试）在改动后**全部保持通过**，未做任何改动。

### 测试环境上的两个坑（后继事项会再遇到）

- **`Clipboard.setData` 在测试里永远不完成**：测试环境没有真的系统剪贴板，
  也没人接管 `SystemChannels.platform`，这个 Future 会一直挂着，
  于是复制按钮后面的 SnackBar 再也不出现（表现为「点了没反应」）。
  需要在 `setUp` 里 `TestDefaultBinaryMessengerBinding...setMockMethodCallHandler(SystemChannels.platform, ...)`
  接管通道，并在 `tearDown` 里置回 `null`。
  注意这条通道上还有系统 UI / 无障碍等别的调用，**只记录 `Clipboard.setData` 那一条**，
  否则断言「调用了一次」会被无关调用顶掉。
- **单独渲染 `ProfilePage` 要连 `UserScope` 一起给**：它自己会去 `UserScope.of()`，
  只包 `PostScope` 会在 build 里断言失败。`test/profile_page_test.dart` 里已有辅助函数可参考。
