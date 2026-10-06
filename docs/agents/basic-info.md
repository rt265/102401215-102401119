# Basic Info

## Core Functions

完成核心功能，使“发布信息—浏览或搜索—查看详情—联系发布者—更新状态”的基本流程清晰、可用。

### View posts

首页让可以让用户集中浏览校园里的失物/招领内容，还可通过筛选器筛选。

### Search

首页的上方的搜索栏将用户引导至搜索子界面。搜索允许用户通过物品名称等关键词进行搜索，搜索结果也可以通过筛选器筛选。

### View Detail

用户能够查看物品的详细信息及发布者提供的联系方式。

### Release Post

“发布”界面允许用户发布失物/招领信息，通过表格填充，填充不合规需要提醒。发布成功后，显式弹窗提醒发布成功。

每个信息应当包含以下内容：

- 物品名称（必填）
- 物品分类（必填）
- 地点（必选）
- 时间（必选）
- 描述（选填）
- 联系方式（必填）
- 图片（选填）

### Manage

“我的”界面允许用户注册账户并管理发布内容。

每个信息都应该提供选项：

- 在物品找回或归还后，由发布者将信息标记为“已找到”或“已归还”；
- 允许发布者修改发布内容；
- 允许发布者删除发布。

### WARN

不要求实现复杂后台管理、实名认证、即时聊天、地图定位等功能。

## UI

三大主界面：首页、发布、我的

次级界面：搜索界面（首页）、编辑界面（我的）、应用设置界面（我的）、详细信息界面

## Storage Notice

用户所有数据保存在本地 SQLite 数据库。功能在本地闭环，暂不实现与远程服务端的连接。

## Design

界面使用 Google Material Design 设计系统。

## Priority

请按照此列表分事项实现。

首先是 UI 构建。

1. 构建首页 ✅
2. 构建发布界面
3. 构建我的界面
4. 构建详细信息界面
5. 构建搜索界面
6. 构建编辑界面
7. 构建应用设置界面

## Progress

当前阶段：**UI 构建**。

| 事项 | 状态 | 文档 |
| --- | --- | --- |
| 1. 首页 | 已完成并验证 | [ui-01-home-page.md](./ui-01-home-page.md) |
| 2. 发布界面 | 未开始 | — |
| 3. 我的界面 | 未开始 | — |
| 4. 详细信息界面 | 未开始 | — |
| 5. 搜索界面 | 未开始 | — |
| 6. 编辑界面 | 未开始 | — |
| 7. 应用设置界面 | 未开始 | — |

已铺好的公共基础（后继事项可直接复用，不必重建）：

- `lib/theme/app_theme.dart`：全局 Material 3 主题（`ColorScheme.fromSeed`，种子色 `0xFF00695C`，明 / 暗两套）。
- `lib/models/item_post.dart`：`ItemPost` 及 `PostType` / `PostStatus` / `ItemCategory` 枚举，字段与上文「每个信息应当包含以下内容」一致。
- `lib/pages/main_shell.dart`：三大主界面外壳（底部 `NavigationBar` + `IndexedStack`）。
- `lib/widgets/post_card.dart`、`lib/widgets/coming_soon.dart`：信息卡片与「未开工界面」占位组件。
- `lib/utils/time_format.dart`：时间格式化工具。
- `lib/data/mock_posts.dart`：**仅在 UI 阶段**使用的示例数据，接入本地 SQLite 后应由仓储查询替换。

尚未开始的技术工作：本地 SQLite 存储与仓储层、图片选择与展示、`flutter_localizations` 中文化。

## 环境备忘（后继 Agent 必读）

- Flutter 3.47.5 / Dart 3.13.4，SDK 位于 `D:\flutter\flutter`，Dart 可执行文件在
  `D:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe`。
- **`flutter analyze` 与 `flutter test` 在受限沙箱下必定失败**（不是慢）：分析器需要启动
  `analysis_server_aot.dart.snapshot` / `flutter_tester` 子进程，沙箱下报
  `CreateFile failed 5 ... ProcessException: 拒绝访问。(process_win.cc:744)`，表现为长时间无输出的假死。
  命令本身没问题，需在放宽权限（danger-full-access）下运行，或由用户手动执行。
- 绕开 flutter 工具启动开销的等效校验命令：
  ```bash
  dart analyze .          # 等价于 flutter analyze 的静态检查
  flutter test            # widget 测试
  ```
