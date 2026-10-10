# UI 事项 5：搜索界面

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 5 项「构建搜索界面」，
需求原文见「Search」：**首页的上方的搜索栏将用户引导至搜索子界面。
搜索允许用户通过物品名称等关键词进行搜索，搜索结果也可以通过筛选器筛选。**

## 本轮目标

- 把首页搜索栏的落点从 `ComingSoon` 占位换成真能搜的界面：输关键词、看结果、进详情。
- 关键词要能沾到**物品名称、地点、描述、分类名**——用户记得住什么就搜什么，不该只认标题。
- 搜索结果上也要能再筛（类型 / 分类 / 排序），也就是需求里那半句「搜索结果也可以通过筛选器筛选」。
- **首页与搜索界面共用一套筛选与排序**：不复制第二份口径，两处日后不会走偏。
- 明确本轮**不做**的事：不建数据库、不做图片、不做搜索历史、不做分词 / 模糊匹配 / 高亮。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 搜索界面 `SearchPage` | `AppBar` 里是**真输入框**（返回按钮 + 输入框 + 清空按钮）；正文四态：引导 / 结果 / 「关键词没沾边」空态 / 「被筛选筛空」空态 |
| 查询对象 `PostQuery` | `lib/models/post_query.dart`：`PostSortBy` + `PostQuery(keyword, type, category, sortBy).apply(posts)`，一次查询的判定与排序都在这儿 |
| 筛选条 `PostFilterBar` | `lib/widgets/post_filter_bar.dart`：类型 chip 条 + 筛选菜单（分类 / 排序），**从首页原样搬出来**，Key 前缀可变 |
| 关键词匹配 `ItemPost.matchesKeyword` | 改成按空白拆词、**多词都要沾边（AND）**，单词时逐个字段找 |
| 首页改造 | 删掉本地的枚举与筛选控件，改用 `PostQuery` + `PostFilterBar(keyPrefix: 'home-filter')`；搜索入口把 `onGoHome` 继续传下去 |
| 入口联动 | `HomePage._openSearch()` → `SearchPage(onGoHome:)`；搜索结果点卡片 → `PostDetailPage(postId:, onGoHome:)` |

## 文件清单

```
lib/
  pages/search_page.dart          搜索界面（占位改为实现，本轮主体）
  models/post_query.dart          新增：PostSortBy + PostQuery（首页与搜索共用）
  widgets/post_filter_bar.dart    新增：PostFilterBar（从首页搬出来的筛选区）
  models/item_post.dart           matchesKeyword() 支持多关键词 AND
  pages/home_page.dart            改用共享的 PostQuery / PostFilterBar，透传 onGoHome
test/
  search_page_test.dart           搜索界面 13 个 widget 测试（新增）
  widget_test.dart                第 6 条断言从「建设中」改为断言搜索框与引导态（原占位文案已删）
```

## 界面结构

`AppBar`：

- `leading`：显式 `IconButton`（Key `search-back-button`，tooltip「返回」）——
  项目还没接 `flutter_localizations`，系统 `BackButton` 的 tooltip 是英文，测试按文案找不到（同 ui-04）。
- `title`：`TextField`（Key `search-field`，`autofocus: true`，`TextInputAction.search`，边框去掉嵌在 AppBar 里），
  hint 是「搜索物品名称、地点或描述」——比首页那条「搜索物品名称、地点」多一项，因为描述也算。
- `actions`：**只在有内容时**给清空按钮（Key `search-clear`）。

正文是一列：**有关键词时**先摆筛选条（`search-filter-*`），再是下面四种状态之一：

1. **引导态**（还没输入，Key `search-intro`）：搜索图标 + 「搜索校园里的失物与招领」+
   「物品名称、地点、描述里的词都能搜」+ 几个能点的示例词。
2. **结果态**：顶部一行「找到 N 条相关信息」（Key `search-result-count`），下面是 `ListView.separated`
   （Key `search-results`）渲染 `PostCard`，点卡片进详情。
3. **关键词没沾边**（Key `search-empty-keyword`）：「没有找到与「xx」相关的信息」+ 提示换个说法 + 同样的示例词。
4. **被筛选筛空**（Key `search-empty-filter`）：关键词本身是找得到的，说明「只是被类型或分类筛掉了」，
   并给一个「清除筛选」按钮（Key `search-clear-filters`）。

示例词是 `ActionChip`（Key `search-suggestion-<词>`），点一下把词**填进输入框**再搜，
用户看得见自己搜了什么，也就知道怎么改。

