# 本地后端事项 1：数据迁移至本地 SQLite

对应 `docs/agents/basic-info.md` 中「然后是本地后端建设」的第 1 项：**数据迁移至本地 Sqlite，保留示例数据**，
以及「Storage Notice」原文：用户所有数据保存在本地 SQLite 数据库，功能在本地闭环。

## 本轮目标

UI 阶段的信息与账户都放在内存仓库里（`PostStore` / `UserStore`，初始内容是 `lib/data/mock_posts.dart`），
关掉应用就没了。本轮把这两份数据落到本地 SQLite：

- 首次打开应用**自动建库**并写入原来的 9 条示例数据（用户看到的内容与 UI 阶段一致）；
- 之后用户发布 / 修改 / 删除 / 标记、登记账户，全部写进本地库，重开应用还在；
- **界面层一行不改**：三大主界面仍同步读内存快照，筛选仍是即时的。

范围：不碰界面交互，不做图片选择、不做多用户 / 登录态、不做云同步。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 建库与表结构 | `lib/data/db_schema.dart`：库版本 / 表名 / 列名常量都只在这里写一遍，DDL 由常量拼出来，避免「常量与 SQL 各写一份」漂移 |
| 行 ↔ 对象映射 | `lib/data/post_row.dart`：`ItemPost` 与数据库行互转（枚举存 `name`、时间存毫秒、图片存 JSON 字符串），并生成检索列 `search_text` |
| 数据库生命周期 | `lib/data/app_database.dart`：`AppDatabase.open()` 打开（可注入 `DatabaseFactory` 与路径）、首建时写示例数据、`close()` |
| 信息仓储 | `lib/data/item_repository.dart`：`ItemRepository` 接口 + `SqliteItemRepository`（查询 / 新增 / 修改 / 删除） |
| 账户仓储 | `lib/data/user_repository.dart`：`UserRepository` 接口 + `SqliteUserRepository`（单行账户表） |
| 仓库改造 | `lib/data/post_store.dart` / `lib/data/user_store.dart`：内存快照 + **写穿**（改动先落内存并通知界面，再写库）；有仓储时启动用 `load()` 读回 |
| 启动装配 | `lib/main.dart`：`main()` 变异步，开库 → 建两个 Store（注入仓储）→ `load()` → `runApp()` |
| 依赖 | 运行时 `sqflite` 2.4.4+1、`path` 1.9.1；测试用 `sqflite_common_ffi` 2.4.3（dev，含 `sqlite3` 3.5.2） |

## 文件清单

```
lib/
  data/db_schema.dart        新增：库版本、表名、列名常量与建表 DDL
  data/post_row.dart         新增：ItemPost ↔ 数据库行，含 search_text 生成
  data/app_database.dart     新增：打开/建库/写示例数据/关闭
  data/item_repository.dart  新增：ItemRepository + SqliteItemRepository
  data/user_repository.dart  新增：UserRepository + SqliteUserRepository
  models/user_account.dart   新增：UserAccount 从 data/user_store.dart 搬来（模型不该住在 data/ 的 store 里）
  data/post_store.dart       改写：内存快照 + 写穿仓储，load()
  data/user_store.dart       改写：同上（账户部分）
  data/mock_posts.dart       仅注释更新：说明它现在是「建库时的初始内容」
  models/post_query.dart     仅注释更新：说明 SQL 版判定在 SqliteItemRepository
  main.dart                  改写：异步启动 + 注入仓储；LostAndFoundApp 支持外部注入 Store
  pages/profile_page.dart    加一行 import（UserAccount 换了位置）
test/
  sqlite_storage_test.dart   新增：19 个用例（建库 / 读写 / 查询 / 账户 / 写穿）
```

`pubspec.yaml` 新增 `sqflite`、`path` 依赖与 `sqflite_common_ffi` 开发依赖。

## 表结构

库文件：`getDatabasesPath()` 下的 `lost_and_found.db`（应用私有目录，不进 git），版本 `1`。

