# UI 事项 7：应用设置界面

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 7 项
「构建应用设置界面（外观、账户、应用信息）」，属于「次级界面」，
入口按「UI」一节挂在**我的**界面下（右上角齿轮）。

## 本轮目标

前六项都是围绕「发一条信息、找到它、管好它」的主链路，本轮补的是**主链路之外的那点事**：
用户想换主题、想改自己登记的联系方式、想知道数据存在哪、想看开源许可，之前都无处可去。

范围经用户确认（选项「标准实现」）：

- **外观**：主题模式（跟随系统 / 浅色 / 深色），选完立刻生效，**并写进本地 SQLite**，重启仍在。
- **账户**：查看本机账户、修改资料（未登记时就是登记）、退出登录。
- **应用信息**：应用名称、版本、数据存储说明、开源许可。
- **入口**：「我的」界面 AppBar 右上角的齿轮。

明确**不做**（用户没选，也超出本事项）：

- 不接 `flutter_localizations` 做中文化——那是另一件事，仍留在「尚未开始的技术工作」里
  （备注：`docs/agents/ui-01-home-page.md:68` 曾建议中文化「在应用设置界面一并处理」；
  本轮没做，因为用户选的范围不含它，且它会动到全仓所有页面的按钮文案与既有测试）。
  因此设置界面里那几个按钮（选择器等系统控件、`showLicensePage` 里的英文）仍是系统语言。
- 不做界面骨架式的「假设置」：外观必须真的落库、账户必须真的改 `UserStore`。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 外观分区 | `SegmentedButton<ThemeMode>` 三段（跟随系统 / 浅色 / 深色）+ 一句说明当前实际生效的是哪一边；改动即 `SettingsStore.setThemeMode()` |
| 主题持久化 | 新增键值表 `app_settings`（`DbSchema` 版本 1 → 2），主题存 `theme_mode` = `ThemeMode.name` |
| 账户分区 | 未登记 → 提示 + 「登记账户」；已登记 → 称呼 / 联系方式 / 登记时间 + 「修改资料」「退出登录」 |
| 账户表单 | 从「我的」界面抽出的共用组件 `AccountForm`，支持初值回填、标题 / 说明 / 按钮文案与 Key 前缀可配 |
| 应用信息分区 | 应用名称、版本、数据存储说明、本机条数统计 + 「开源许可」入口（`showLicensePage`） |
| 「我的」入口 | AppBar `actions` 里的齿轮（Key `profile-settings-button`）→ `SettingsPage` |
| 版本号来源 | `lib/app_info.dart` 里的常量（与 `pubspec.yaml` 手工同步），不引 `package_info_plus` |

## 文件清单

```
lib/
  app_info.dart                应用名称 / 版本常量（新增）
  data/db_schema.dart          版本 1→2，新增 app_settings 表与 createSettingsTable()（改写）
  data/app_database.dart       _upgrade 补 v1→v2 迁移（改写）
  data/settings_repository.dart 设置仓储接口 + SQLite 实现（新增）
  data/settings_store.dart     SettingNames / SettingsStore / SettingsScope（新增）
  pages/settings_page.dart     设置界面（新增，三个分区）
  pages/profile_page.dart      AppBar 加齿轮；登记表单换成 AccountForm（改写）
  widgets/account_form.dart    称呼 + 联系方式的共用表单（新增）
  main.dart                    建 SettingsStore、加 SettingsScope、MaterialApp 接 themeMode（改写）
test/
  settings_page_test.dart      设置界面 8 个 widget 测试（新增）
  sqlite_storage_test.dart     新增「设置」group 5 个用例（含 v1→v2 迁移）（改写）
  profile_page_test.dart       跟随 Key 改名（改写，4 处）
```

## 界面结构

`AppBar`：

- `leading`：显式 `IconButton`（Key `settings-back-button`，tooltip「返回」）——同 ui-04 / ui-05 / ui-06，
  项目还没接 `flutter_localizations`，系统 `BackButton` 的 tooltip 是英文，测试按文案找不到。
- `title`：「设置」。

正文是一个 `ListView`，三个分区（每个分区一句 `_SectionTitle` + 一张 `Card`）：