## Key 约定

| Key | 位置 |
| --- | --- |
| `search-back-button` / `search-field` / `search-clear` | AppBar |
| `search-intro` | 引导态整块 |
| `search-result-count` / `search-results` | 结果条数与结果列表 |
| `search-empty-keyword` / `search-empty-filter` | 两种空态 |
| `search-clear-filters` | 筛空空态里的「清除筛选」 |
| `search-suggestion-<关键词>` | 示例词 chip |
| `search-filter-menu` / `search-filter-category-<name\|all>` / `search-filter-sort-<name>` | 筛选条（由 `PostFilterBar(keyPrefix: 'search-filter')` 生成） |
| `home-filter-*` | 首页筛选条，前缀沿用（`keyPrefix: 'home-filter'`），首页原有测试不受影响 |

## 设计要点

- **输入即搜，不做「搜索」按钮**：数据在本地内存里，每敲一个字重新查一遍的成本可以忽略；
  手机上按一次「搜索」键才出结果是多余的一步。键盘上的「搜索」键只用来收键盘（`unfocus`）。
- **判定与排序抽成 `PostQuery`，而不是让搜索界面自己写一遍**：首页那套筛选 + 排序原本长在
  `_HomePageState` 里，搜索界面再抄一份必然走偏（同一个信息在两边筛出不同结果，是最难查的一类 bug）。
  现在 `PostQuery.apply()` 是唯一口径，字段判定仍留在 `ItemPost`（`matchesKeyword` / `matchesFilter`），
  `PostQuery` 只负责「过滤 + 排序」。将来换 SQLite 时，这里对应一条 `WHERE ... ORDER BY ...`（有 `TODO(storage)`）。
- **筛选条也搬成组件、Key 按前缀生成**：`PostFilterBar` 的 `keyPrefix` 默认 `'post-filter'`，
  首页传 `'home-filter'`（于是首页既有测试的 Key 一字未改），搜索界面传 `'search-filter'`。
  一个 `Key` 在测试树里只能有一个，两处同时在栈上时也必须能分清是谁的。
- **筛选条只在有关键词时出现**：没输入时没有结果可筛，摆出来只是噪音；
  引导态要说的是「你能搜什么」，不是「你能筛什么」。
- **两种「没结果」必须分开**：关键词压根没沾到边，用户的下一步是**换个词**；
  关键词有货、只是被筛选筛掉，下一步是**放宽筛选**。混成一句「没有找到」的话，
  用户会以为数据不存在，其实只要点一下「清除筛选」就出来了——所以两者文案与按钮都不一样。
- **多关键词按 AND 处理**：`matchesKeyword` 把输入按空白拆词，每个词都要在
  title / location / description / category.label 里沾到边。多打一个词应当是**收窄**结果，
  这是用户的直觉；OR 会让多打词反而变多，看起来像坏了。
- **关键词清空时顺手把筛选复位**：筛选条本身跟着关键词一起隐藏，留着上一轮的筛选就成了
  「看不见的条件」——用户看到空列表却找不到是哪儿在筛。所以在关键词变空的那一刻把类型 / 分类清掉。
  注意「清除筛选」按钮走的是另一个方法（无条件清筛选，关键词留着），
  这两个动作不能共用一个实现（**本轮就在这里踩了一下**：一开始 `_clearFilters()` 直接复用了
  「关键词空了才清」的那份逻辑，于是关键词非空时点「清除筛选」什么都不发生，被测试 10 抓了出来）。
- **显示「找到 N 条相关信息」——与首页的取舍相反**：首页刻意不显示条数（列表本身就是答案，
  页面还长），但搜索界面必须给反馈：用户在调关键词，条数从 9 → 3 → 0 的过程正是他在找的那个信号，
  同时也是「关键词太宽 / 太窄」的提示。
- **结果是活视图**：`SearchPage` 不存结果快照，每次 `build` 从 `PostScope.of(context).posts` 现查
  （与详情页同一套规矩）。别人刚发布的信息，正在搜的人不用退出重进就能搜到。
- **「回到首页」的传递链**：`MainShell → HomePage → SearchPage → PostDetailPage`。
  详情页里信息被删除时的空态按钮需要一条出路，而搜索界面自己 pop 不掉栈上的首页——
  所以 `SearchPage._backToHome()` 先 `popUntil((r) => r.isFirst)` 退回外壳，再调 `widget.onGoHome`；
  单独渲染 `SearchPage`（测试里）时它不是 `null` 判断的漏网之鱼：`onGoHome` 为 `null` 时不传给详情页，按钮也就不显示。