```sql
CREATE TABLE posts (
  post_id       TEXT PRIMARY KEY,
  post_type     TEXT NOT NULL,      -- PostType.name
  title         TEXT NOT NULL,
  category      TEXT NOT NULL,      -- ItemCategory.name
  location      TEXT NOT NULL,
  event_time    INTEGER NOT NULL,   -- 毫秒时间戳
  contact       TEXT NOT NULL,
  created_at    INTEGER NOT NULL,
  description   TEXT,               -- 选填
  image_paths   TEXT NOT NULL,      -- JSON 数组字符串
  status        TEXT NOT NULL,      -- PostStatus.name
  is_mine       INTEGER NOT NULL,   -- 0 / 1
  search_text   TEXT NOT NULL       -- 检索用：标题+地点+描述+分类名，小写，换行连接
);
CREATE INDEX idx_posts_created_at ON posts (created_at);

CREATE TABLE user_account (         -- 本机只登记一个账户，固定单行
  id           INTEGER PRIMARY KEY CHECK (id = 1),
  display_name TEXT NOT NULL,
  contact      TEXT NOT NULL,
  created_at   INTEGER NOT NULL
);
```

`search_text` 是为了让 SQL 关键词查询与 `ItemPost.matchesKeyword` 同口径：拼的是
`title / location / description / category.label`（**分类按中文标签**，用户搜「电子产品」能命中），
中间用换行连接，保证一个词不会跨字段接上。

## 读写路径

**读**：界面照旧从 `PostScope` / `UserScope` **同步**读内存快照。没有改成 `FutureBuilder` 或异步查询，
因为首页 / 搜索的筛选排序是「点一下就该出结果」的即时交互，一次异步查询会让 chip 变卡。
库里的数据只在启动（`load()`）和写完之后进内存。

**写**：`addPost` / `updatePost` / `removePost` / `register` / `signOut` 都是

1. 先改内存 + `notifyListeners()`（界面立刻响应）；
2. 再 `await` 仓储写库，**错误不吞**——写失败会从返回的 `Future` 抛给调用方。

方法签名从 `void` 变成 `Future<void>`，是源码兼容的：现有界面全部不 `await`（发布、编辑、标记、删除、
登记、退出），因此**页面代码一行没改**。将来要做「写失败提示」时，把 `await` 补上即可。

**启动**：`main()` → `WidgetsFlutterBinding.ensureInitialized()` → `AppDatabase.open()` →
`PostStore(repository: SqliteItemRepository(db))` / `UserStore(repository: SqliteUserRepository(db))` →
两个 `load()` → `runApp(LostAndFoundApp(postStore:, userStore:))`。

`LostAndFoundApp` 的 `postStore` / `userStore` 都是可选参数：**不传时仍是纯内存仓库 + 示例数据**
（`const LostAndFoundApp()` 行为与 UI 阶段完全一致），这样 `test/widget_test.dart` 那 6 个
「打开应用看首页」的用例不需要起数据库；State 里只 dispose 自己创建的那两个 Store。

## 查询一致性（SQL ↔ Dart 对拍）

关键词与筛选的判定现在有**两份实现**，必须同口径：

- 内存侧：`ItemPost.matchesKeyword()` / `PostQuery.apply()`（列表页即时筛选走这条）；
- SQL 侧：`SqliteItemRepository.queryPosts()`（启动加载与将来分页查询走这条）。

对齐规则：

- 关键词按空白拆词、全部命中才算命中（`WHERE` 里每个 token 一条 `search_text LIKE ?` 用 AND 连接）；
- 大小写不敏感：`search_text` 存的就是小写，查询参数也 `toLowerCase()`；
- token 里的 `%`、`_`、`\` 是 LIKE 通配符，逐个用 `ESCAPE '\'` 转义（不转义的话搜 `%` 会把整库捞出来）；
- 排序只按 `created_at DESC` / `ASC`，**不加第二排序键**——内存版的 `List.sort` 本就不稳定，
  并列时顺序未定义，多加一个键反而会让两边不一致。

`test/sqlite_storage_test.dart` 里有一组**对拍测试**：17 个 `PostQuery`（含 `%`、`_`、`伞%` 三个转义判别用例）
同时喂给 SQL 与 `PostQuery.apply()`，比较 id 列表是否一致。**改判定时两处都要改**，这一点现在写在
`lib/models/post_query.dart` 的类注释里——那个文件里原本的 `TODO(storage)` 后来被改写成了说明文字，
仓库里已经搜不到它（订正记录见 [todo-triage.md](./todo-triage.md)）。

