# UI 事项 6：编辑界面

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 6 项「构建编辑界面」，
需求原文见「Manage」的第二条：**允许发布者修改发布内容。**

## 本轮目标

编辑链路的**骨架**在 UI 事项 3 就已经搭好了（`profile-edit-<id>` → `PostEditPage` → `PostForm` →
`PostStore.updatePost()` → 弹回「我的」并提示「已更新」，见 [ui-03-profile-page.md](./ui-03-profile-page.md)），
本轮做的是**打磨**——补上「用户改到一半」时缺的那几件事：

- 表单里给一个**「还原」**入口：改乱了好退回打开时的内容，不必退出重进。
- 有未保存改动时**返回先问一句**「放弃这次修改？」，避免白填一场（含系统返回键 / 返回手势）。
- 表单只读**共用的** `PostForm`，本轮给它补上「有没有改动」的能力（`isDirty` + `onChanged`），
  而不是在编辑界面里另抄一份字段比较。

范围经用户确认（选项「补齐编辑界面的打磨」）：不重做链接、不新增字段、不碰存储。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 「还原」入口 | `AppBar.actions` 里的 `TextButton`（Key `edit-restore-button`），先确认再 `reset()`；没有改动时置灰 |
| 返回确认 | `_cancel()`：有未保存改动才弹「放弃这次修改？」；确认按钮「放弃修改」、取消按钮「继续编辑」 |
| 系统返回拦截 | 整页包 `PopScope<ItemPost>(canPop: !_dirty)`，返回键 / 返回手势走同一条确认路径 |
| 表单改动检测 | `PostFormState.isDirty`（判「和打开时不一样」）+ `PostForm.onChanged` 回调，编辑界面据此刷新「还原」可用性与拦截状态 |
| 校验模式的复位 | `reset()` 复位后回到编辑态该有的自动校验（`AutovalidateMode.onUserInteraction`），不再一律关掉 |

## 文件清单

```
lib/
  pages/post_edit_page.dart    编辑界面（整篇重写：还原 / 返回确认 / PopScope）
  widgets/post_form.dart       共用表单：新增 isDirty、onChanged；reset() 复位校验模式并回调
test/
  post_edit_page_test.dart     编辑界面 8 个 widget 测试（新增）
```

## 界面结构

`AppBar`：

- `leading`：显式 `IconButton`（Key `edit-cancel-button`，tooltip「返回」）——同 ui-04 / ui-05，
  项目还没接 `flutter_localizations`，系统 `BackButton` 的 tooltip 是英文，测试按文案找不到。
- `title`：「修改信息」。
- `actions`：`TextButton`「还原」（Key `edit-restore-button`），**只在有改动时可点**。

正文仍是共用的 `PostForm`（`initial: widget.post`，提交按钮文案「保存修改」，顶部说明「保存后首页与
「我的」都会显示修改后的内容」）。两个确认弹窗共用一套按钮（Key `edit-dialog-cancel` / `edit-dialog-confirm`），
文案分别是：

| 弹窗 Key | 标题 | 正文 | 确认文案 |
| --- | --- | --- | --- |
| `edit-restore-dialog` | 还原为打开时的内容？ | “<物品名称>”还没保存的改动会丢掉；已保存的信息不受影响。 | 还原 |
| `edit-discard-dialog` | 放弃这次修改？ | “<物品名称>”的改动还没有保存，返回后不会保留。 | 放弃修改 |

两个弹窗的取消文案都是「继续编辑」——用户点这两个按钮的本意都是「先不退」，说清楚比「取消」好。

## Key 约定

| Key | 位置 |
| --- | --- |
| `edit-cancel-button` | AppBar 返回 |
| `edit-restore-button` | AppBar「还原」 |
| `edit-restore-dialog` / `edit-discard-dialog` | 两个确认弹窗 |
| `edit-dialog-cancel` / `edit-dialog-confirm` | 两个弹窗里的按钮（共用一套） |
| `publish-*` | 表单内部（沿用发布界面的前缀，`PostForm` 只写一份，见 basic-info 的「已铺好的公共基础」） |

## 设计要点

- **「还原」和发布界面的「清空」是同一个 `reset()`**：`FormFieldState.reset()` 的实现就是
  `_value = widget.initialValue`，所以「新建 = 清空、编辑 = 还原」本来就是同一个动作的两副面孔。
  这也意味着 `PostForm` 里三处选择器（类型 / 分类 / 时间）的 `FormField.initialValue` **必须绑不可变的
  `widget.initial?.xxx`**——绑 `_type` / `_category` / `_eventTime` 会「清不掉」，这个坑在
  [fix-post-form-reset.md](./fix-post-form-reset.md) 里已经记过，本轮直接沿用约束。
- **`reset()` 复位的是校验模式，不是校验值**：原来的 `reset()` 把 `_autovalidateMode` 一律设成
  `disabled`（那是对的：新建表单复位后是张白纸，不该一片红）。现在改成回到
  `_initialAutovalidateMode`——新建态仍是 `disabled`，编辑态是 `onUserInteraction`：
  还原后表单里还填着原始内容，不该立刻标红，但用户接着改时仍该边填边校验
  （原来编辑态一旦点过「还原」就永远不再自动校验了）。