| 分区 | 卡片内容 |
| --- | --- |
| 外观 | 「主题模式」+ 说明「改完立刻生效，并记住这次选择。」+ 三段选择器 + 当前状态提示 |
| 账户 | 未登记：头像 + 一句提示 + 「登记账户」；已登记：称呼 / 联系方式 / 登记时间 + 「修改资料」「退出登录」；两张状态共用底部一句「账户信息只保存在本机，用于发布时自动带出联系方式。」；点任一个按钮原地展开表单 |
| 应用信息 | 应用名称 / 版本 / 数据存储 / 本机数据四行 + 分隔线 + 「开源许可」`ListTile` + 底部一段「本机应用」说明 |

外观分区的提示文案随模式变化（同一段 `Text`，内容不同）：

| 模式 | 提示 |
| --- | --- |
| 跟随系统 | 当前跟随系统设置，本机为浅色。／当前跟随系统设置，本机为深色。（按 `MediaQuery.platformBrightnessOf` 判） |
| 浅色 | 始终使用浅色主题。 |
| 深色 | 始终使用深色主题。 |

退出登录的确认弹窗（Key `settings-sign-out-dialog`）：

| 标题 | 正文 | 按钮 |
| --- | --- | --- |
| 退出登录？ | 只会清掉本机登记的账户信息，已发布的信息不受影响。 | 取消（`settings-dialog-cancel`）／退出（`settings-dialog-confirm`） |

这两句与「我的」界面上的退出弹窗**故意保持一字不差**——同一个动作在两处出现，
文案不一致会让人以为是两回事。

## Key 约定

| Key | 位置 |
| --- | --- |
| `profile-settings-button` | 「我的」AppBar 右上角齿轮（本事项新增的入口） |
| `settings-back-button` | 设置界面 AppBar 返回 |
| `settings-section-theme` / `settings-section-account` / `settings-section-about` | 三个分区标题 |
| `settings-theme-card` / `settings-account-card` / `settings-about-card` | 三张卡片 |
| `settings-theme-selector` | 主题模式选择器（`SegmentedButton`） |
| `settings-theme-hint` | 主题状态提示 |
| `settings-account-register` | 未登记时的「登记账户」 |
| `settings-account-name` / `settings-account-contact` / `settings-account-since` | 已登记时的称呼 / 联系方式 / 登记时间 |
| `settings-account-edit` / `settings-sign-out` | 「修改资料」/「退出登录」 |
| `settings-sign-out-dialog` | 退出确认弹窗 |
| `settings-dialog-cancel` / `settings-dialog-confirm` | 弹窗按钮 |
| `settings-version` / `settings-storage` / `settings-local-posts` | 版本 / 数据存储 / 本机条数 |
| `settings-licenses` | 「开源许可」 |
| `settings-account-name-field` / `-contact-field` / `-submit` / `-cancel` | 账户表单（`AccountForm` 的 `keyPrefix: 'settings-account'`） |

**Key 改名（会影响既有测试）**：「我的」界面上的登记表单换成 `AccountForm` 后，
两个按钮的 Key 跟着 `keyPrefix` 走：

| 旧 Key | 新 Key |
| --- | --- |
| `profile-register-submit` | `profile-submit` |
| `profile-register-cancel` | `profile-cancel` |

两个输入框的 Key（`profile-name-field` / `profile-contact-field`）没变，
`test/profile_page_test.dart` 里改用例名的 4 处（原 108 / 114 / 131 / 352 行）已同步。

## 设计要点

- **主题用 Flutter 自带的 `ThemeMode`，不另建一套枚举**：`ThemeMode` 就是「跟随系统 / 浅色 / 深色」，
  自建枚举只能多出一层映射，多一处对不上的机会；`MaterialApp.themeMode` 直接吃它。
- **设置存键值表，而不是「每项一列」**：`app_settings(setting_name PK, setting_value)` 一行一项，
  以后加设置项（字号、语言……）只写一行数据、不动表结构，也就不必再升版本。
  代价是值的类型得自己解析——`_parseThemeMode()` 认不出的值退回 `ThemeMode.system`，
  而不是崩溃或留空（库里可能留着旧版本写下的名字）。
- **`DbSchema` 版本升到 2，并补迁移**：老用户（已装 App）的库是版本 1，
  只有 `onUpgrade` 补一句 `if (from < 2) await DbSchema.createSettingsTable(db);` 才能继续用。
  迁移里**不能直接调 `DbSchema.create()`**：那是「首次建库」的全套 DDL，会把已存在的表再建一遍，
  且这些 DDL 都没有 `IF NOT EXISTS`，一跑就报错。
  `test/sqlite_storage_test.dart` 里为此写了一个「手工建版本 1 老库 → 用 `AppDatabase.open` 打开」
  的用例，DDL 是**冻结在测试里的字面量**（不调 `DbSchema.create`，否则建出来的就不是老库）。