## 示例数据策略

`buildMockPosts()` 原样保留，现在有两个用途：

1. `AppDatabase` 首建库时（`onCreate`）写进 `posts` 表；
2. 纯内存模式（不传仓储）下作为 `PostStore` 的初始内容——测试与预览仍走这条。

示例数据**只在首建库时写一次**：用户把它删掉之后，重开应用不会又冒出来。

## 测试

`test/sqlite_storage_test.dart`，5 组 19 个用例（`flutter test test/sqlite_storage_test.dart` 全过）：

| 组 | 覆盖 |
| --- | --- |
| 建库与示例数据 | 首建写入 9 条示例数据、全字段原样读回、重开同一个文件库不再写示例数据（删掉的 p001 不会回来） |
| 读写 | 全字段落库并读回、选填字段留空读回仍是 null / 空 / pending / false、修改覆盖原行、删除、重开文件库后自己写的信息还在 |
| 查询 | 关键词（名称 / 地点 / 分类名 / 多词）、类型与分类筛选、两种排序、**SQL 与 `PostQuery.apply()` 对拍 17 例** |
| 账户 | 保存与读回、覆盖只有一行（`COUNT(*) == 1`）、清空、重开还在 |
| 仓库写穿 | `PostStore` 装载 / 增 / 改 / 删都落库、`load()` 丢掉内存原有内容、`UserStore` 登记与退出落库、**没有仓储时仍是纯内存仓库** |

测试里用的是 `databaseFactoryFfi` + `inMemoryDatabasePath`（内存库）或 `Directory.systemTemp` 下的临时文件库，
`seededAt` 固定成 `DateTime(2026, 5, 1, 12)` 把示例数据的相对时间钉死，避免用例随运行时刻漂移。

## 验证

- `flutter analyze` → **No issues found!**
- `flutter test` → **79 个用例全部通过**（含本轮的 19 个、以及 UI 阶段原有的 60 个）。
- 命令按 `AGENTS.md` 用 `flutter pub get` / `flutter analyze` / `flutter test`；本次会话权限为 danger-full-access，
  受限沙箱下的表现见 `basic-info.md` 的「环境备忘」。

## 注意事项（后继 Agent 必读）

- **测试里必须注入 ffi**：`databaseFactory` 在 `flutter test` 的宿主上不可用，测试统一走
  `sqflite_common_ffi` 的 `sqfliteFfiInit()` + `databaseFactoryFfi`。应用侧（Android / iOS / 桌面）用默认的
  `databaseFactory`，两者只在 `AppDatabase.open(factory:)` 这一个参数上分岔。
- `sqlite3` 3.5.2 走 Dart hooks 拉原生库：默认从 GitHub release 下载预编译 `sqlite3.dll`，缓存进
  `.dart_tool/hooks_runner/`（已被 gitignore），**换机器 / 清 `.dart_tool` 后需要联网 GitHub 重新下载**。
  不想联网时可在 `pubspec.yaml` 里改走系统库：
  `hooks: user_defines: sqlite3: {source: system, name_windows: winsqlite3}`。
- 首建库写入的示例数据用了毫秒时间戳（相对 `DateTime.now()`），所以**不同设备之间同一条信息的 `created_at` 不同**，
  测试断言请只比自己刚写进去的值，别硬编码示例数据的时间。
- 图片字段 `image_paths` 已经在库里；图片选择与展示在本轮还没做，后来由本地后端事项 2 补齐
  （见 [storage-02-photos.md](./storage-02-photos.md)）。
- 库版本还是 `1`，`AppDatabase._upgrade` 是个空实现：**下次改表结构时先想清楚要不要迁移**，
  现有的用户数据只在用户自己的设备上，没有远端备份。
- 仓库只有 `android/` 与 `ios/` 两个平台目录（移动端应用），所以应用侧用 `sqflite` 默认的 `databaseFactory`
  就够；**将来若要跑 Windows / Linux 桌面**，运行时也得换成 `sqflite_common_ffi`（把它从 dev_dependencies
  提到 dependencies，并在 `AppDatabase.open(factory:)` 那里按平台注入），否则开库时没有可用的实现会直接抛错。
