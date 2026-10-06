# UI 事项 2：发布界面

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 2 项「构建发布界面」，
需求原文见「Release Post」。

## 本轮目标

- 完成发布界面：用表单填写失物 / 招领信息（信息类型、物品名称、物品分类、地点、时间、描述、联系方式、图片）。
- 填写不合规时逐项给出提醒，**不发布**。
- 发布成功后**显式弹窗**提醒，并能直接回到首页看到刚发布的信息。
- 让「发布 → 浏览」在本轮就形成闭环：新建一个内存信息仓库，发布界面写入、首页读取
  （SQLite 仍未接入，但界面层的数据来源不再是写死的示例数据）。
- 明确本轮**不做**的事：不建数据库、不实现图片选择、不做编辑 / 删除。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 发布界面 `PublishPage` | 表单项：信息类型（分段按钮）、物品名称、物品分类（8 个 chip）、地点、时间、描述、联系方式、图片（占位）；底部「发布信息」按钮，AppBar 上「清空」 |
| 表单校验 | 6 个必填项逐项提醒；首次提交失败后切到「边填边校验」，并把视口滚回顶部 |
| 发布成功弹窗 | `AlertDialog`：标题「发布成功」，正文复述物品名称，按钮「去首页看看」/「知道了」 |
| 信息仓库 `PostStore` | `ChangeNotifier` 内存仓库：`posts`（只读）+ `addPost()`（头插 + 通知） |
| 仓库下发 `PostScope` | `InheritedNotifier<PostStore>`，`PostScope.of(context)` 取用并订阅变化 |
| 外壳联动 | `PublishPage(onGoHome:)` 由 `MainShell` 注入，弹窗按钮可直接切回首页标签 |
| 首页数据源改造 | `HomePage` 不再持有 `buildMockPosts()`，改为读 `PostScope.of(context).posts` |
| 时间选择 | `showDatePicker` + `showTimePicker`，日期上限为今天，validator 再挡一次「晚于当下」 |
| 图片（选填） | 说明性占位（`TODO(image)`），不放点了没反应的假按钮 |

## 文件清单

```
lib/
  data/post_store.dart       PostStore（UI 阶段的内存信息仓库）+ PostScope（InheritedNotifier）
  main.dart                  根组件改为 StatefulWidget：创建 PostStore 并用 PostScope 包住 MaterialApp
  pages/main_shell.dart      发布界面接入 onGoHome（发布成功后切回首页）
  pages/home_page.dart       列表数据改从 PostScope 读取，_visiblePosts 改为带参数的方法
  pages/publish_page.dart    发布界面（本轮主体）
test/
  publish_page_test.dart     发布界面 6 个 widget 测试（表单渲染、校验、发布、跳首页、清空）
```

## 设计要点

- **先补一条数据通路**：需求要求「发布成功的产物」可见，而 SQLite 还没接入。
  于是加一个 `PostStore`（`ChangeNotifier`）+ `PostScope`（`InheritedNotifier`），
  发布界面写入、首页读取。用 Flutter 自带的 `InheritedNotifier` 而不是引入第三方状态管理，
  依赖它的首页会在 `addPost()` 后自动重建。将来换 SQLite 时只替换 `PostStore` 的实现
  （`TODO(storage)`：改为 `ItemRepository`），界面层用法不变。
- **表单用 `Form` + `SingleChildScrollView` + `Column`，刻意不用 `ListView`**：
  字段总共十来项，不需要懒加载；副作用是**屏幕外的表单项也始终存在于 widget 树里**，
  测试可以直接 `find` 到它们，只需在点击前 `ensureVisible`。
- **类型与时间也是 `FormField`**：`FormField<PostType>` 包住 `SegmentedButton`、
  `FormField<DateTime>` 包住时间选择行，这样它们和文本框一样参与 `Form.validate()` 与 `Form.reset()`，
  不会出现「文本框有提醒、选择项没有」的两套逻辑。
- **校验策略**：`Form.validate()` 不通过就只显示提醒、不发布，并把视口滚回顶部让第一条提醒可见；
  `_autovalidateMode` 从 `disabled` 切到 `onUserInteraction`，提醒过一次之后边填边校验。
  空表单直接提交会同时出现 6 条提醒（信息类型 / 物品名称 / 物品分类 / 地点 / 时间 / 联系方式）。
- **时间有上限**：`showDatePicker(lastDate: now)` 挡住未来日期，validator 再用
  `value.isAfter(DateTime.now())` 兜一次（今天 + 未来时刻）。
- **成功流程**：`form.save()` → 组装 `ItemPost`（`id` 为 `local-<microsecondsSinceEpoch>`）→
  `PostScope.of(context).addPost(post)` → `_reset()` → 弹窗。先清空再弹窗，正文里保留刚提交的物品名称，
  弹完就能接着发下一条。
- **没有额外加 SnackBar**：红色字段提醒 + 滚动回顶部已经足够说明「填写不合规」，
  不再叠一层转瞬即逝的提示。
- **选择器是英文的**：项目还没接入 `flutter_localizations`，`showDatePicker` / `showTimePicker`
  的按钮是 `OK` / `Cancel`，测试里按 `find.text('OK')` 点击并在注释里写明原因（中文化归 UI 事项 7）。

## 尚未实现 / 留给后续事项

- 图片（选填）未实现：`TODO(image)`，需要先有本地存储与图片目录，届时再做选图、缩略图与删除。
- 数据只在内存里，**重启应用即丢**；SQLite 与仓储层未接入（`TODO(storage)`）。
- 发布后不能修改或删除，状态也不能标记「已找到 / 已归还」（属 UI 事项 3「我的」与事项 6「编辑」）。
- 没有重复发布检测、草稿保存、发布频率限制。
- 表单只做必填校验，没有格式 / 长度校验（如手机号、微信格式）。
- 系统级控件仍为英文（UI 事项 7 一并中文化）。
- 首页的列表仍不支持下拉刷新（要等真实存储接入）。

## 验证

```bash
dart analyze .        # 等价于 flutter analyze 的静态检查，且不必启动 flutter 工具
flutter test
```

**最近一次验证结果（本轮）**：`dart analyze .` → `No issues found!`；
`flutter test` → `00:03 +12: All tests passed!`（每个测试文件 6 个，共 12 个）。

注意：这两个命令在受限沙箱下会因无法启动分析器 / 测试子进程而失败
（`CreateFile failed 5 ... 拒绝访问`），需在放宽权限下运行或由用户手动执行，详见 basic-info.md 的环境备忘。

新增的 `test/publish_page_test.dart` 覆盖：

1. 发布界面列出全部 8 个表单项、8 个分类选项与发布 / 清空按钮；
2. 空表单提交时 6 条提醒逐项出现，且不弹出成功弹窗；
3. 只填物品名称仍然被拦下（已填项的提醒消失，其余仍在）；
4. 填完整（含系统日期 / 时间选择器）后发布成功并弹窗，关闭后表单已清空；
5. 发布成功后从弹窗点「去首页看看」回到首页，新信息出现在列表最前，字段值正确带入；
6. 「清空」按钮同时清掉已填内容与已出现的提醒。

上一轮的 `test/widget_test.dart`（6 个首页测试）在首页数据源改造后仍然全部通过。