- **`SettingsStore` 与 `PostStore` / `UserStore` 同一套路**：内存先改 + `notifyListeners()`，再写穿仓储；
  纯内存模式（`SettingsStore()`，无仓储）在测试与预览里照样能用。
  `load()` 在 `main()` 里 `await` 完再 `runApp()`，否则会先按默认主题画一帧再跳成用户选的那套。
- **换肤靠 `ListenableBuilder` 包 `MaterialApp`**：`SettingsScope` 只负责把 store 递下去，
  `themeMode` 得在 `MaterialApp` 上生效，所以在 `SettingsScope` 与 `MaterialApp` 之间插一层
  `ListenableBuilder(listenable: _settingsStore, ...)`；`SettingsPage` 自己不用 `setState` 也能立刻变色。
- **`SettingsScope` 放在 `PhotoScope` 外层、`UserScope` 内层**：设置页同时要读 `SettingsStore`、
  `UserStore`、`PostStore`（本机条数）与图片（无），次序只要都在 `MaterialApp` 之上即可。
- **账户的「登记」与「修改资料」是同一条路径**：都调 `UserStore.register()`，
  它内部保留 `_account?.createdAt ?? DateTime.now()`，所以改资料不会把「登记时间」刷成今天
  （测试里断言了这一点）。界面上只是标题 / 说明 / 按钮文案不同。
- **表单抽成 `AccountForm` 而不是复制一份**：「我的」界面上的登记表单与本页的账户表单字段、
  校验、文案完全一致，抄一份就会有两份「必填校验」的真相。
  共用组件用 `keyPrefix` 拼 Key（`ProfilePage` 传 `'profile'`、设置页传 `'settings-account'`），
  两处同时在栈上时 Key 也不撞车——这跟 `PostFilterBar` 的 `keyPrefix` 是同一个理由。
  `AccountForm` **不碰 `UserStore`**：写库、收起表单、弹提示都留给调用方，
  这样「我的」界面保持原样（点「完成注册」只登记，不弹提示），设置页才能多给一句「账户资料已保存」。
- **先取 `ScaffoldMessenger` 再 `await`**：`_saveAccount` / `_signOut` 都会 `await` 之后再弹 SnackBar，
  跨 `async` 用 `context` 会被 `use_build_context_synchronously` 拦下，也是真的会用到失效的 context。
- **「本机数据」那一行是活的**：直接读 `PostScope.of(context).posts`，
  所以删掉几条信息再进来，数字就会变——它顺带成了「库里确实只有这些」的一个凭据。
- **版本号写常量而不是运行时读**：`pubspec.yaml` 是 `1.0.0+1`，读它要引 `package_info_plus`
  （多一个依赖 + 平台通道 + 测试里要 fake），而本项目版本是发版时手改的，
  `lib/app_info.dart` 顶部注释写明「改 `pubspec.yaml` 时一并改这里」。
- **「开源许可」直接用 `showLicensePage`**：Flutter 自带 `LicenseRegistry` + `AboutDialog` 的现成页面，
  不必自己攒一份第三方许可列表（那份列表本来也由各包的 `LICENSE` 自动注册）。

## 尚未实现 / 留给后续事项

- **中文化仍未做**：`flutter_localizations` 没接，所以系统级控件（日期 / 时间选择器、`showLicensePage`、
  长按文本菜单）与系统 `BackButton` 的 tooltip 还是英文。设置界面是本该顺手处理它的地方，
  但本轮范围不含，见上文「本轮目标」。
- **没有「关于作者 / 反馈」入口**：需求只列了名称、版本、存储说明、开源许可。
- **浅色 / 深色只有一套种子色**：`AppTheme.light()` / `dark()` 早已定好，本事项只负责让用户选，
  没做「主题色可选」。
- **设置项只有主题一个**：键值表已经铺好，加项不必再升库版本。
- **账户仍无密码 / 无法注销（清空）账户**：需求「WARN」明确不要求实名认证与复杂后台管理，
  「退出登录」就是本机账户的全部生命周期操作。
- 图片（选填）在真机相册上仍未手动验证；数据都在本机，卸载即丢。

## 验证

```bash
flutter analyze
flutter test
```

