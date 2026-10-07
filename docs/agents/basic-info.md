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

## Env

Flutter 3.47.5 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 6a19cca564 (3 weeks ago) • 2026-09-17 14:13:22 -0400
Engine • hash ab598368592da0064197e2bc15c7f5b0a2c6bb1f (revision af7e796e16) (19 days ago) • 2026-09-16 18:35:09.000Z
Tools • Dart 3.13.4 • DevTools 2.60.0

## UI

三大主界面：首页、发布、我的

次级界面：搜索界面（首页）、编辑界面（我的）、应用设置界面（我的）、详细信息界面

## Storage Notice

用户所有数据保存在本地 SQLite 数据库。功能在本地闭环，暂不实现与远程服务端的连接。

## Design

界面使用 Google Material Design 3 设计系统。

## Priority

请按照此列表分事项实现。

### UI 构建

1. 构建首页 ✅
2. 构建发布界面 ✅
3. 构建我的界面 ✅
4. 构建详细信息界面 ✅
5. 构建搜索界面 ✅
6. 构建编辑界面 ✅
7. 构建应用设置界面（外观、账户、应用信息）✅
8. 控件文字本地化
9. MD3 主题动态取色
10. 取代 Flutter 默认图标，添加启动页

### 本地后端建设

1. 数据迁移至本地 Sqlite，保留示例数据 ✅
2. 支持照片存储 ✅
3. 多用户隔离
4. 搜索记录

## Progress

当前阶段：**UI 事项 1–7 全部完成，本地后端建设两项也已完成**。
后续工作见下方「尚未开始的技术工作」；本地库当前版本是 **2**（v2 加了 `app_settings` 设置表，
主题模式存这里，见 [ui-07-settings-page.md](./ui-07-settings-page.md)）。

| 事项 | 状态 | 文档 |
| --- | --- | --- |
| 1. 首页 | 已完成并验证 | [ui-01-home-page.md](./ui-01-home-page.md) |
| 2. 发布界面 | 已完成并验证 | [ui-02-publish-page.md](./ui-02-publish-page.md) |
| 3. 我的界面 | 已完成并验证 | [ui-03-profile-page.md](./ui-03-profile-page.md) |
| 4. 详细信息界面 | 已完成并验证 | [ui-04-post-detail-page.md](./ui-04-post-detail-page.md) |
| 5. 搜索界面 | 已完成并验证 | [ui-05-search-page.md](./ui-05-search-page.md) |
| 6. 编辑界面 | 已完成并验证（UI 事项 3 顺带做出骨架，事项 6 补齐打磨） | [ui-06-post-edit-page.md](./ui-06-post-edit-page.md) |
| 7. 应用设置界面 | 已完成并验证（外观 / 账户 / 应用信息；入口在「我的」右上角齿轮） | [ui-07-settings-page.md](./ui-07-settings-page.md) |

本地后端建设：

| 事项 | 状态 | 文档 |
| --- | --- | --- |
| 1. 数据迁移至本地 SQLite（保留示例数据） | 已完成并验证 | [storage-01-sqlite.md](./storage-01-sqlite.md) |
| 2. 支持照片存储（选图 / 落盘 / 展示 / 清理） | 已完成并验证（真机相册未手动验证） | [storage-02-photos.md](./storage-02-photos.md) |

工程化 / 自动化：

| 事项 | 状态 | 文档 |
| --- | --- | --- |
| GitHub Actions：Build / Test / Release 三条工作流 | 已编写；Android 构建链路本地验证通过，**三个工作流均尚未在 GitHub 上真跑过** | [ci-automation.md](./ci-automation.md) |
| Android 正式签名（`android/key.properties` 存在才启用，CI 用 Secrets 注入） | 已实现（签名分支本地验证通过；正式 keystore 由用户自备） | [ci-automation.md](./ci-automation.md) |

已完成的问题修复（非新增事项）：

| 问题 | 状态 | 文档 |
| --- | --- | --- |
| 「我的发布」状态显示与状态回退 | 已修复并验证 | [fix-my-post-status.md](./fix-my-post-status.md) |
| 发布界面「清空」清不掉已选的信息类型 / 物品分类 / 时间 | 已修复并验证 | [fix-post-form-reset.md](./fix-post-form-reset.md) |
| Android 构建失败（Kotlin 跨盘符 + sqlite3 下载超时） | 已修复并验证 | [fix-android-build.md](./fix-android-build.md) |
| 详情页图片点击放大 | 已修复并验证 | [fix-detail-photo-zoom.md](./fix-detail-photo-zoom.md) |
| 代码中三处 `TODO` 的排查与注释 / 文档订正（不改逻辑） | 已完成 | [todo-triage.md](./todo-triage.md) |

