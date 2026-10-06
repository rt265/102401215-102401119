# 修复：发布界面「清空」清不掉已选的信息类型 / 物品分类 / 时间

## 用户反馈（本轮原话）

> 发布界面的“清空”是如何实现的？

在解释实现（AppBar「清空」→ `PublishPage._reset()` → `PostFormState.reset()`）的过程中发现：
被清掉的只有文本，**三个选择项清不掉**。用户在确认成因后要求修复。

对应 `basic-info.md` 的「Release Post」一节：发布界面用表格填充失物 / 招领信息，
填充不合规要提醒，发布成功后显式弹窗提醒。

## 成因

「清空」的复位链路是 `PostFormState.reset()` → `FormState.reset()` → 逐个
`FormFieldState.reset()`，而 `FormFieldState.reset()` 的实现是
`setState(() { _value = widget.initialValue; _clearErrorInternal(); })`
（`packages/flutter/lib/src/widgets/form.dart:685-692`）。

| 现象 | 成因 |
| --- | --- |
| 选过「失物 / 电子产品 / 某个时刻」后按「清空」，分段按钮、分类 chip、时间行仍是选中态 | 三个选择器的 `FormField.initialValue` 绑的是**会被用户改动的** `_type / _category / _eventTime`，于是 reset 把「上一次的选择」原样复位回来 |
| 上一条发布成功后接着发下一条，新信息静默沿用上一条的类型 / 分类 / 时间 | 同上：`save()` 组装信息时读的就是这三个字段，它们从未回到初值 |
| 只在「选择之后又发生过一次重建」时才复现 | `_TypeSelector.onChanged` 只写 `_type`、不 `setState`，父 State 不重建时挂载的 `FormField.initialValue` 还是最初那份（新建表单时是 `null`），reset 反而清得掉；**提交失败**会 `setState(() => _autovalidateMode = onUserInteraction)` 触发重建，此后 `initialValue` 就变成用户当前的选择 |

文本框不受影响：带 `controller` 的 `TextFormField` 要求 `initialValue == null`，
reset 把文本复位成空串，正是「清空」想要的效果。

## 改动内容

### `lib/widgets/post_form.dart`

1. 三处选择器的 `initialValue` 改绑**不可变的原始初值**：
   `:300` `initialValue: widget.initial?.type`、
   `:318` `initialValue: widget.initial?.category`、
   `:336` `initialValue: widget.initial?.eventTime`。
   决策理由：reset 的语义是「回到打开表单时的样子」——新建时初值是 `null`（=清空），
   编辑时是刚打开时那条信息的值（=`PostEditPage` 将来要做「还原」时的正确行为）。
2. `reset()`（`:214-228`）在 `_formKey.currentState?.reset()` 之后补上同步：
   ```dart
   _formKey.currentState?.reset();
   setState(() {
     _type = widget.initial?.type;
     _category = widget.initial?.category;
     _eventTime = widget.initial?.eventTime;
     _autovalidateMode = AutovalidateMode.disabled;
   });
   _autoFilledContact = null;
   _syncAccountContact();
   ```
   决策理由：光复位 `FormField` 不够——`save()` 读的是这三个字段，它们留着重值
   就会让下一条被静默沿用。随后的 `_syncAccountContact()` 保持原行为：
   账户里登记过的联系方式会重新填上。
3. `:84-90` 的字段注释改写，写明「选择器的 `initialValue` 必须绑 `widget.initial?.xxx`，
   不要绑 `_type / _category / _eventTime`」以及原因，避免下次又被改回去。

`PostEditPage`（`lib/pages/post_edit_page.dart`）同样复用 `PostForm`，但从不调用
`reset()`，因此本次改动对编辑界面没有行为影响。

## 文件清单

```
lib/widgets/post_form.dart
test/publish_page_test.dart
```

## 新增的测试

本次没有新增用例，而是**把两条既有用例加强成真正能拦住这个 bug 的回归测试**
（`test/publish_page_test.dart`），并加了两个读数 helper：

```dart
SegmentedButton<PostType> typeSelector(WidgetTester tester) => ...
ChoiceChip categoryChip(WidgetTester tester, ItemCategory category) => ...
```

- **填写完整后发布成功并弹窗，表单随后清空**：填完表单后**抹掉联系方式再提交一次**
  （制造一次「提交失败 → 父 State 重建」），补回联系方式后正式发布，
  确认弹窗后断言：时间行回到 `选择丢失 / 拾取的时间`、`typeSelector(tester).selected` 为空、
  分类 chip 未选中。
- **清空按钮清掉已填内容、已选选项与提醒**：填标题 + 选「失物」+ 选「电子产品」+ 选时间，
  然后提交一次（失败 → 重建），再点「清空」，断言：文本没了、提醒没了、
  三个选择项都回到未选状态。

为什么要「先失败提交一次」：这正是 bug 的前提条件。第一版加强断言（不制造重建）在
**注入 bug 的情况下仍然 6 条全绿**（`flutter test test/publish_page_test.dart` →
`00:03 +6: All tests passed!`），因为不重建时 `initialValue` 还是最初那份 `null`。
断言必须先复现 bug 的前提，才能覆盖 bug。

## 验证

```
dart analyze .        → No issues found!
flutter test          → 00:05 +52: All tests passed!
```

（52 = 首页 6 + 发布 6 + 我的 15 + 详情 12 + 搜索 13，与 `fix-my-post-status.md` 记录一致。）

并做了**反向验证**，确认加强后的断言真的能拦住这个 bug：

```
# 把 lib/widgets/post_form.dart:300 改回 initialValue: _type,（重现 bug）
flutter test test/publish_page_test.dart
  → Expected: empty
    Actual: Set:[PostType:PostType.lost]
    00:04 +4 -2: Some tests failed.        # 两条用例失败
# 改回 initialValue: widget.initial?.type, 后
flutter test          → 00:05 +52: All tests passed!
```

## 测试环境注意

受限沙箱下 `flutter test` / `flutter analyze` 会以
`CreateFile failed 5 ... ProcessException: 拒绝访问。(process_win.cc:744)` 假死，
需在放宽权限下运行或由用户手动执行；详见 `basic-info.md` 的「环境备忘」。

## 尚未做 / 可以再议

- 图片字段仍是占位文案，接入本地存储时一并实现（见 `ui-02-publish-page.md`）。
- `PostFormState.reset()` 目前在账户联系方式为空时会把输入框清空，
  若希望「清空后仍保留手打的联系方式」可再议。