## 尚未实现 / 留给后续事项

- **搜索历史**（当时没做：没有持久化层，存了也留不住）——已由
  [storage-04-search-history.md](./storage-04-search-history.md) 补上：本地库版本 2 → 3 加了
  `search_history` 表，引导态摆出「最近搜索」，可点可删可清空。
  该文档里写清了**记录时机**（只有键盘搜索键 / 点词 chip 才算一次，`onChanged` 不记）。
- **不做分词 / 拼音 / 错别字容错 / 结果高亮**：`matchesKeyword` 是朴素的子串包含。
  中文没空格，用户输入「图书馆雨伞」这种连写不会命中两条不同字段的信息——这是已知边界。
- 应用设置界面（事项 7）**已完成**（[ui-07-settings-page.md](./ui-07-settings-page.md)）；
  编辑界面（事项 6）已可用，文档在 [ui-06-post-edit-page.md](./ui-06-post-edit-page.md)。
- 图片（选填）仍未实现；数据只在内存里，重启即丢（`TODO(storage)`、`TODO(image)`）。
- 系统级控件（日期 / 时间选择器）仍是英文，同 ui-04 的说明。

## 验证

```bash
flutter analyze
flutter test
```

**最近一次验证结果（本轮）**：

- `flutter analyze` → `No issues found! (ran in 0.9s)`
- `flutter test` → `00:04 +50: All tests passed!`（首页 6 + 发布 6 + 我的 13 + 详情 12 + 搜索 13 共 50 个）

注意：这两个命令在受限沙箱下会因无法启动分析器 / 测试子进程而失败
（`CreateFile failed 5 ... 拒绝访问。(process_win.cc:744)`），
需在放宽权限（danger-full-access）下运行或由用户手动执行，详见 basic-info.md 的环境备忘。

新增的 `test/search_page_test.dart` 覆盖：

1. 首页搜索栏进入搜索界面：输入框就位，给的是引导而不是「建设中」（筛选条此时不出现）；
2. 输入「雨伞」后只剩匹配的信息，并给出条数；
3. 关键词不只看物品名称：地点（图书馆）、描述（胶带）、分类名（证件）都能命中；
4. 多个关键词是「都要沾边」：`图书馆 雨伞` 有 1 条、词序无关、`图书馆 保温杯` 为 0 条；
5. 英文关键词不分大小写（`iphone` / `IPHONE`）；
6. 没有匹配时给出空态与可点的示例词，点一下就出结果；
7. 引导页的示例词点了会填进输入框（用户看得见搜的是什么）；
8. 点清空按钮回到引导态，输入框清空、筛选条一起消失；
9. 结果也能换排序（「电子产品」两条按最新 / 最早切换）；
10. 筛选把结果筛空时给的是「清除筛选」而不是「没找到」，点了能恢复；
11. 清空关键词会把筛选一起复位，不留看不见的条件；
12. 点结果进详情、返回后关键词与结果都还在；
13. 结果是活视图：仓库里新发布的信息，正在搜的人也能搜到。

上一轮的 `test/widget_test.dart`（6 个首页测试）、`test/publish_page_test.dart`（6 个）、
`test/profile_page_test.dart`（13 个）、`test/post_detail_page_test.dart`（12 个）在首页改造后**全部保持通过**；
`widget_test.dart` 只改了第 6 条（搜索入口）的断言——原来断言的是占位文案「搜索界面建设中」，
占位已被真界面取代，改为断言 `search-field` 与 `search-intro`。

### 本轮踩到的测试坑

- **详情页的联系方式卡要放大视口才建得出来**：搜索界面里点进详情的用例一开始用默认 800×600，
  `detail-content` 找得到、`detail-contact` 找不到——详情页是 `ListView`，下半截根本没进 widget 树。
  加 `setSurfaceSize(Size(800, 1600))` + `addTearDown` 复原即可（ui-04 已记过同一个坑）。
- **造测试数据时关键词要真的在字段里**：用 `buildPost` 造了一条标题「黑色折叠伞」的信息去搜「雨伞」，
  结果是 0 条——「折叠伞」里没有「雨伞」两个字。造数据的人自己知道想指什么，字段不会替他补上。
- **默认排序是最新发布**：断言结果顺序前先想一下 `createdAt` 谁在前（`证件` 命中一卡通 2 小时前、
  学生证 4 天前，顺序是一卡通在前）。测试里已经写在注释里。
