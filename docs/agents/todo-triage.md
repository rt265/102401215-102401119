# 代码中三处 TODO 的排查与订正（2026-10-07）

本轮不改功能，只做一件事：把 `lib/` 里的三处 `TODO` 查清楚——它们各自的前提还成不成立、
该做还是该删——然后把**已经和代码对不上的注释与文档**订正回来。

起因：`lib/` 全目录只剩三处 `TODO`（`FIXME` / `HACK` / `XXX` / `TEMP` / `待办` 均无命中），
其中两处写着「接入本地 SQLite 后……」，而 SQLite 早已在本地后端事项 1 落地。
它们到底还算不算待办，需要一次判定，否则后继 Agent 会把已经不该做的事重新做一遍。

## 排查方法

1. 出处：`git log -S` 定位每处 `TODO` 是哪个提交写下的；
2. 前提：逐条比对注释里写的前提（「接入 SQLite」「区分账户」）与当前代码 / 表结构；
3. 调用方：找 `queryPosts` / `isMine` 的全部调用点，区分生产代码与测试；
4. 结论：能做的、不该做的、将来做的，分别处理。

`TODO` 的出处：

| TODO | 位置 | 写下的提交 |
| --- | --- | --- |
| 主键生成 | `lib/widgets/post_form.dart` | `686c680`（UI 事项 3「我的」界面） |
| `isMine` 判定 | `lib/models/item_post.dart` | `686c680`（同上） |
| 改用 `queryPosts` | `lib/data/item_repository.dart` | `30ca319`（本地后端事项 1，SQLite 落地） |

前两处写下时项目还没有 SQLite（内存仓库阶段），第三处是落库当轮写下的前瞻备忘。

## 结论

| TODO | 前提是否满足 | 处理 |
| --- | --- | --- |
| 主键生成 | 满足，但**结论与落地的表结构冲突** | 删掉 `TODO`，改写为设计说明 |
| `isMine` 判定 | 只满足一半（落库完成，**多账户不在范围内**） | 保留，改写前提 |
| 改用 `queryPosts` | 是「将来再说」的性能备忘，不是缺陷 | 保留，补上当前调用状况 |

### ① 主键生成：前提已满足，但结论走不通

原文：`// TODO(storage): 接入本地 SQLite 后由数据库生成主键。`
实际代码：`id: 'local-${now.microsecondsSinceEpoch}'`。

SQLite 确实接入了，但接入后的表结构把「数据库生成主键」这条路堵死了：
`DbSchema.create()` 把主键声明成 `id TEXT NOT NULL PRIMARY KEY`，
**SQLite 不会给 TEXT 主键自动填值**——要走数据库生成，得改成 `INTEGER` + AUTOINCREMENT
（或引入 UUID 生成）。

改动代价也不止一行：`ItemPost.id` 是必填的 `final String`；`PostRow.toRow()` 每次写入都带上 id；
`PostStore.addPost()` 是「先改内存快照、再落库」，要拿数据库生成的 id 就得反过来先插库再回填；
`postById()` / `updatePost()` / `deletePost()` 全按 id 定位。

附带记一笔低危隐患：`SqliteItemRepository.insertPost()` 用的是
`ConflictAlgorithm.replace`，同一微秒生成的两个 id 会**静默覆盖**。
UI 上一次表单提交只产生一个 id，实际碰不到，故本轮不动它。

### ② isMine：只做到一半，另一半超出本期范围

原文：`/// TODO(storage): 接入本地 SQLite 并区分账户后，改由发布者 id 判断。`

**已经做到的那半**是落库：`is_mine` 列在 `DbSchema` 里（建表语句 `is_mine INTEGER NOT NULL`），
编码见 `PostRow.toRow()`、解码见 `PostRow.fromRow()`，往返断言在
`test/sqlite_storage_test.dart` 的「写入的信息连同每个字段一起落库」用例里。

**没做到的那半是「区分账户」**，而且它被明确排除在范围外：
`user_account` 被设计成固定单行表（`accountRowId = 1`，注释写着「应用是单机自用的，只存一行」），
`posts` 表没有发布者列，`UserAccount` 也没有超出该行主键的身份；
`basic-info.md` 的「WARN」一节明确「不要求实现复杂后台管理、实名认证」。

