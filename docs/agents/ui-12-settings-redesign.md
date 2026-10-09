# UI 事项 12：设置界面优化

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 12 项「设置界面优化」
（同文档「Setting」一节写着「应用信息：用户协议、关于（这两个放在**次级界面**）」）。
UI 事项 7 用一页三张卡把所有设置铺开了，本轮把它改成**目录页 + 三个子界面**。

> 说明：用户没有给「优化」的具体口径，本轮按「设置页只当目录，细节各自落在子界面」实现。
> 依据是 basic-info.md 那句「关于……放在次级界面」，以及事项 11 要给外观加一整块取色 UI——
> 继续堆在同一页会让设置页变成「什么都有、什么都放不下」。

## 本轮目标

| 问题（事项 7 留下的） | 本轮的处置 |
| --- | --- |
| 一页三段，越加越长：事项 11 的取色网格放进来会把它撑成一屏半 | 设置页只留**摘要 + 入口**，细节进子界面 |
| 账户表单与账户状态挤在设置页里，和「我的」界面上的账户卡重复 | 账户独立成 `AccountPage` |
| 「关于」按需求本该在次级界面，却挤在设置页底部 | 独立成 `AboutPage` |
| 外观只有一行选择器，看不到「换成这个颜色长什么样」 | 独立成 `AppearancePage`（事项 11 的主题色全在这里） |

## 交付内容

设置页现在是**目录页**：三个分区标题 + 三张入口卡 + 底部一行本机数据统计。

| 分区 | 设置页上显示 | 点进去 |
| --- | --- | --- |
| 外观 | 色点 + 「青绿 · 深色」摘要 + 紧凑样本预览 | `AppearancePage` |
| 账户 | 昵称（未登记则「登记账户」）+ 联系方式（未登记则一句引导） | `AccountPage` |
| 应用信息 | 一个「关于本应用」入口（标题 + 「版本、数据说明与用户协议」） | `AboutPage` |
| （底部） | 「共 N 条信息 · 我的发布 M 条」——**状态不是设置项，所以留在目录页** | —— |

子界面各自带「中文 tooltip 的返回键」（项目仍未接 `flutter_localizations`，系统 `BackButton` 的 tooltip 是英文）。

## 文件清单

```
lib/
  pages/settings_page.dart    整体重写：目录页；顶层公开 SectionTitle / InfoRow 供子界面复用
  pages/appearance_page.dart  外观界面（新增，见 ui-11）
  pages/account_page.dart     账户界面（新增）
  pages/about_page.dart       关于界面（新增）
test/
  settings_page_test.dart     重写：目录页 9 个用例
  account_page_test.dart      账户界面 7 个用例（新增）
  about_page_test.dart        关于界面 4 个用例（新增）
  appearance_page_test.dart   外观界面 7 个用例（新增，见 ui-11）
  helpers/page_harness.dart   四个界面共用的脚手架（新增）
  sqlite_storage_test.dart    「设置」group 补 3 个种子色用例（见 ui-11）
```

## Key 约定

设置页（目录）：

| Key | 位置 |
| --- | --- |
| `settings-back-button` | AppBar 返回 |
| `settings-section-theme` / `-account` / `-about` | 三个分区标题 |
| `settings-theme-card` | 外观摘要卡 |
| `settings-theme-preview` | 外观摘要卡上的 `InkWell`（整卡可点） |
| `settings-theme-hint` | 「青绿 · 深色」这行摘要 |
| `settings-account-entry-card` / `settings-account-tile` / `settings-account-summary` | 账户入口卡 / 那一行 / 副标题 |
| `settings-about-card` / `settings-about-tile` | 应用信息入口卡 / 「关于本应用」那一行 |
| `settings-local-posts` | 底部本机数据统计 |

账户界面 `account-*`：`account-back-button` / `account-card` / `account-register` /
`account-name` / `account-contact` / `account-since` / `account-edit` / `account-sign-out` /
`account-sign-out-dialog` / `account-dialog-cancel` / `account-dialog-confirm`，
表单的 `keyPrefix: 'account'` → `account-name-field` / `account-contact-field` / `account-submit` / `account-cancel`。

关于界面 `about-*`：`about-back-button` / `about-card` / `about-version` / `about-storage` / `about-licenses`。

外观界面 `appearance-*`：见 [ui-11-theme-color.md](./ui-11-theme-color.md)。

### Key 改名（事项 7 → 事项 12）

