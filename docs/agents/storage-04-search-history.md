# 本地后端事项 4：搜索记录

对应 `docs/agents/basic-info.md` 中「本地后端建设」的第 4 项：**搜索记录**。

## 本轮目标

搜索界面一直少一块：搜过什么，关掉页面就忘了。上一轮 [ui-05-search-page.md](./ui-05-search-page.md) 里
写得很明白——「搜索历史没做：没有持久化层，存了也留不住（等 SQLite 接入后再考虑）」。
本地库已经就位，本轮把这笔账补上：

- 搜过的关键词**落进本地库**，重开应用还在；
- 搜索界面的引导态摆出「最近搜索」，点一下就能重搜，每个词带小叉可单条删除，另有「清空」；
- 只在**明确的搜索动作**时记一笔，不为每一次键盘输入记账；
- 本地库版本 **2 → 3**，老库（v1 / v2）能一路升上来。

范围：不记筛选条件与结果条数、不给搜索记录排序或再搜索、不做多用户隔离
（单账户应用，见 [todo-triage.md](./todo-triage.md)）。

## 核心决策（后继 Agent 改这块之前先读）

| 决策 | 理由 |
| --- | --- |
| **单开一张 `search_history` 表**（`keyword TEXT PK` + `searched_at INTEGER`），没塞进 `app_settings` 键值表 | 键值表里只能把一串词编码成 JSON 存一格，**逐条删除与「最近在前」的排序语义都要在应用层自己维护**，一删一改都是整串重写。独立表让「删一条」「取最近 N 个」各是一句 SQL |
| **`keyword` 直接作主键**，写入走 `ConflictAlgorithm.replace` | 「同一个词只留一行、重搜挪到最前」是一步到位的：主键撞了就是覆盖行（顺带把 `searched_at` 推到最新），不需要先查后写 |
| 排序 `ORDER BY searched_at DESC, rowid DESC` | `searched_at` 是毫秒时间戳，**同一毫秒内连记两个词时只靠它分不出先后**；`rowid` 是插入序，正好当兜底 |
| `SearchHistoryStore.maxKeywords = 10` | 「一屏放得下、又足够复现上一次找东西的过程」的量。再多也没人往下翻，反而把引导语和示例词挤没 |
| **只在明确动作时记**：键盘搜索键、点最近搜索 chip、点示例词 chip。`onChanged` 一律不记 | 敲「一卡通」会先经过「一」「一卡」「一卡通」三个状态，边打边记等于用前缀占满整个列表 |
| 判重**忽略大小写**（`IPHONE` 与 `iphone` 算同一个词），记之前 `trim()`，纯空白的词直接丢弃 | 前者是因为 SQLite 的 `TEXT` 主键是大小写敏感的，不折叠就会在库里留下两行看起来一样的词；后者是因为「敲了空格就回车」太常见，那不是一次搜索 |
| 历史区块**只在引导态出现**，出了结果就收起来 | 结果列表才是主角。历史是没东西可看时的入口，不是常驻侧栏 |
| 「清除筛选」空态里的词用另一套 Key（`search-history-suggestion-<词>`） | 引导态的 chip 是 `search-history-<词>`。两个区块理论上不同屏，但**同一个词在两处同屏就会 Key 撞车**，索性分开命名 |
| 清空全部**先弹确认框**，单条删除不弹 | 「清空」收不回来，代价是整个列表；单条删错只是少一个词，不值得打断 |

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 表结构 | `lib/data/db_schema.dart`：`historyTable` / `historyKeyword` / `historySearchedAt` 常量、`createSearchHistoryTable()`、`version` 2 → 3、`create()` 末尾建表 |
| 迁移 | `lib/data/app_database.dart`：`_upgrade` 里 `if (from < 3) createSearchHistoryTable(db)`，v1 老库逐级补上设置表与搜索记录表 |
| 仓储 | `lib/data/search_history_repository.dart`（新增）：`SearchHistoryRepository` 接口 + `SqliteSearchHistoryRepository` + `MemorySearchHistoryRepository`（测试/预览用） |
| 仓库 | `lib/data/search_history_store.dart`（新增）：`SearchHistoryStore` + `SearchHistoryScope` |
| 装配 | `lib/main.dart`：`main()` 里开库后建 `SearchHistoryStore(repository: SqliteSearchHistoryRepository(...))` 并 `await load()`；`LostAndFoundApp` 收一个可空的 `searchHistoryStore`，不传则自建内存版；build 里插入 `SearchHistoryScope` |
| 界面 | `lib/pages/search_page.dart`：`_onSubmitted` 记一笔、`_searchKeyword` 记一笔、`_removeHistory` / `_clearHistory`（带确认框）；引导态改为纵向滚动并新增 `_SearchHistorySection` |

## 文件清单

