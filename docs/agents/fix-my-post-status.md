# 修复：「我的发布」卡片的状态显示与状态回退

用户反馈（本轮原话）：

> “我的”发布中，“已找到/归还”点击后的文字和图标中心不水平；用户不知道如何将状态再改回“进行中”

对应 `docs/agents/basic-info.md` 中「Manage」一节：标记完成后应当**仍然可以改回来**
（原文：「允许发布者修改发布内容」，标记是修改的一部分，写错了就得能退）。

## 两个问题的成因

| 现象 | 成因 |
| --- | --- |
| 状态文字与图标按钮中心不水平 | 操作行用的是 `Wrap(alignment: WrapAlignment.end)`，已完成分支只放了一行**裸 `Text`**（`Padding` + `labelMedium`），和右边的 `IconButton`（修改 / 删除）各按自己的基线摆放，中心自然对不上。 |
| 不知道怎样改回「进行中」 | 已完成分支把「标记」按钮整个换成了那行文字，**界面上再没有任何回退入口**——尽管确认弹窗当时还写着「你仍然可以改回来或删除它」。 |

## 改动内容

### `lib/widgets/my_post_card.dart`

1. **操作行由 `Wrap` 改成 `Row`**（`children`：状态块 → `Spacer()`/`Expanded` 占据余量 → 按钮）。
   `Wrap` 适合「装不下就换行」的标签流，这里其实只有固定几件东西，排成一行即可，
   也让三者共享 `Row` 的默认 `crossAxisAlignment: center`——这正是「水平对齐」的由来。
2. **新增私有组件 `_StatusChip`**：`Row(mainAxisSize: min, crossAxisAlignment: center)`，
   `Icon(Icons.task_alt_rounded, size: 18)` + `SizedBox(width: 8)` + `Text(label, overflow: ellipsis)`。
   用图标 + 文字的小块代替裸文字，**和同一排的图标按钮在视觉上成为同类元素**，
   尺寸上也就对齐了（图标 18 与按钮图标同规格）。文字用 `Flexible` 包住，窄屏不溢出。
3. **新增「改回进行中」入口**：已完成时给 `TextButton.icon(key: Key('profile-revert-<id>'), icon: Icons.undo_rounded, label: '改回进行中')`。
   未完成时仍是原来的 `profile-resolve-<id>`「标记已找到 / 已归还」。两者互斥，永远只出现一个。
4. **新增 `Future<void> _revert(BuildContext context)`**：与 `_resolve` 对称——先弹确认框
   （Key `profile-revert-dialog`，标题「改回「进行中」？」），确认后
   `store.updatePost(post.copyWith(status: PostStatus.pending))` 并弹 SnackBar「已改回「进行中」」。
5. 文案 `_statusHint` 抽成常量，标记与改回共用：「标成已完成的信息在首页会显示为已完成，随时可以改回来。」
   `_pendingLabel` 用 `static final`（**不能是 `const`**：`PostStatus.pending.label` 不是常量表达式，
   写 `static const` 会报 `const_eval_property_access`）。

状态本身依旧只存在 `ItemPost.status` 一处，首页卡片、详情页、「我的」都读同一个字段，
所以改回之后三处一起变，不需要各自同步。

## 文件清单

```
lib/
  widgets/my_post_card.dart       操作行改 Row、新增 _StatusChip 与「改回进行中」
test/
  profile_page_test.dart          新增 2 个用例；1 处旧断言随表单提示文案改动更新
```

## 新增的测试

- **`标记完成后状态与图标按钮在同一水平线上`**：用 `tester.getCenter()` 取
  「修改」按钮里的图标、状态块的对勾、状态文字三者的 `dy`，断言两两相差 ≤ 1.0。
  **断言全部收进 `find.byKey(Key('profile-post-local-1'))` 之内**——
  页面上方的统计卡也有图标，不收进去会误伤。
  （这类「看着不齐」的问题本来是视觉问题，用坐标断言把它变成了能回归的测试。）
- **`标记后可以改回进行中`**：已完成的卡片上能看到「改回进行中」；
  点开确认框后**先取消**，断言状态仍是 `resolved`；
  再点一次并确认，断言仓库里回到 `pending`，且「标记已找到」按钮回来了。

## 顺带修的（不属于本次反馈）

`lib/widgets/post_form.dart` 里表单提示文案被改成「带 * 的为必填项。」（原文更长），
`test/profile_page_test.dart` 中「从『我的』界面可以直接去发布」一条仍在断言旧文案，
于是全量测试有 1 条失败。已把该断言改为新文案——
**断言文案时要按界面认控件（`publish-submit-button` 这类 Key），文案断言只留给必要的提示语**。

## 验证

```
dart analyze .        → No issues found!
flutter test          → 00:04 +52: All tests passed!
```

（52 = 首页 6 + 发布 6 + 我的 15 + 详情 12 + 搜索 13。）

测试环境注意：`flutter analyze` / `flutter test` 在受限沙箱下必定失败（`拒绝访问 (process_win.cc:744)`），
需在放宽权限下运行，详见 `docs/agents/basic-info.md` 的「环境备忘」。

## 尚未做 / 可以再议

- 状态回退只支持「已完成 → 进行中」；**没有**引入第三种状态（如「已过期」）。
- 详情页仍是只读的，标记与改回都只在「我的」——同一条信息不留两套管理入口，这是 UI 事项 4 定下的设计。
- 真机观感（对勾与文字的视觉重心）未目视确认，可 `flutter run` 复核。