已铺好的公共基础（后继事项可直接复用，不必重建）：

- `lib/theme/app_theme.dart`：全局 Material 3 主题（`ColorScheme.fromSeed`，种子色 `0xFF00695C`，明 / 暗两套）。
- `lib/models/item_post.dart`：`ItemPost` 及 `PostType` / `PostStatus` / `ItemCategory` 枚举，字段与上文「每个信息应当包含以下内容」一致。
- `lib/pages/main_shell.dart`：三大主界面外壳（底部 `NavigationBar` + `IndexedStack`）。
- `lib/data/post_store.dart`：**信息仓库**（`PostStore` + `PostScope`）。界面继续**同步**读它的内存快照，
  所以首页 / 搜索的筛选排序仍是即时的（点一下就出结果，不等查询）；有仓储时每次改动顺手写进本地 SQLite，
  启动时用 `load()` 读回。发布界面写入、首页读取，`updatePost()` / `removePost()` / `postById()` 齐备
  （**详情页只收 id，不认快照**，信息被改 / 被删它都能跟着变）。
- `lib/data/user_store.dart`：**账户仓库**（`UserStore` / `UserScope`），
  「我的」界面登记本机账户（称呼 + 联系方式），发布界面据此带出默认联系方式；同样支持写穿仓储。
  账户模型 `UserAccount` 已搬到 `lib/models/user_account.dart`。
- `lib/widgets/post_form.dart`：**发布与编辑共用的整张表单**（`PostForm` + `PostFormState`）。
  新表单界面不必再抄一遍字段与校验：套一层 `AppBar`，用 `PostForm.createKey()` 拿 key 调
  `save()` / `reset()` 即可。表单内部 Key 沿用 `publish-` 前缀。
  UI 事项 6 又给它加了 `isDirty`（「和打开时不一样」的判定，联系方式自动带出的不算）与
  `onChanged` 回调（选择器 / 文本框 / `reset()` 都会触发），供宿主做「有没有未保存的改动」这类界面状态。
- `lib/models/item_post.dart` 的 `isMine` 字段标出「本机用户发布的」，
  `copyWith()` 供「标记状态」「修改发布」构造新对象。
- `lib/widgets/post_card.dart`、`lib/widgets/coming_soon.dart`：信息卡片与「未开工界面」占位组件。
- `lib/widgets/my_post_card.dart` 在首页卡片基础上加了管理操作（标记 / 修改 / 删除）。
  标记完成后展示「对勾 + 已找到/已归还」的状态块，并给「改回进行中」留了回退入口
  （见 [fix-my-post-status.md](./fix-my-post-status.md)）。
- `lib/pages/post_detail_page.dart`：**详细信息界面**（UI 事项 4）。首页与「我的发布」的卡片都指向它；
  它只读不写——标记 / 修改 / 删除仍留在「我的」，同一条信息不留两套管理入口。
- `lib/models/post_query.dart`：**一次查询**（`PostSortBy` + `PostQuery(keyword, type, category, sortBy)`）。
  首页与搜索界面共用同一套筛选 + 排序口径（字段判定仍在 `ItemPost.matchesKeyword()`）。
  **同一口径现在有两份实现**：内存版 `PostQuery.apply()`（列表页即时筛选用）与 SQL 版
  `SqliteItemRepository.queryPosts()`，两者由 `test/sqlite_storage_test.dart` 的对拍用例兜住——改判定时两处都要改。
- `lib/widgets/post_filter_bar.dart`：**筛选条组件**（类型 chip 条 + 分类 / 排序菜单），由首页原样搬出。
  `keyPrefix` 默认 `'post-filter'`，首页传 `'home-filter'`、搜索界面传 `'search-filter'`——
  两处同时在栈上时 Key 不能撞车。
- `lib/pages/search_page.dart`：**搜索界面**（UI 事项 5）。首页搜索栏的落点，输入即搜；
  结果每次都从 `PostStore` 现查（活视图），并可再用筛选条筛。
- `lib/pages/post_edit_page.dart`：**编辑界面**（UI 事项 6）。链路在 UI 事项 3 已通，
  事项 6 补的是「改到一半」的兜底：AppBar 的「还原」（与发布界面「清空」共用同一个
  `PostFormState.reset()`，新建=清空、编辑=还原）、有未保存改动时返回 / 系统返回先确认
  （`PopScope<ItemPost>(canPop: !_dirty)`）。见 [ui-06-post-edit-page.md](./ui-06-post-edit-page.md)。
- `lib/data/settings_store.dart`：**设置仓库**（`SettingsStore` / `SettingsScope`，键名常量在
  `SettingNames`），目前只有一项「主题模式」。用法与 `PostStore` / `UserStore` 一样：
  读内存快照，改完立刻 `notifyListeners()` 再写穿仓储；`load()` 必须在 `runApp()` 之前 `await` 完。
  主题用的是 Flutter 自带的 `ThemeMode`（跟随系统 / 浅色 / 深色），没有自建枚举。
