# UI 事项 1：首页

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 1 项「构建首页」。

## 本轮目标

- 完成首页本体：集中浏览校园失物 / 招领信息，并能用筛选器与搜索入口缩小范围。
- 顺带搭好承载「三大主界面」的外壳（底部导航），否则首页无处安放。
- 明确本轮**不做**的事：不建数据库、不写仓储层、不实现其他次级界面。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 应用外壳 `MainShell` | 底部 `NavigationBar`，三个主界面：首页 / 发布 / 我的；`IndexedStack` 保留各页的滚动位置与输入状态 |
| 首页 `HomePage` | 搜索栏、类型筛选、分类筛选、排序菜单、结果计数、信息卡片列表、空结果提示 |
| 主题 `AppTheme` | Material 3，`ColorScheme.fromSeed(0xFF00695C)`，明 / 暗两套 |
| 数据模型 `ItemPost` | 字段与《Basic Info》「每个信息应当包含以下内容」一一对应 |
| 示例数据 `buildMockPosts()` | 9 条覆盖不同分类 / 类型 / 状态的样例，时间基于当前时刻生成 |
| 占位界面 | `SearchPage`、`PublishPage`、`ProfilePage`，统一用 `ComingSoon` 撑起导航结构 |

## 文件清单

```
lib/
  main.dart                  应用根组件 LostAndFoundApp（主题 + MainShell）
  theme/app_theme.dart       AppTheme：Material 3 明 / 暗主题
  models/item_post.dart      ItemPost、PostType、PostStatus、ItemCategory
  data/mock_posts.dart       buildMockPosts()：UI 阶段的示例数据
  utils/time_format.dart     formatDate / formatDateTime / formatRelativeTime / formatEventTime
  widgets/post_card.dart     首页列表的信息卡片
  widgets/coming_soon.dart   未开工界面的占位内容
  pages/main_shell.dart      三大主界面外壳（底部导航）
  pages/home_page.dart       首页
  pages/search_page.dart     搜索界面（占位，UI 事项 5）
  pages/publish_page.dart    发布界面（占位，UI 事项 2）
  pages/profile_page.dart    我的界面（占位，UI 事项 3）
test/
  widget_test.dart           首页渲染、筛选行为、搜索跳转的 widget 测试
```

## 设计要点

- **信息模型先行**：`ItemPost` 按《Basic Info》的字段表定义（物品名称、分类、地点、时间、描述、联系方式、图片），
  状态用 `PostStatus.pending / resolved` 表示，配合 `PostType` 派生出「寻找中 / 待认领 / 已找到 / 已归还」四种文案。
  接入 SQLite 时模型不用改，只把 `buildMockPosts()` 换成仓储查询。
- **筛选就是纯函数**：`ItemPost.matchesFilter({type, category})`，`null` 表示该维度不筛选；
  页面只负责维护两个可空状态并重新求值，后续搜索界面可以复用同一套判定。
- **搜索栏是入口而非输入框**：首页顶部的搜索栏只做跳转（`Key('home-search-entry')`），
  符合「首页的上方的搜索栏将用户引导至搜索子界面」的要求，真正的输入与结果留在搜索界面。
- **排序**：右上角菜单提供「最新发布 / 最早发布」，按 `createdAt` 排序。
- **卡片信息层级**：缩略图 → 类型标签（+ 已解决时的状态标签）与相对时间 → 物品名称 → 描述摘要 → 地点 / 时间；
  已解决的信息标题与图标降饱和，便于与进行中的信息区分。
- **缩略图暂用分类图标占位**：仓库里还没有图片资源，也不该在本轮引入假资源，代码中留有 `TODO(image)`。

## 尚未实现 / 留给后续事项

- 卡片点击暂未接详细信息界面（UI 事项 4），`PostCard.onTap` 已预留参数。
- 搜索界面、发布界面、我的界面目前是 `ComingSoon` 占位。
- 未接入 SQLite，首页数据来自 `buildMockPosts()`；下拉刷新等真实数据交互一并留到存储接入时再加。
- 未引入 `flutter_localizations`，系统级控件（文本选择菜单等）仍是英文；
  若要中文化，应在「应用设置界面」（UI 事项 7）一并处理。
- 图片缩略图未实现。

## 验证

```bash
flutter pub get
flutter analyze
flutter test
```

若上述命令执行时间过长，请停止继续执行并要求用户手动验证。

`test/widget_test.dart` 覆盖：

1. 首页渲染标题、搜索栏、分类筛选器与信息卡片；
2. 选择「失物」后招领信息消失、失物信息保留；
3. 按「电子产品」分类筛选后只保留该分类的信息；
4. 点击首页搜索栏跳转到搜索界面。