语义上 `isMine` 现在等于「本机用户发的 vs 示例数据」：`ProfilePage` 用它列「我的发布」，
`SettingsPage` 用它统计条数。只有一个本地账户时，多一列 `author_id` 得不出比这个布尔值更多的信息。
所以本轮把它写成**前提是「多账户」，不是「落库」**。

### ③ 改用 queryPosts：备忘有效，但那份 SQL 现在只在测试里活着

原文：`/// TODO: 数据量大到内存放不下时，把列表页改成直接 await queryPosts(...)，`
`/// 界面层构造 [PostQuery] 的用法不用变。`

这是前瞻备忘，和 `lib/models/post_query.dart` 的类注释是一对：列表页走 `PostQuery.apply()`
是为了「点一下就出结果」，本地这点数据不值得加一次异步查询。

排查中值得记下来的是调用状况：**`queryPosts` 在生产代码里只有一个调用点**——
`PostStore.load()` 传的是 `const PostQuery()`（全空条件），`_conditionFor()` 拼出来的 `WHERE`
是空串、`where` / `whereArgs` 都传 `null`。于是 `SqliteItemRepository` 里那套关键词拆词 /
`LIKE` 转义（`_conditionFor` / `_tokensOf` / `_escapeLike`）目前**只由对拍测试守着**。
它不是没人要的死代码，是给这条 TODO 预备的接口——两个结论都要写清楚，
否则后继 Agent 要么误以为列表页已经在用 SQL 查，要么顺手把它当死代码删掉。

## 本轮改动

| 文件 | 改动 |
| --- | --- |
| `lib/widgets/post_form.dart` | 把主键 `TODO` 换成设计说明（TEXT 主键无法自增 + id 必须先于落库定下来） |
| `lib/models/item_post.dart` | `isMine` 的 `TODO` 改写：前提从「接入 SQLite」（已完成）改成「多账户」 |
| `lib/data/item_repository.dart` | 保留 `TODO`，补上「当前只有启动装载在走」「那套 SQL 由对拍测试守着，别当死代码删」 |
| `docs/agents/storage-01-sqlite.md` | 订正漂移 3 处：①「`post_query.dart` 里 `TODO(storage)` 现在写的内容」指向了不存在的 TODO（文件清单与「两份实现」两处都这么写）；②「图片选择与展示还没做」已被事项 2 补齐 |
| `docs/agents/basic-info.md` | 「已完成的问题修复」表里挂上本文档 |

改动全部是注释与文档，**没有动任何逻辑**，因此不需要新的测试用例。

## 刻意没做的事

- **没删 `isMine`、没加 `author_id`**：单账户应用里两者信息量相同，加列等于给一次数据库迁移换零收益。
- **没改主键生成方式**：现状（客户端按微秒生成 TEXT 主键）自洽，改成自增或 UUID 的收益不抵上面列出的连锁改动。
- **没动 `ConflictAlgorithm.replace`**：它带来的覆盖风险在 UI 上不可达，贸然改成 `abort` 反而会让重试路径抛异常。
- **没重排 `post_query.dart` 的注释**：那里早已没有 `TODO`，是文档在描述一个已经不在的东西，改文档即可。

## 验证

- `flutter analyze` → **No issues found!**（`analyze` 命令开头的 `flutter pub get` 未再单独跑，依赖未变）
- `flutter test` → **118 个用例全部通过**（`All tests passed!`，与改动前一致）。
- 语义检查：改完后 `grep TODO lib/` 只剩 `lib/data/item_repository.dart` 一处命中。
- 本轮只改注释与文档、未改逻辑，因此没有新增测试用例。

## 注意事项（后继 Agent 必读）

- **`lib/models/post_query.dart` 里没有 `TODO` 了**。文档里若再见到「`post_query.dart` 的 `TODO(storage)`」，
  那是历史描述，指的是类注释里「同一套条件有两份实现，改判定时两处都要改」这段说明文字。
- **三处 `TODO` 有各自的处置，别一律照做**：`item_repository.dart` 的那处是唯一还成立的待办，
  它的触发条件是「数据量大到内存放不下」，不是「有空就做」。
- **`isMine` 想改成发布者 id 判断，先做多账户**，`user_account` 单行表是硬前提，
  见 `basic-info.md` 的「WARN」。