- **改动判定在表单里，界面只读结果**：`isDirty` 比较 `_type` / `_category` / `_eventTime` 与
  四个文本框的 `text.trim()`；**联系方式额外特判**——「我的」界面登记过的账户联系方式会被自动带进
  空白表单（`_autoFilledContact`），那是系统填的、不是用户改的，不算改动。
  判定放在 `PostForm` 里，是为了让「什么算改动」只有一个定义；编辑界面只负责把
  `onChanged` 折成 `_dirty` 两个状态。
- **`onChanged` 是「表单说它变了」，不是「用户输入了」**：选择器、时间选择器、文本框与 `reset()`
  都会回调，编辑界面因此不需要认识表单内部的任何字段。回调里只比较
  `_formKey.currentState?.isDirty`，变了才 `setState`。
- **有改动时的返回用 `PopScope` 兜，而不是只用返回按钮**：用户习惯用系统返回键 / 返回手势，
  只拦 `leading` 等于没拦。查过 SDK（`flutter/lib/src/widgets/pop_scope.dart`）：`canPop: false`
  只拦系统返回，**`Navigator.pop()` 照样成功且回调里 `didPop == true`**，
  所以「保存」走的直接 pop 完全不受影响，`onPopInvokedWithResult` 里只处理被拦下的那一次。
- **返回不动数据**：表单只把 `widget.post` 当作初值读一遍（不共享可变状态），
  所以「放弃修改」就是纯粹地 `pop()`，仓库里的信息一直是原样——测试里也断言了这一点。
- **保存照旧「直接走」**：保存时表单已经通过校验，`updatePost()` 之后立即 `pop(updated)`，
  不会再多问一句；「我的」界面收到非空结果才提示「已更新」，取消返回（`null`）不提示。
- **没改动时「还原」置灰而不是隐藏**：按钮位置稳定，用户不会因为改了一行字就发现 AppBar 上
  多出个东西；置灰同时也在说「现在没什么可还原的」。

## 尚未实现 / 留给后续事项

- **保存前的「确认保存」没做**：需求只要求能改，改完直接落库更顺；真要防误触，该防的是删除。
- **没有「撤销」**：还原是一次性的，还原本身也弹确认，不做多级撤销（内存里的数据量不值得）。
- **不留编辑历史 / 不显示「上次修改于」**：`ItemPost` 没有 `updatedAt` 字段，加字段属于数据层的事。
- 应用设置界面（事项 7）未开工。
- 图片（选填）仍未实现；数据只在内存里，重启即丢（`TODO(storage)`、`TODO(image)`）。

## 验证

```bash
flutter analyze
flutter test
```

**最近一次验证结果（本轮）**：

- `flutter analyze` → `No issues found! (ran in 0.9s)`
- `flutter test` → `00:05 +60: All tests passed!`（首页 6 + 发布 6 + 我的 15 + 详情 12 + 搜索 13 + 编辑 8 共 60 个）

注意：这两个命令在受限沙箱下会因无法启动分析器 / 测试子进程而失败
（`CreateFile failed 5 ... 拒绝访问。(process_win.cc:744)`），
需在放宽权限（danger-full-access）下运行或由用户手动执行，详见 basic-info.md 的环境备忘。

新增的 `test/post_edit_page_test.dart` 用一个最小的「上一页」宿主复现推入 / 弹回
（真实入口是「我的」卡片上的「修改」），覆盖：

1. 打开编辑界面时回填原信息，没改动可以直接返回（「还原」置灰、返回不追问、弹回结果是 `null`）；
2. 改动后「还原」要先确认，选「继续编辑」则改动还在；
3. 确认「还原」后表单退回打开时的内容（文字与分类都回去、给「已还原」提示、仓库没被动过、改动标记收回）；
4. 有未保存的改动时返回先确认，选「继续编辑」就留在编辑界面且输入还在；
5. 确认「放弃修改」后才离开，`PostStore` 里的信息一字未改；
6. 系统返回键（`tester.binding.handlePopRoute()`）同样被拦下并确认；
7. 保存后更新仓库，并把改好的信息交回上一页（不弹「放弃修改？」）；
8. 只是多打了空格不算改动；改掉又改回原值也不算改动。

既有 52 个测试在本轮改动后**全部保持通过**（`PostForm` 的 `reset()` 语义变了、
四个文本框与三个选择器多了 `onChanged` 回调，发布界面与「我的」界面的用例都没受影响）。

### 本轮踩到的坑

- **`PostForm.onSaved` 是 required**：整篇重写编辑界面时漏传了它，`flutter analyze` 报
  `missing_required_argument`（外加 `unused_element: _onSaved`）——重写这类「套壳页面」时，
  壳子里的回调接线要照着原文件对一遍。
- **测试宿主不要暴露私有 State**：一开始用 `GlobalKey<_EditorHostState>` 把弹回结果读出来，
  `flutter analyze` 报 `library_private_types_in_public_api`（info 级）。
  改成宿主收一个 `ValueChanged<ItemPost?>` 回调，测试用局部变量接，既没有 lint 也不用 `setState`。
- **模拟系统返回用 `tester.binding.handlePopRoute()`**：`WidgetsBinding.handlePopRoute()`
  在 `D:\flutter\flutter\packages\flutter\lib\src\widgets\binding.dart:1113`（`@visibleForTesting`），
  最终走 `_WidgetsAppState.didPopRoute()`（`.../lib/src/widgets/app.dart:1607-1619`）里的
  `navigator.maybePop()`，于是真的会经过 `PopScope`——这比 `tester.pageBack()` 更贴近「按了系统返回键」。