- `lib/pages/settings_page.dart`：**应用设置界面**（UI 事项 7）。`MaterialApp.themeMode` 由
  `lib/main.dart` 里的 `ListenableBuilder(listenable: _settingsStore, ...)` 驱动，
  所以 `setThemeMode()` 一处生效、全应用立刻换肤。
- `lib/widgets/account_form.dart`：**账户表单**（称呼 + 常用联系方式），「我的」界面的登记表单与
  设置界面的登记 / 修改资料表单共用它。用 `keyPrefix` 拼 Key（`ProfilePage` 传 `'profile'`、
  设置页传 `'settings-account'`），**它不碰 `UserStore`**——写库、收表单、弹提示都由调用方负责。
  注意它把「我的」界面上两个按钮的 Key 从 `profile-register-submit` / `profile-register-cancel`
  改成了 `profile-submit` / `profile-cancel`。
- `lib/app_info.dart`：应用名称与版本常量（`AppInfo.name` / `versionLabel`），
  与 `pubspec.yaml` **手工同步**——项目没引 `package_info_plus`，改版本号时两处都要改。
- `lib/data/settings_repository.dart` + `DbSchema` 的 `app_settings` 表（库版本 **1 → 2**）：
  设置以「一行一项」的键值对落库；`app_database.dart` 的 `_upgrade` 里有对应的 v1→v2 迁移
  （只补表，不动老数据）。以后加设置项不必再升版本。
- `lib/utils/time_format.dart`：时间格式化工具。
- `lib/data/mock_posts.dart`：**示例数据**（9 条），两处用途：首建本地库时写进 `posts` 表，以及纯内存模式下作为
  `PostStore` 的初始内容。示例数据只在首建库时写一次，用户删掉后不会回来。详见 [storage-01-sqlite.md](./storage-01-sqlite.md)。
- `lib/data/db_schema.dart`、`lib/data/post_row.dart`、`lib/data/app_database.dart`：**本地库的地基**——
  表名 / 列名 / DDL 常量、`ItemPost` ↔ 数据库行的映射（含检索列 `search_text`）、开库与首建写示例数据。
- `lib/data/item_repository.dart`、`lib/data/user_repository.dart`：**仓储接口 + SQLite 实现**，
  将来换存储（或加一层远端）只需换实现，`PostStore` / `UserStore` 与界面都不动。
- `lib/data/image_file_store.dart`、`lib/data/photo_store.dart`：**图片文件与图片仓库**
  （本地后端事项 2）。`ImageFileStore` / `FileImageFileStore` 管盘上的文件（落盘、起名、
  删文件、文件名 ↔ 绝对路径换算），`PhotoStore` 管会话、迁移与孤儿清理。
  **库里 `posts.image_paths` 只存文件名**（iOS 每次安装目录都会变，绝对路径会失效）。
- `lib/services/photo_picker.dart`：**相册 / 相机的抽象**（`PhotoPicker` + `PhotoPickerScope`）。
  `image_picker` 这个依赖只在这里出现，界面拿到的是一组绝对路径；测试整套替换掉即可。
- `lib/widgets/post_photo.dart`：`PostPhotoView`（缩略图 / 轮播页，读不到图时降级成分类图标）、
  `imageFilenamesOf()`、`resolvePhotoPath()`。新界面要显示信息的图片就用它。
- `PostForm` 的图片字段已经可用：选图 / 删图 / 9 张上限 / `isDirty` 都接进了 `PostFormState`，
  宿主不必自己处理图片。图片的落盘与会话清理由 `FormImageSession` 兜住。

尚未开始的技术工作：`flutter_localizations` 中文化（UI 事项 7 想顺手做，但那一轮范围不含它，
系统级控件与系统返回键的 tooltip 仍是英文，详见 [ui-07-settings-page.md](./ui-07-settings-page.md)）。

## 环境备忘（后继 Agent 必读）

- Flutter 3.47.5 / Dart 3.13.4，SDK 位于 `D:\flutter\flutter`，Dart 可执行文件在
  `D:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe`。
- **`flutter analyze` 与 `flutter test` 在受限沙箱下必定失败**（不是慢）：分析器需要启动
  `analysis_server_aot.dart.snapshot` / `flutter_tester` 子进程，沙箱下报
  `CreateFile failed 5 ... ProcessException: 拒绝访问。(process_win.cc:744)`，表现为长时间无输出的假死。
  命令本身没问题，需在放宽权限（danger-full-access）下运行，或由用户手动执行。
  **`dart analyze .` 同样会失败**（一样要拉 `analysis_server_aot.dart.snapshot` 子进程），
  所以静态检查与测试应当**在一次放宽权限的命令里一起跑完**，不要反复试、白等审批。