| 旧 Key（事项 7） | 新 Key（事项 12） |
| --- | --- |
| `settings-theme-selector` | `appearance-theme-selector`（搬进外观界面） |
| `settings-account-card` | `account-card` |
| `settings-account-register` | `account-register` |
| `settings-account-name` / `-contact` / `-since` | `account-name` / `account-contact` / `account-since` |
| `settings-account-edit` / `settings-sign-out` | `account-edit` / `account-sign-out` |
| `settings-sign-out-dialog` | `account-sign-out-dialog` |
| `settings-dialog-cancel` / `-confirm` | `account-dialog-cancel` / `account-dialog-confirm` |
| `settings-account-name-field` / `-contact-field` / `-submit` / `-cancel` | `account-name-field` / `account-contact-field` / `account-submit` / `account-cancel` |
| `settings-version` | `about-version`（后续调整后又**从设置页删掉**了这条，见下） |
| `settings-licenses` | `about-licenses`（现指「用户协议与开源许可」） |
| `settings-storage` | `about-storage`（设置页上那条「数据存储」后来一并去掉了，没有留 Key） |

保留原名的：`settings-theme-card`（现为摘要卡）、`settings-theme-preview`（新增）、
`settings-theme-hint`（现为「色名 · 模式」摘要）、`settings-section-*`、
`settings-about-card` / `settings-about-tile` / `settings-local-posts` / `settings-back-button`。

`lib/pages/profile_page.dart` **没有改动**：齿轮入口与「我的」上的账户卡原样保留
（同一个「账户」在两处出现是既有的产品决定，本轮不合并）。

## 设计要点

- **设置页只当目录，不当表单**：一页里既有入口又有一整块表单时，用户很难说清「我现在在设置什么」。
  摘要卡上的信息（色名 + 模式、昵称 + 联系方式）本身就够回答「当前是什么」，要点进去才改。
- **`SettingsPage` 从 `StatefulWidget` 降成 `StatelessWidget`**：它不再持有任何本地状态，
  读的是 `SettingsScope` / `UserScope` / `PostScope` 的内存快照。
- **`SectionTitle` / `InfoRow` 提到 `settings_page.dart` 顶层公开**，子界面
  `import 'settings_page.dart' show InfoRow, SectionTitle;` 复用。
  理由：这三个界面视觉上就是「同一个设置页的分部」，样式必须一致；
  为它们单开一个 `widgets/` 文件也行，但会更难看出「它们同属设置」。
- **「本机数据」那一行留在目录页**：它是**状态**不是设置项，
  点进「关于」能看到更详细的版本，但首页目录上有个总数是最省事的概览。
  这一条也划出了「应用信息」那张卡的界线：**状态可以留在目录页，静态的分条信息不行**——
  后者在「关于」里已经有一份，再列一遍就是纯重复（见上方「后续调整」）。
- **账户的展示态 / 表单态在同一个界面里切换**（`_formOpen`），不另开路由：
  登记与修改资料本来就是同一张表单（`AccountForm`），再拆一层只会多一次返回。
- **先取 `ScaffoldMessengerState` 再 `await`**：`_save` / `_signOut` 都在 `await` 之后弹 SnackBar，
  跨 `async` 用 `context` 会被 `use_build_context_synchronously` 拦下，也是真的会拿到失效的 context
  （与 ui-07 的 `_saveAccount` / `_signOut` 同一个坑）。
- **「用户协议」直接复用 Flutter 自带的开源许可页**：单机应用没有服务端、没有账号体系，
  没有需要用户单独同意的服务条款，真正约束双方的就是所用开源组件许可 + 关于页底部那句署名。
  与其编一份没人看的协议文本，不如把许可页给出来。
- **关于界面的入口用 `ListTile` 而不是按钮**：与设置页的入口卡同构，
  整行可点、右侧 chevron，一眼知道「这里能进去」。
- **许可页断言要看 `LicensePage` 类型**：`showLicensePage` 推入的是 Flutter 自带的 `LicensePage`，
  里面并没有「查看许可」这种文案；测试里 `find.byType(LicensePage)` 才是稳的
  （本轮一开始写了 `find.text('查看许可')`，直接失败）。
  它的 `legalese` 会把 `applicationLegalese` 画一遍，所以
  「Copyright (c) 2026 rt265, Lqh5」在树上有**两处**（关于页底部 + 许可页），
  断言要用 `findsWidgets` 而不是 `findsOneWidget`。

## 测试脚手架 `test/helpers/page_harness.dart`

四个设置相关界面（设置 / 外观 / 账户 / 关于）共用，内容：

- `RecordingSettingsRepository`：把写入的键值记在 `Map` 里，用来断言「真的落库了」；
- `buildSettingsHost({posts, users, settings, home, dark})`：四个仓库 + 按当前设置派生主题的 `MaterialApp`；
  **三个 Scope 都在 `MaterialApp` 外面**（和 `LostAndFoundApp` 一样）——放在 `home` 里面时，
  `Navigator.push` 出来的子界面挂在 Navigator / Overlay 之下，就找不到 `Scope` 了
  （会报「未找到 UserScope / PostScope」）；
