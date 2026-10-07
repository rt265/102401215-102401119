# 开发者文档

**速拾失** —— 一款基于 Flutter 的单机移动应用，覆盖校园失物与招领信息的发布、浏览、搜索、详情查看与状态管理全流程。

目前仅开发了客户端服务，数据和功能完全位于本地。

---

## 1. 快速开始

### 1.1 工具链

| 工具 | 版本 | 说明 |
| --- | --- | --- |
| Flutter | 3.47.5 (stable) | 跨平台 UI 框架 |
| Android SDK | 36.0.0 | Android 开发套件 |
| JDK | 21/25 | Java 开发套件 |
| Dart | 3.13.4 | 与 Flutter 捆绑，无需单独安装 |
| Flutter Lints | ^6.0.0 | 静态分析规则集 |
| sqflite_common_ffi | ^2.4.3 | 仅 dev，测试用 |

查看面向使用中文的开发者的 Flutter 文档：[安装 Flutter](https://docs.flutter.cn/install/)

对于中国大陆地区的开发者，建议同时查看 [在中国网络环境下使用 Flutter](https://docs.flutter.cn/community/china/)

检查环境：

```bash
flutter doctor -v
```

### 1.2 克隆与依赖安装

```bash
git clone <repo-url>
cd lost-and-found
flutter pub get
```

> **注意**：项目使用各平台**系统自带的 SQLite 库**（Android 的 `libsqlite3.so`、Windows 的 `winsqlite3.dll`、iOS/macOS 的 `libsqlite3.dylib`），`pubspec.yaml` 中的 `hooks.user_defines.sqlite3` 已配置为 `source: system`，不从 GitHub 下载预编译二进制，避免了网络不稳定导致的构建超时。

### 1.3 运行开发版

```bash
# 开发调试（连接模拟器或真机）
flutter run

# 明确指定设备
flutter run -d <device-id>

# 构建 Debug 版本的 APK
flutter build apk --debug
```

### 1.4 构建发布版本

本项目目前只支持为 Android 和 iOS 平台构建。

```bash
flutter build <platform>
```

你可以通过 `flutter help build` 查看你的设备所支持构建的 `platform`。你只需要关注：

|平台名称|说明|
| ------ | -- |
| `apk`  | 经典 Android APK 构建，**推荐大多数情况**下使用 |
| `appbundle` | 面向支持平台（如 Google Play）的发布文件 |
| `ipa` | 面向 iOS 的构建 |

> [!NOTE]
>
> Android 平台构建需要 Android SDK、JDK，建议添加用于 release signing 的 keystore。
>
> 为 Android 平台构建时，建议添加 `--split-per-abi` 选项，以减少单个包的体积。
>
> iOS 平台构建需要 macOS 构建机和 Xcode。进行签名时还需要 Apple Developer 账号。
>
> 我们主要为 Android 平台进行测试和构建。iOS 仅限于最低限度的支持。

---

## 2. 项目结构

```
lost-and-found/
├── lib/                        # 应用源码
│   ├── main.dart               # 应用入口：初始化数据库与仓库，挂载根组件
│   ├── app_info.dart           # 应用固定信息（名称、版本号）
│   ├── models/                 # 数据模型（不可变值对象）
│   │   ├── item_post.dart      # 一条失物/招领信息
│   │   ├── post_query.dart     # 浏览/搜索查询条件
│   │   └── user_account.dart   # 本机账户
│   ├── data/                   # 数据层：仓储、Store、本地 SQLite
│   │   ├── app_database.dart    # 开库、建表、首次建库写示例数据
│   │   ├── db_schema.dart       # 表结构定义（表名、列名、建表语句）
│   │   ├── post_row.dart        # posts 表行 ↔ ItemPost 编解码
│   │   ├── item_repository.dart # 信息仓储接口 + SQLite 实现
│   │   ├── user_repository.dart # 账户仓储接口 + SQLite 实现
│   │   ├── settings_repository.dart # 设置仓储接口 + SQLite 实现
│   │   ├── post_store.dart      # 信息仓库（内存快照 + 落库）
│   │   ├── user_store.dart      # 账户仓库
│   │   ├── settings_store.dart   # 设置仓库
│   │   ├── photo_store.dart     # 图片仓库（保存/删除/清理/迁移）
│   │   ├── image_file_store.dart # 图片文件读写（真实实现）
│   │   └── mock_posts.dart      # 示例数据
│   ├── services/
│   │   └── photo_picker.dart    # 选图能力（相册/拍照），抽象接口 + 真实实现
│   ├── pages/                   # 界面层
│   │   ├── main_shell.dart      # 三大主界面外壳（首页/发布/我的）
│   │   ├── home_page.dart       # 首页
│   │   ├── publish_page.dart    # 发布界面
│   │   ├── profile_page.dart    # 我的界面
│   │   ├── post_detail_page.dart# 详细信息界面
│   │   ├── search_page.dart     # 搜索界面
│   │   ├── post_edit_page.dart  # 编辑界面
│   │   └── settings_page.dart   # 应用设置界面
│   ├── widgets/                 # 可复用组件
│   │   ├── post_card.dart       # 信息卡片（首页/搜索）
│   │   ├── my_post_card.dart    # 我的信息卡片（带管理操作）
│   │   ├── post_form.dart       # 发布/编辑共用表单
│   │   ├── post_filter_bar.dart # 筛选与排序条
│   │   ├── post_photo.dart      # 本地图片显示（读不出降级为图标）
│   │   ├── account_form.dart    # 账户登记/修改表单
│   │   └── coming_soon.dart     # 占位组件
│   ├── theme/
│   │   └── app_theme.dart       # Material 3 全局主题
│   └── utils/
│       └── time_format.dart     # 时间格式化工具
├── test/                        # 测试
│   ├── widget_test.dart         # 首页 widget 测试
│   ├── sqlite_storage_test.dart # 本地存储对拍测试
│   ├── photo_storage_test.dart  # 图片存储测试
│   ├── publish_page_test.dart   # 发布界面测试
│   ├── post_form_photo_test.dart# 表单选图测试
│   ├── post_edit_page_test.dart # 编辑界面测试
│   ├── post_detail_page_test.dart# 详情页测试
│   ├── profile_page_test.dart   # 我的界面测试
│   ├── search_page_test.dart    # 搜索界面测试
│   └── settings_page_test.dart  # 设置界面测试
├── android/                     # Android 平台配置
├── ios/                         # iOS 平台配置
├── docs/
│   ├── developer/intro.md       # 本文档
│   └── agents/                  # Agent 会话记录文档
├── pubspec.yaml                 # 依赖与项目元信息
├── analysis_options.yaml        # 静态分析配置
├── AGENTS.md                    # Agent 工作规则
├── LICENSE
└── README.md
```

---

## 3. 架构概览

### 3.1 分层

应用按以下层次组织，数据自上而下、事件自下而上：

```
┌─────────────────────────────────────────────┐
│  pages/          界面层（StatefulWidget / StatelessWidget）
│  widgets/        可复用组件
├─────────────────────────────────────────────┤
│  data/*Store     仓库层（内存快照 + ChangeNotifier）
│  data/*Repository 仓储接口 + SQLite 实现
├─────────────────────────────────────────────┤
│  models/         数据模型（不可变值对象）
│  data/db_schema  表结构定义
│  data/post_row   行编解码
├─────────────────────────────────────────────┤
│  data/app_database  SQLite 句柄（开库/建表/迁移/播种）
│  services/       平台服务（选图）
│  theme/          主题
│  utils/          工具函数
└─────────────────────────────────────────────┘
```

### 3.2 数据流

1. **启动时**：`main()` 打开 SQLite 数据库 → 创建各 `*Store`（持有 SQLite 仓储）→ 调用各 `store.load()` 把库中数据读入内存快照 → `runApp()` 挂载根组件。

2. **读取**：界面通过 `PostScope.of(context)` / `UserScope.of(context)` 等 `InheritedNotifier` 同步获取内存快照，无需 `await`。仓库变化时，依赖它的界面自动重建。

3. **写入**：界面调用 `store.addPost()` / `store.updatePost()` 等 → 先改内存快照并 `notifyListeners()`（界面立刻刷新）→ 再异步落库。写库失败时内存改动仍在，错误从 Future 抛出。

### 3.3 启动序列

`main()` 中的启动顺序有严格约束：

1. `WidgetsFlutterBinding.ensureInitialized()` —— 初始化平台绑定。
2. `AppDatabase.open()` —— 打开本地 SQLite；首次建库时建表 + 写入示例数据。
3. `PhotoStore.open()` —— 打开图片目录（数据库目录下的 `photos/`）。
4. `PhotoStore.applyPendingUpdates()` —— **先**迁移：把库里遗留的绝对路径搬进私有目录、改写成文件名。
5. `photoStore.reconcile()` —— **后**清理：删掉没有任何信息引用的孤儿图片。
   > 顺序不能反：反过来会把刚搬进来、还没被引用上的文件当成垃圾删掉。
6. 创建 `PostStore` / `UserStore` / `SettingsStore`（传入 SQLite 仓储）。
7. `store.load()` × 3 —— 把库里内容读进内存，避免首帧闪空列表或主题跳变。
8. `runApp(LostAndFoundApp(...))`。

---

## 4. 数据模型

### 4.1 `ItemPost` —— 一条失物/招领信息

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `String` | 是 | 主键，发布时按 `local-<微秒时间戳>` 生成 |
| `type` | `PostType` | 是 | `lost`（失物）/ `found`（招领） |
| `title` | `String` | 是 | 物品名称 |
| `category` | `ItemCategory` | 是 | 物品分类 |
| `location` | `String` | 是 | 丢失/拾取地点 |
| `eventTime` | `DateTime` | 是 | 丢失/拾取发生时间 |
| `contact` | `String` | 是 | 发布者联系方式 |
| `createdAt` | `DateTime` | 是 | 发布时间（排序用） |
| `description` | `String?` | 否 | 物品描述 |
| `imagePaths` | `List<String>` | 否 | 图片文件名列表（库里存文件名，非绝对路径） |
| `status` | `PostStatus` | — | `pending`（进行中）/ `resolved`（已完成），默认 `pending` |
| `isMine` | `bool` | — | 是否本机用户发布，默认 `false` |

**枚举**：

- `PostType`：`lost`（失物，"寻找中"/"已找到"）/ `found`（招领，"待认领"/"已归还"）
- `PostStatus`：`pending`（进行中）/ `resolved`（已完成）
- `ItemCategory`：`card`（证件卡类）、`digital`（电子产品）、`book`（书籍资料）、`key`（钥匙）、`clothing`（衣物服饰）、`daily`（生活用品）、`other`（其他）

`ItemPost` 是 `@immutable` 值对象，通过 `copyWith()` 做局部替换（如标记状态时只改 `status`）。

### 4.2 `UserAccount` —— 本机账户

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `displayName` | `String` | 称呼，如"张同学" |
| `contact` | `String` | 常用联系方式，发布时作为默认值 |
| `createdAt` | `DateTime` | 登记时间 |

> 这是**本机自用**的称呼与联系方式，不涉及密码与实名认证。全应用只有一个本地账户（`user_account` 表固定单行，主键 = 1）。

### 4.3 `PostQuery` —— 浏览/搜索查询

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `keyword` | `String` | 搜索关键词，空串表示不按关键词筛选 |
| `type` | `PostType?` | `null` 表示"全部" |
| `category` | `ItemCategory?` | `null` 表示"全部分类" |
| `sortBy` | `PostSortBy` | `newest`（最新发布）/ `oldest`（最早发布） |

`PostQuery.apply(List<ItemPost>)` 对内存快照应用筛选与排序。首页与搜索界面共用同一套判定逻辑（`ItemPost.matchesKeyword` / `ItemPost.matchesFilter`），避免两处各写一套日后走偏。

> **关键词匹配口径**：按空白拆成多个词，**全部命中才算命中**（"图书馆 雨伞" = 两样都得沾边）。SQL 版的 `LIKE` 查询与此同口径，由 `test/sqlite_storage_test.dart` 的对拍测试兜住。

---

## 5. 数据存储

### 5.1 SQLite 数据库

库文件 `lost_and_found.db`，落在系统给应用的数据库目录下。表结构集中在 `lib/data/db_schema.dart`。

**当前版本**：2

| 版本 | 变更 |
| --- | --- |
| 1 | 首版：`posts` + `user_account` |
| 2 | 新增 `app_settings`（应用设置键值表） |

#### 表：`posts`

| 列 | 类型 | 说明 |
| --- | --- | --- |
| `id` | TEXT PK | 信息主键 |
| `type` | TEXT | 枚举名（`lost`/`found`） |
| `title` | TEXT | 物品名称 |
| `category` | TEXT | 枚举名 |
| `location` | TEXT | 地点 |
| `event_time` | INTEGER | 毫秒时间戳 |
| `contact` | TEXT | 联系方式 |
| `created_at` | INTEGER | 毫秒时间戳（排序索引） |
| `description` | TEXT | 可空 |
| `image_paths` | TEXT | JSON 数组字符串 |
| `status` | TEXT | 枚举名 |
| `is_mine` | INTEGER | 0/1 |
| `search_text` | TEXT | 冗余列：标题+地点+描述+分类的小写拼接，供 `LIKE` 搜索 |

索引：`idx_posts_created_at`（按发布时间排序/取最新）。

#### 表：`user_account`（单行表）

固定主键 `id = 1`，`CHECK` 约束兜住不会出现第二行。写入用 `REPLACE`。

| 列 | 类型 |
| --- | --- |
| `id` | INTEGER PK (CHECK = 1) |
| `display_name` | TEXT |
| `contact` | TEXT |
| `created_at` | INTEGER |

#### 表：`app_settings`（键值表）

以设置名为主键，"写入"永远是覆盖。

| 列 | 类型 |
| --- | --- |
| `setting_name` | TEXT PK |
| `setting_value` | TEXT |

当前设置项：`theme_mode`（值 = `ThemeMode.name`：`system`/`light`/`dark`）。

### 5.2 仓储模式

每个数据域遵循统一的 **Store + Repository** 模式：

```
界面层  ←(同步读取/订阅)→  *Store (ChangeNotifier)  ←(异步落库)→  *Repository (SQLite)
                              ↑                               ↑
                         内存快照                          SQL 读写
```

- **`*Store`**（`PostStore` / `UserStore` / `SettingsStore` / `PhotoStore`）：继承 `ChangeNotifier`，内存里留一份快照供界面**同步**读取。有仓储时每次改动顺手写进本地库；无仓储时退回纯内存实现（测试与预览走这条）。
- **`*Repository`**（`ItemRepository` / `UserRepository` / `SettingsRepository`）：抽象接口，`Sqlite*Repository` 是其 SQLite 实现。界面层只见接口，不关心底下是 SQLite 还是内存。

### 5.3 状态下发

四个 `*Store` 通过 `InheritedNotifier` 沿 widget 树下发：

| Scope | 提供 | 可空 |
| --- | --- | --- |
| `PostScope` | `PostStore` | 否 |
| `UserScope` | `UserStore` | `maybeOf` 可空 |
| `SettingsScope` | `SettingsStore` | 否 |
| `PhotoScope` | `PhotoStore?` | 是（纯内存测试时为 null，界面按"没有图片"显示） |

不引入第三方状态管理（Riverpod / Bloc 等），`InheritedNotifier` + `ChangeNotifier` 足够。

### 5.4 图片存储

- **库里存文件名**（如 `p001-1.jpg`），不存绝对路径：应用目录在 iOS 上每次安装都变，绝对路径重装后失效。
- **图片目录**：数据库文件旁的 `photos/`，与库文件同生共死，清数据时一起清掉。
- **迁移**：启动时 `PhotoStore.applyPendingUpdates()` 把库里遗留的绝对路径搬进私有目录、改写成文件名。幂等：已经是文件名的行原样跳过。
- **清理**：`PhotoStore.reconcile()` 删掉没有任何信息引用的孤儿图片。必须**在迁移之后**执行。
- **表单会话**：`FormImageSession` 管理编辑中的草稿图。保存（`commit`）后图片归信息所有；还原/清空/退出（`discard`）时删掉，不留垃圾。

### 5.5 数据库迁移

表结构改动时：

1. 升 `DbSchema.version`。
2. 在 `create()` 之外补迁移逻辑（`AppDatabase.open` 的 `onUpgrade`）。
3. 迁移里**不能**调 `create()` —— 那会把已存在的表再建一遍，且建表语句不带 `IF NOT EXISTS` 会直接报错。需要单独抽取建表方法（如 `createSettingsTable`）。

---

## 6. 界面层

### 6.1 主界面外壳 `MainShell`

底部 `NavigationBar` 切换三个主界面：**首页** / **发布** / **我的**。`IndexedStack` 让三个界面各自保留滚动位置与输入状态。

### 6.2 页面清单

| 页面 | 文件 | 类型 | 说明 |
| --- | --- | --- | --- |
| 首页 | `home_page.dart` | 主界面 | 浏览信息列表，搜索栏入口，类型/分类/排序筛选 |
| 发布 | `publish_page.dart` | 主界面 | 表单填写信息，校验后写入仓库，成功弹窗 |
| 我的 | `profile_page.dart` | 主界面 | 账户登记，我的发布列表，管理操作（标记/修改/删除） |
| 详情 | `post_detail_page.dart` | 次级 | 按 id 现查信息，展示全部内容+联系方式（一键复制），图片轮播+全屏查看 |
| 搜索 | `search_page.dart` | 次级 | 关键词搜索（输入即搜），结果可再筛选 |
| 编辑 | `post_edit_page.dart` | 次级 | 回填原信息，保存后替换，未保存改动时拦截返回 |
| 设置 | `settings_page.dart` | 次级 | 外观（主题模式）、账户、应用信息 |

### 6.3 关键设计

- **详情页按 id 现查**：`PostDetailPage` 不接收快照，而是用 `postId` 从 `PostStore.postById()` 现查。用户改了内容再切回来时显示新内容；信息被删则落到空态。
- **编辑页拦截返回**：有未保存改动时 `PopScope` 拦下系统返回，确认后再走。`PostFormState.isDirty` 比较会写入的各字段（`trim` 后），多打空格不算改动。
- **表单共用**：`PostForm` 同时服务发布与编辑，字段与校验完全一致，只是初值和提交后流程不同。
- **联系方式自动带出**：发布表单的联系方式字段会自动填充本机账户的联系方式（空的才填，不覆盖用户输入）。
- **图片降级显示**：`PostPhotoView` 读不到文件时退回分类图标，不崩。

---

## 7. 主题

`lib/theme/app_theme.dart` 定义全局 Material 3 主题：

- 品牌种子色 `#00695C`（青色），`ColorScheme.fromSeed` 据此派生整套明/暗配色。
- 浅色 `AppTheme.light()` / 深色 `AppTheme.dark()`。
- 主题模式（跟随系统/浅色/深色）存于 `app_settings` 表，启动时读回，避免先画默认主题再跳。
- 全局配置：AppBar 居左无阴影、Card 圆角 16 无阴影、导航栏阴影 3。

---

## 8. 测试

### 8.1 运行测试

```bash
# Flutter 的完整测试
flutter test

# 指定测试文件
flutter test test/widget_test.dart

# 生成覆盖率报告
flutter test --coverage
```

覆盖率报告可以通过 `genhtml coverage/lcov.info -o coverage/html` 生成 HTML 以查看。对于 VSCode 用户，还可以使用这些插件：

- Flutter Coverage，树状图形式呈现项目和文件级别的覆盖率。
- Coverage Gutters，逐行提示代码是否被覆盖。

### 8.2 测试组织

| 文件 | 覆盖范围 |
| --- | --- |
| `widget_test.dart` | 首页展示、筛选菜单、排序切换、搜索栏跳转 |
| `sqlite_storage_test.dart` | 建库播种、读写、查询对拍（SQL == 内存版）、写穿 |
| `photo_storage_test.dart` | 图片保存、删除、清理、迁移 |
| `publish_page_test.dart` | 发布表单填写与校验 |
| `post_form_photo_test.dart` | 表单选图流程 |
| `post_edit_page_test.dart` | 编辑回填、还原、未保存拦截 |
| `post_detail_page_test.dart` | 详情展示、联系方式复制、空态 |
| `profile_page_test.dart` | 账户登记、管理操作 |
| `search_page_test.dart` | 搜索输入即搜、空态分流 |
| `settings_page_test.dart` | 主题切换、账户管理、应用信息 |

### 8.3 测试策略

- **纯内存模式**：`LostAndFoundApp()` 不传任何仓库时，组件自建内存仓库 + 示例数据，`PhotoStore` 为 null。widget 测试走这条，不碰真实 I/O。
- **SQLite 对拍**：`sqlite_storage_test.dart` 用 `sqflite_common_ffi` + 内存库，验证 SQL 版查询与内存版 `PostQuery.apply` 结果一致。
- **可测试性**：`PhotoPicker` / `ImageFileStore` 抽成接口，测试中替换为假实现，避免真实相册/相机弹窗和磁盘 I/O。

---

## 9. 编码规范

### 9.1 Lint

- 使用 `flutter_lints`（`analysis_options.yaml` 中 `include: package:flutter_lints/flutter.yaml`）。
- 必要时用 `// ignore: lint_name` 按行抑制，或 `// ignore_for_file: lint_name` 按文件抑制，需写明原因。

### 9.2 Key 命名

widget 上大量使用 `Key` 供测试定位，命名有前缀约定：

| 前缀 | 来源 |
| --- | --- |
| `home-*` | 首页控件 |
| `publish-*` | 发布/编辑表单控件（共用） |
| `profile-*` | 我的界面控件 |
| `search-*` | 搜索界面控件 |
| `detail-*` | 详情页控件 |
| `settings-*` | 设置界面控件 |

共享控件用 `keyPrefix` 参数避免 Key 撞车（如 `PostFilterBar` / `AccountForm`）。

### 9.3 文档注释

- 公开 API 一律写 `///` 文档注释，说明用途、参数含义、边界条件。
- 复杂逻辑（迁移顺序、校验时机、枚举容错等）在注释里写清**为什么**，不只写**做什么**。

---

## 10. 版本

`pubspec.yaml` 中 `version: 1.0.0+1`。`lib/app_info.dart` 中 `AppInfo.version` / `AppInfo.buildNumber` 与之**手工保持一致**——改版本号时两处一起改。

---

## 11. 补充

- **Agent 会话记录**：见 `docs/agents/`。后续 Agent 先读 `docs/agents/basic-info.md` 获取总体状态，再读分文档。
- **平台配置**：Android/iOS 的权限声明、签名配置等在各自平台目录下。
- **SQLite 系统库**：`pubspec.yaml` 的 `hooks.user_defines.sqlite3` 配置各平台加载系统自带 SQLite（Android `sqlite3`、Windows `winsqlite3`、iOS/macOS/Linux `sqlite3`），不从 GitHub 下载预编译二进制。
