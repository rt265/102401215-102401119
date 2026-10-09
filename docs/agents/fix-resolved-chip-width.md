# 修复：「我的发布」已完成状态块在窄屏被折行

用户反馈（本轮原话）：

> 卡片点击标记按钮后显示的“已找到 · 3 小时前”在宽度较小时被折叠。我希望删除“ · 3 小时前”这一部分

对应上一轮 [fix-my-post-status.md](./fix-my-post-status.md) 里 `_StatusChip` 的收尾遗留：
那次把状态做成了「对勾 + 文字」的小块，文字用 `Flexible` + `overflow: ellipsis` 兜底，
但**文案本身太长**——窄屏上一行要同时装下状态块、`改回进行中` 按钮和两个 `IconButton`，
「已找到 · 3 小时前」第一个被挤掉（省略号或换行），用户看到的信息反而残缺。

## 结论

状态块只需要说明「这条信息已经完成」，**时间不是它的职责**：

- 卡片本体（`PostCard`）右上角本来就有发布时刻，重复一次没有新信息；
- 状态一旦标记就固定不动，跟着 `createdAt` 走的相对时间在「我的」列表里只制造噪声；
- 去掉后状态块只剩 `已找到` / `已归还` 三个字，窄屏不再被压缩。

## 改动内容

### `lib/widgets/my_post_card.dart`

1. **文案去掉时间**：`label` 由 `'$_resolveLabel · ${formatRelativeTime(post.createdAt)}'`
   改成 `_resolveLabel`（即 `PostType.resolvedLabel`，失物 → 「已找到」、招领 → 「已归还」）。
2. **删掉 `import '../utils/time_format.dart';`**：该文件里 `formatRelativeTime` 已无其它用处
   （卡片时刻仍由 `PostCard` 自己格式化）。留着会触发 `unused_import`。
3. **给状态块加 Key**：`_StatusChip` 构造加 `super.key`，
   调用处传 `Key('profile-status-<id>')`。文案变短后「已找到」在卡片里**不再是唯一文本**
   （`PostCard` 已完成时的 `_StatusBadge(text: post.type.resolvedLabel)` 也是「已找到」），
   测试再按文字找就会命中两个 `Text`；用 Key 定位状态块，断言才稳。
4. `_StatusChip` 里的 `Flexible` + `overflow: ellipsis` **保留**：它本来是防溢出的兜底，
   现在虽然用不上，但状态块仍处在 `Expanded` 里，留着不亏。

### `test/profile_page_test.dart`

「标记完成后状态与图标按钮在同一水平线上」一条的旧断言用
`inCard(find.textContaining('已找到 · '))`，文案里没有时间后必然落空。改为
`inCard(find.descendant(of: find.byKey(Key('profile-status-local-1')), matching: find.text('已找到')))`——
**先按 Key 圈定状态块，再在块内找文字**，与上面的 Key 改动配套。

## 文件清单

```
lib/
  widgets/my_post_card.dart       状态文案去掉时间、删掉 time_format 导入、_StatusChip 加 Key
test/
  profile_page_test.dart          1 处断言改为按 Key 定位状态块内的文字
```

## 验证

```
flutter analyze       → No issues found! (ran in 1.1s)
flutter test          → 00:07 +118: All tests passed!
```

## 尚未做 / 可以再议

- 若日后确实想在「我的」里看到完成时刻，应加**独立字段**（如 `resolvedAt`）而不是复用
  `createdAt`——现在显示的那个时间是「发布时间」，语义上本来就不是「找到的时间」。
- 状态块在极窄屏（如 320dp）下仍可能与右侧按钮争宽，未单独做窄屏快照验证。