- `buildPushHost(page)`：装一个「按钮 → push」的最小宿主，测返回键必须让界面真的在导航栈上；
- `useTallScreen` / `tapAt` / `pumpBriefly` / `typeInto` / `textAt` / `seedSwatchKey` / `presetSeedKey`。

### 本轮踩到的三个坑（写测试很值得看）

1. **`pumpAndSettle()` 会被「一直在转的进度圈」拖到超时**。
   外观界面的 `ThemeSample` 里有个 `CircularProgressIndicator`（展示配色里的主色），
   它按定义不会停，于是「有任何待调度帧」永远为真，`pumpAndSettle` 一路等到
   `pumpAndSettle timed out`。**这不是界面坏了**。
   处置：`pumpBriefly(tester)` = 手推 7 × 100ms 固定帧数。
   额外试过 `pumpFrames`，**不能用**：它会把传进去的 widget 当成新的根重新挂整棵树
   （`widget_tester.dart:739` 的 `binding.attachRootWidget(...)`），界面会被整个换掉；
   而且它的第一个参数类型是 `Widget`，传 `Finder` 连编译都过不去。
2. **点击要用「按下 → 停一帧 → 抬起」，不能用 `tester.tap()`**。
   带 tooltip 的返回键在 `tester.tap(finder)` / `tester.tapAt(坐标)` 下**收不到点击**
   （界面纹丝不动，也不报「点空了」）；换成
   `startGesture(getCenter(finder))` → `pump(50ms)` → `gesture.up()` 立刻就正常了。
   坐标还要在动画落定**之后**再算：页面刚推出来时 `getCenter` 量到的是过场动画中途的位置，
   差 4 像素就点空了（返回键因此一直「没反应」）。
3. **推帧时长要够一次过场动画**。一开始只推 400ms，弹出动画还没结束就断言
   `findsNothing`，于是「界面没关掉」；推到 700ms（`MaterialPageRoute` 约 300ms）才稳。
   同理，`tapAt` 里的 `pumpAndSettle` 也要换成 `pumpBriefly`——弹出动画期间界面上还有样本，
   一样会超时。

## 后续调整（本轮之后按用户反馈改的）

用户看过成果后提了两点，都已落地：

1. **「用户协议」就用开源许可页**，不另写协议文本。本应用没有后端与账号体系，
   没有需要用户单独同意的服务条款，真正约束双方的是所用开源许可以及关于页底部那句署名。
   所以「关于」界面第三段的标题是 `用户协议`，里面一个条目 `用户协议与开源许可`（Key 仍是
   `about-licenses`）指向 Flutter 自带 `LicensePage`。
2. **设置页「应用信息」不再重复关于界面的分条信息**。原来那张卡上有应用名称 / 版本 / 数据存储
   三行 `InfoRow`，而它们在「关于」里又出现一遍，属于纯重复。
   现在设置页只剩一个入口条目（`settings-about-tile`，标题「关于本应用」，
   副标题「版本、数据说明与用户协议」）。
   **`settings-version` 这个 Key 因此被删除**（`settings-storage` 本来就没单独建过 Key），
   测试改为直接断言「目录页上没有 `InfoRow`、没有版本号」。
   目录页只回答「有什么可以进去」，不回答「里面是什么」。
   → 见 `lib/pages/settings_page.dart` 的 `settings-about-card` 与
   `lib/pages/about_page.dart` 顶部注释。

---

## 尚未实现 / 留给后续事项

- 设置项仍只有主题模式 + 主题色两项；键值表已铺好，加项不必升库版本。
- 中文化仍未做（UI 事项 8），所以系统控件与系统返回键 tooltip 还是英文；
  本轮新增的三个子界面都自带中文 tooltip 的返回键。
- 响应式（UI 事项 10）未做，三个子界面沿用与设置页相同的 16px 边距，未针对宽屏分栏。

## 验证

```bash
flutter analyze
flutter test
```

**最近一次验证结果（本轮）**：

- `flutter analyze` → `No issues found! (ran in 1.0s)`
- `flutter test` → `00:07 +140: All tests passed!`

四个设置相关界面共 27 个用例（设置 9 + 外观 7 + 账户 7 + 关于 4），
其余既有用例在本轮改动后全部保持通过。

（`flutter analyze` / `flutter test` 在受限沙箱下会因无法启动分析器 / 测试子进程而失败，
需在 danger-full-access 下运行或由用户手动执行，详见 basic-info.md 的环境备忘。）