- 项目在 `D:` 盘；若会话工作区在别处且沙箱只允许写工作区，可先在可写目录准备好文件，
  再用一次放宽权限的命令 `Copy-Item` 进项目并顺带跑校验，以减少审批次数。
- 用 **`flutter test`**，不要用 `dart test`：后者读不到 test 包，报
  `Could not find package 'test' or file 'test:test'`。
- 测试里涉及剪贴板（`Clipboard.setData`）时，必须先接管 `SystemChannels.platform`，
  否则那个 Future 永远不完成、按钮像点了没反应；单独渲染 `ProfilePage` 时还要连 `UserScope` 一起包。
  详见 [ui-04-post-detail-page.md](./ui-04-post-detail-page.md) 结尾的两个坑。
- 测试里要碰本地库（`AppDatabase` / 仓储）时，**必须注入 ffi**：`sqfliteFfiInit()`（`setUpAll` 里一次）
  + `AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath, seededAt: ...)`。
  测试宿主上没有平台通道，默认的 `databaseFactory` 用不了。照抄 `test/sqlite_storage_test.dart` 的开头即可。
- `sqlite3` 3.5.2 靠 Dart hooks 拉原生库：首次从 GitHub release 下载并缓存到 `.dart_tool/hooks_runner/`
  （已 gitignore）。**本机网络访问 GitHub 不稳定（下载超时）**，已在 `pubspec.yaml` 里改用各平台系统自带的
  SQLite 库（`hooks: user_defines: sqlite3: {source: system, ...}`），构建与测试都不再依赖联网下载。
  详细配置见 `pubspec.yaml` 与 [fix-android-build.md](./fix-android-build.md)。
- **别顺手 `dart format lib test`**：本机 Dart 3.13 的 formatter 是新排版风格，与仓库既有代码风格不同，
  一次全量格式化会顺带重排十几个无关文件（本地后端事项 1 干过一次，已用 `git checkout --` 撤销）。
  要统一格式就单独开一轮、单独提交；平时只格式化自己新增 / 改写的文件。
- **`testWidgets` 里不要做真实文件 I/O**：它的虚拟时间不驱动 `dart:io` 的回调，
  `await Directory.systemTemp.createTemp(...)` / `File.copy(...)` 会**永远挂着**（不是慢）。
  真实文件读写用普通 `test()`；要驱动 widget 就 `tester.runAsync()`，或者把文件层换成内存实现
  （见 [storage-02-photos.md](./storage-02-photos.md) 的坑 1）。
- **测试里页面比 800×600 高时要放大视口**：`ListView` 是懒加载的，屏幕外的那截不会进 widget 树，
  按 Key 找「下面的那个卡片 / 那一行」会直接失败（不是代码错）。
  用 `tester.view.physicalSize = Size(1000, 2000)`（配 `devicePixelRatio = 1`）+
  `addTearDown(tester.view.reset)`。ui-03 的「我的发布」长列表与 ui-07 的设置页都踩过。
- **`// ignore: <lint>` 只作用到紧随的一行**：初始化列表里有两行需要忽略时，两行前面各写一条
  （`flutter analyze` 会把第二行照旧报出来）。
- **`flutter test` 被强杀不会带走它派生的 `flutter_tester` / `dart` 子进程**，
  残留进程会占住 `.dart_tool/hooks_runner/shared/sqlite3/.lock` 等文件句柄。
  处置：`Get-Process dart,flutter_tester,java,gradle,KotlinCompileDaemon` 找残留 → `Stop-Process -Force` →
  删 `.dart_tool/hooks_runner/shared/sqlite3/.lock` → 重新构建。
  本机 `android\gradlew.bat --stop` 不可用（`JAVA_HOME` 指向不存在的 JDK 目录），构建用的是
  Android Studio 自带 JBR（`C:\Program Files\Android\Android Studio\jbr`）。
- **Android 构建原本失败的两个根因（已修复，见 [fix-android-build.md](./fix-android-build.md)）**：
  1. Kotlin 增量编译跨盘符 bug——源文件在 `C:` 盘（Pub Cache）、项目在 `D:` 盘，
     `RelocatableFileToPathConverter.toPath` 算相对路径时抛 `IllegalArgumentException: different roots`，
     导致 `caches-jvm` 关不掉。已在 `android/gradle.properties` 加 `kotlin.incremental=false`。
  2. sqlite3 原生库下载超时——hooks runner 直连 GitHub 超时，`gradle.properties` 的代理只对 Gradle 生效。
     已在 `pubspec.yaml` 配 `source: system` 改用系统自带 SQLite。
