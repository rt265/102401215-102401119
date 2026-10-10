# 修复 PR #3（UI 8 + UI 10）合并后不通过的测试（2026-10-10）

## 背景

用户合并了 PR #3（`Lqh5/main`，标题「UI8 and UI10」）。这个 PR 主体是 UI 事项 10
响应式设计的纯重排（把各页正文包进 `MaxWidthBody`，`post_form.dart` / `appearance_page.dart`
等文件几百行 diff 其实只是缩进变化），但**顺带夹带了 UI 事项 8 的 `flutter_localizations` 接入**，
而后者改变了 widget 测试能看到的系统控件文案。PR 的 `basic-info.md` 已把 UI 8 标为
「待本机 `flutter analyze` / `flutter test` 验证」，实际两样都没过。

本轮只做一件事：把合并后的工程恢复到 `flutter analyze` 干净 + `flutter test` 全绿。

## PR #3 留下的三个问题

| 问题 | 表现 | 根因 |
| --- | --- | --- |
| 1. `unused_import` | `flutter analyze` 报 1 issue：`lib/theme/app_layout.dart:1:8` | `app_layout.dart` 里 `package:flutter/widgets.dart` 只被文档注释 `[MaxWidthBody]` 引用，dartdoc 引用**不算使用** |
| 2. 4 个 widget 测试失败 | 两个测试文件断言系统选择器里的英文 `OK` 按钮 | PR 加了 `localizationsDelegates` + `locale: Locale('zh')`，系统控件（日期 / 时间选择器）的确认键由 `OK` 变成「确定」；测试没跟着改 |
| 3. `pubspec.lock` 未随 PR 提交 | 工作区多出 `flutter_localizations` / `intl` 两处 lock 变更 | `pubspec.yaml` 加了 `flutter_localizations`，但 PR 忘了提交 lock 文件 |

失败的 4 条用例（同因）：

- `test/publish_page_test.dart`：填写完整后发布成功并弹窗，表单随后清空
- `test/publish_page_test.dart`：发布成功后可从弹窗回到首页并看到新信息
- `test/publish_page_test.dart`：清空按钮清掉已填内容、已选选项与提醒
- `test/profile_page_test.dart`：发布的信息会出现在「我的发布」并计入统计

报错原文：

```
Expected: at least one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "OK": []>
   Which: means none were found but some were expected
未本地化的系统选择器应显示英文 OK 按钮
```

## 改动

| 文件 | 改动 |
| --- | --- |
| `lib/theme/app_layout.dart` | 删掉 `package:flutter/widgets.dart` 的 import（并写进注释说明为什么不能再加回来） |
| `test/publish_page_test.dart` | `confirmPicker()` 由 `find.text('OK')` 改为 `find.text('确定')`，注释与 `reason` 同步改成「已本地化」 |
| `test/profile_page_test.dart` | 「发布的信息会出现在『我的发布』并计入统计」里的两次 `find.text('OK')` 改成 `'确定'`，注释同步 |
| `test/post_form_photo_test.dart` | 只改注释 / `reason`：**这里仍保留英文 `OK` 是对的**，因为 `pumpForm` 用的是裸 `MaterialApp`（没挂 `localizationsDelegates`） |
| `pubspec.lock` | 补上 `flutter_localizations`（sdk）与 `intl 0.20.3`（transitive），另含 `image_picker_ios` 0.8.13+9 → +10 的既有漂移 |

### 判定：为什么改测试而不是回退本地化

系统控件中文化是 UI 事项 8 的**目标本身**（见 [ui-08-localization.md](./ui-08-localization.md)），
不是副作用；测试里的英文 `OK` 只是本地化尚未接入时的**现状记录**。所以正确处置是把测试
改成断言新契约（中文「确定」），而不是把 `localizationsDelegates` 撤掉。

### 两类测试环境的差异（本轮最值得记住的一点）

**同一个选择器，在两个测试文件里确认键不同，取决于宿主 `MaterialApp` 有没有挂委托**：

- 走真实壳 `LostAndFoundApp` 的测试（`publish_page_test.dart`、`profile_page_test.dart`、
  `widget_test.dart` 等）：`MaterialApp` 里有 `localizationsDelegates` + 固定 `zh`，
  系统控件是中文 → `find.text('确定')`。
- 自己造 `MaterialApp` 的单元测试（`post_form_photo_test.dart` 的 `pumpForm`、
  `test/helpers/page_harness.dart` 的脚手架）：没挂委托，系统控件退回 Flutter 默认英文
  → `find.text('OK')` 依然正确。

以后再加「系统控件文案」相关的断言，先看这个测试是怎么起 `MaterialApp` 的。

## 验证

- `flutter analyze` → `No issues found! (ran in 2.3s)`
- `flutter test` → `00:07 +140: All tests passed!`

## 给后继 Agent 的提示

- 本机跑校验必须在**放宽权限**下一次性跑完 `flutter analyze` + `flutter test`
  （原因见 [basic-info.md](./basic-info.md) 的「环境备忘」）。
- PR #3 的重排风格（把 `Column` 的 children 整体再缩进一层）与仓库其他文件一致，
  没有遗留格式问题；**不要**顺手 `dart format lib test`。
- `MaxWidthBody` 目前包在：首页正文、发布 / 编辑表单、详情页、三个设置子界面。
  改动这些页面 `build()` 的顶层结构时，注意别把它顶掉——它只管宽度，不参与业务。