```
lib/
  data/db_schema.dart                  改动：+ search_history 表、版本 2 → 3
  data/app_database.dart               改动：_upgrade 补 v3 迁移
  data/search_history_repository.dart  新增：接口 + SQLite 实现 + 内存实现
  data/search_history_store.dart       新增：SearchHistoryStore / SearchHistoryScope
  main.dart                            改动：装配 SearchHistoryStore 与 SearchHistoryScope
  pages/search_page.dart               改动：记录时机、最近搜索区块、删除与清空

test/
  search_history_test.dart             新增：19 个用例（SQL 仓库 6 / 内存仓库 3 / Store 8 / 版本迁移 2）
  search_page_history_test.dart        新增：10 个 widget 用例（记录时机、删除、清空、收起）
  search_page_test.dart                改动：脚手架换成 buildSearchHost
  sqlite_storage_test.dart             改动：迁移用例改名并补「新表可用」断言
  helpers/page_harness.dart            改动：+ buildSearchHost
```

## 数据流

```
界面动作（键盘搜索键 / 点最近搜索 chip / 点示例词 chip）
  → SearchHistoryScope.of(context).record(word)
        ↓
SearchHistoryStore.record()：trim → 大小写无关判重 → 挪到最前 → 截到 10 个 → notifyListeners()
        ↓（有仓储时）
SqliteSearchHistoryRepository.addKeyword(word, DateTime.now())
  → INSERT OR REPLACE INTO search_history(keyword, searched_at)   ← 主键撞了就是覆盖
        ↓
下次启动：main() 里 await searchHistoryStore.load()
  → SELECT keyword ... ORDER BY searched_at DESC, rowid DESC LIMIT 10
  → 引导态读到 keywords，摆出「最近搜索」
```

## 已知限制 / 后续可做

- **同一个词在库里只会有一行**：重搜覆盖而不是追加，所以「这个词我搜过几次」是不存在的。
  真要做「常用词」，得另加一列计数，不是现在这张表能顺手给出的。
- `searched_at` 只用于排序，界面上不显示「什么时候搜的」。
- 记进去的是**用户敲下的原文**（只 `trim`），大小写与全半角不做归一化。
  折叠只用在判重上，显示与回填都保持原样。
- 「最近搜索」只在引导态出现。若将来希望关键词为空但有结果时也看到历史，要重新考虑版面。

## 本轮踩到的坑（有价值，别重踩）

1. **搜索是子串匹配，不是同义词——造测试数据时关键词必须字面出现。**
   `ItemPost.matchesKeyword`（`lib/models/item_post.dart:155-174`）把关键词按空白拆成 token，
   在 title / location / description / `category.label` 上做 `toLowerCase().contains(token)`。
   最初测试数据写的是「黑色折叠伞」，搜「雨伞」**搜不到**（「折叠伞」里没有「雨伞」这两个字），
   表现为 2 个用例报 `PostCard findsNothing`。改用「黑色自动雨伞」（也是示例数据里的真标题）才对。
   写这条的教训是：**先确认数据里真的有那个字，再去断言搜得到**。

2. **`prefer_initializing_formals` 在 `flutter analyze` 里算问题**（info 级也会让命令非零退出）。
   构造函数写成 `X({T? p}) : _p = p;` 就会报。两条出路：把字段改成公开的用 `this.p` 初始化形参
   （`SearchHistoryStore.repository` 走的就是这条，因为它确实需要一个公开的仓储句柄），
   或者加一行 `// ignore: prefer_initializing_formals` 并说明原因
   （`MemorySearchHistoryRepository` 走这条，因为参数名 `readLimit` 与字段名 `_readLimit` 不同名）。

3. **测试文件的顶层私有符号不能跨文件复用。**
   `sqlite_storage_test.dart` 的 `openMemory()` / `makeTempDir()` / `createVersion1Schema` 等都是
   该文件的私有顶层符号，`search_history_test.dart` 引用不了，只能在文件内重写一份。
   这是有意的取舍：比起抽公共 helper，**让每个存储测试自带脚手架**更容易单独读、单独改。

4. 用 PowerShell `Set-Content -Encoding UTF8` 改文件会写成 **UTF-8 无 BOM、LF 行尾**；
   仓库工作区是 CRLF，之后 `git diff` 会警告 `LF will be replaced by CRLF`。
   内容没错，但说明那个文件的行尾被换过一遍。

## 验证

- `flutter analyze`：**No issues found!**
- `flutter test`：**174 个用例全部通过**（含既有未回归的用例）。
  新增覆盖：
  - SQL 仓库——记下能读回、最近在前、重搜只挪位置且表里仍是一行、limit 截断、
    删一条 / 删不存在的词 / 清空、重开同一个库记录还在且删掉的不回来；
  - 内存仓库——语义与 SQL 版对齐、`limit` 与自身上限取小、删与清空；
  - Store——`load()` 读回、写穿后重开读得回、大小写判重、trim 与空词丢弃、
    最多 10 个（最先搜的被挤掉）、删与清空、`notifyListeners` 次数（1 → 1 → 4）、无仓储纯内存可用；
  - 版本迁移——v2 老库升 v3 补表且 `posts` / `app_settings` / `user_account` 内容不动，
    v1 老库一路补到 v3；`sqlite_storage_test.dart` 的迁移用例改为升到「当前版本」并断言新表真的能用；
  - 界面——无历史不摆区块、按最近在前、点 chip 填词并搜出结果、键盘搜索键才算一次
    （打字不算）、点示例词也算、小叉只删一条、清空取消不动、清空确认后区块消失、
    记录落进仓库、出结果后区块收起。
- **未做**：真机上「重启应用后最近搜索还在」需要用户手动确认（测试用的是内存库 / 临时库）。