**最近一次验证结果（本轮）**：

- `flutter analyze` → `No issues found! (ran in 1.0s)`
- `flutter test` → `00:06 +118: All tests passed!`
  （首页 6 + 发布 6 + 我的 15 + 详情 13 + 搜索 13 + 编辑 8 + 设置 8 共 69 个界面测试；
  另外 SQLite 24 + 照片存储 13 + 表单图片 12 共 49 个存储类测试）

注意：这两个命令在受限沙箱下会因无法启动分析器 / 测试子进程而失败
（`CreateFile failed 5 ... 拒绝访问。(process_win.cc:744)`），
需在放宽权限（danger-full-access）下运行或由用户手动执行，详见 basic-info.md 的环境备忘。

新增的 `test/settings_page_test.dart`（8 个）：宿主用 `PostScope` + `UserScope` + `SettingsScope` +
`MaterialApp(home: SettingsPage())` 包起来，仓储换成一个记账用的 `RecordingSettingsRepository`
（把写入的键值记在 `Map` 里，用来断言「真的落库了」），覆盖：

1. 三个分区齐全（外观 / 账户 / 应用信息三张卡与三个标题都在）；
2. 应用信息展示应用名称、版本（`1.0.0（1）`）、存储说明与「共 2 条信息 · 我的发布 1 条」的条数；
3. 主题提示三态（固定浅色 / 固定深色 / 跟随系统时说清本机是浅色还是深色）；
4. 从「我的」齿轮进设置、切深色后**立刻换肤并落库**（断言 `Theme.of(...).brightness == Brightness.dark`
   与 `repository.values['theme_mode'] == 'dark'`）；
5. 返回键能关掉设置界面；
6. 未登记账户时可以在这里登记，称呼与联系方式都必填（空提交拦下，填完收起表单并提示「账户资料已保存」）；
7. 已登记账户时可以修改资料，表单回填、**首次登记时间不变**、只改称呼时联系方式不丢；
8. 退出登录要先确认（先「取消」什么也不发生，再确认回到未登记状态并提示「已退出登录」）。

`test/sqlite_storage_test.dart` 新增 `group('设置')` 5 个用例：写入 / 读回 / 覆盖不攒重复行
（且各设置项互不干扰）、重开同一个库设置还在、`SettingsStore` 装载后读回库里的选择并立刻落库、
库里存着认不出来的主题名（`'neon'`）时退回「跟随系统」、
**版本 1 的老库升到版本 2 会补上设置表且老数据还在**（老库由测试里手工建出，塞一条 `buildBarePost()`，
再用 `AppDatabase.open` 打开；断言信息还在、账户仍是空、示例数据没有被补写、设置读写可用）。

既有 110 个测试在本轮改动后**全部保持通过**（`profile_page_test.dart` 的 4 处 Key 已改名）。

### 本轮踩到的坑

- **`// ignore:` 只作用到紧随的一行**：`SettingsStore` 的构造初始化列表写了两行
  （`_repository = repository,` 与 `_themeMode = themeMode;`），只给前者加
  `// ignore: prefer_initializing_formals` 时 `flutter analyze` 仍报
  `Use an initializing formal … - lib\data\settings_store.dart:30:5 - prefer_initializing_formals`。
  两行各加一条才干净（不改成 initializing formal 是因为这两个字段要能被 `??` 与默认值兜住）。
- **测试窗口太矮，`ListView` 不会把下面的分区建出来**：默认 800×600 下，
  「应用信息」那张卡根本没进 widget 树，`find.byKey(...)` 直接失败——不是代码错，是懒加载。
  测试里用 `tester.view.physicalSize = Size(1000, 2000)`（配 `devicePixelRatio = 1` 与
  `addTearDown(tester.view.reset)`）把窗口撑高；这个坑 ui-03 的「我的发布」长列表也踩过。
- **迁移用例不能借 `DbSchema.create` 建老库**：那样建出来的是「已经带设置表的新库」，
  迁移逻辑永远不会被执行，用例就变成了空转。老库的 DDL 必须冻结在测试里
  （哪怕以后 `DbSchema` 再改，这份 v1 的 DDL 也不该跟着变）。
- **`AccountForm` 的取消按钮要能没有**：设置页与「我的」都要「取消」，但共用组件不该假设调用方
  一定有取消动作，所以 `onCancel` 可空、为空时不渲染按钮——否则「没有取消的宿主」会画出个死按钮。
