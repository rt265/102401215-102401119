# UI 事项 3：我的界面

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 3 项「构建我的界面」，
需求原文见「Manage」：**注册账户**，并对自己发布的内容提供**标记「已找到 / 已归还」、修改、删除**三项操作。

## 本轮目标

- 完成「我的」主界面：登记账户 + 管理自己发布的信息。
- 三项管理操作逐条落地：标记状态（含确认弹窗）、修改（复用发布表单，保存后回到「我的」）、删除（含确认弹窗）。
- 「发布 → 管理」形成闭环：用户**刚发布的信息立刻出现在「我的发布」里**，可以就地标记 / 修改 / 删除。
- 顺带把发布界面的表单抽成可复用组件，供事项 6「编辑界面」直接使用。
- 明确本轮**不做**的事：不建数据库、不做密码 / 实名、不实现图片、不改首页与搜索。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 我的界面 `ProfilePage` | `AppBar('我的')`；账户卡片 + 「我的发布」区块（统计 + 卡片列表）+ 底部「去发布一条」 |
| 账户卡片 `AccountCard` | 未登记：`注册` 按钮展开内联登记表单（称呼、常用联系方式，均必填）；已登记：显示称呼与联系方式 + 退出登录 |
| 信息卡片 `MyPostCard` | 复用首页 `PostCard` 展示内容，底部一排管理操作：`标记已找到 / 已归还`、修改、删除 |
| 统计 `_StatsRow` | 三格：全部发布 / 已完成 / 进行中 |
| 编辑界面 `PostEditPage` | 次级界面（事项 6 的主体，本轮先做出来供「修改」调用）：`AppBar('修改信息')` + 预填表单 + 「保存修改」。**后续打磨（「还原」、返回确认、系统返回拦截）见 [ui-06-post-edit-page.md](./ui-06-post-edit-page.md)** |
| 共用表单 `PostForm` | 从发布界面抽出的整张表单，发布与编辑共用；外部通过 `GlobalKey<PostFormState>` 调 `save()` / `reset()` |
| 账户仓库 `UserStore` / `UserScope` | `ChangeNotifier` 内存仓库 + `InheritedNotifier` 下发，供发布界面带出默认联系方式 |
| 仓库补全 `PostStore` | 新增 `updatePost()` 与 `removePost()`，与已有 `addPost()` 一起构成完整的增删改 |
| 模型补全 `ItemPost` | 新增 `isMine` 字段（标出「这是我发的」）与 `copyWith()` |
| 外壳联动 | `MainShell` 注入 `ProfilePage(onGoPublish:)`，「去发布一条」直接切到发布标签 |

## 文件清单

```
lib/
  data/user_store.dart         UserAccount / UserStore / UserScope（本机账户，新增）
  data/post_store.dart         新增 updatePost() 与 removePost()
  models/item_post.dart        新增 isMine 字段与 copyWith()
  widgets/post_form.dart       发布与编辑共用的整张表单（新抽出的主体）
  widgets/my_post_card.dart    「我的发布」里的卡片与三项管理操作（新增）
  pages/publish_page.dart      改薄：只留 AppBar、成功弹窗与流程，表单交给 PostForm
  pages/post_edit_page.dart    编辑界面（新增，事项 6 的主体）
  pages/profile_page.dart      我的界面（本轮主体）
  pages/main_shell.dart        注入 onGoPublish
  main.dart                    根组件多创建并下发一个 UserStore
test/
  profile_page_test.dart       我的界面 12 个 widget 测试
```

## 设计要点

- **「是不是我发的」用 `isMine` 标出来，而不是猜**：示例数据（`buildMockPosts()`）也是普通
  `ItemPost`，如果「我的发布」直接列出仓库全部内容，示例数据就会混进来，
  「修改 / 删除」也就失去归属。因此给 `ItemPost` 加了 `isMine`（默认 `false`），
  由 `PostForm.save()` 在新建时置 `true`。`TODO(storage)`：接入 SQLite 与账户表后，
  改为按发布者 id 判断。
- **表单只写一份**：发布与编辑填的是同一组字段、同一套校验，抽成 `PostForm` 后，
  发布界面变成「表单 + 成功弹窗」，编辑界面变成「表单 + 保存回退」。
  外部用 `PostForm.createKey()` 拿 `GlobalKey<PostFormState>`，调 `save()`（校验失败返回 `null`，
  调用方什么都不做）与 `reset()`。表单内部的 `Key` 一律沿用 `publish-` 前缀，
  这样上一轮的 `test/publish_page_test.dart` 无需改动仍然有效。
- **选择项也参与 `Form.reset()`**：编辑界面一进来就带初值，所以 `_autovalidateMode` 直接用
  `onUserInteraction`——清空某个必填项立刻能看到提醒，而不是等到点保存。
- **标记与删除都要先确认**：`标记已找到` 会改变首页展示，删除不可恢复，两者都用 `AlertDialog`
  确认（删除按钮用 `colorScheme.error` 配色）；`取消` 是纯 `TextButton`，确认是 `FilledButton`。
  退出登录同理——它只清本机账户，不动已发布的信息，弹窗里把这点写明。
- **文案跟着信息类型走**：标记按钮的文案取自 `PostType.resolvedLabel`
  （失物 → 「已找到」，招领 → 「已归还」），标记后按钮换成「已找到 · 3 小时前」这样的说明文字，
  不再重复提供入口。
- **账户带出默认联系方式**：`PostForm` 在 `didChangeDependencies()` 里同步账户里的联系方式
  （只填空字段，且不覆盖用户自己改过的内容）。发布界面挂在 `IndexedStack` 里，
  进应用时账户可能还没登记，等用户登记完切回来时这里会补上；`reset()` 后也会重新填上，
  同一个人接着发下一条时不必再手打一遍。`UserScope` 因此提供了宽松的 `maybeOf()`：
  账户只是锦上添花，页面不该因为它缺席就报错。
- **「注册」在无后端阶段就是本机登记**：《Basic Info》明确不要求实名认证，所以只存
  称呼与常用联系方式，不涉及密码。`UserStore.register()` 会保留首次登记时间。
- **编辑界面是「推」出去再「弹」回来的**：`MyPostCard` 里
  `await navigator.push<ItemPost>(PostEditPage(...))`，编辑界面保存时先 `updatePost()` 再
  `Navigator.pop(updated)`；取消则返回 `null`，调用方只做 SnackBar 提示，数据以仓库为准。
- **重用了 `ComingSoon` 做空态**：「还没有发布过信息」不是「界面没做」，但 `ComingSoon` 的
  图标 + 标题 + 说明的版式正好合适，避免了再写一个空态组件。
- **`test/profile_page_test.dart` 里直接装 `ProfilePage`**（只包 `PostScope` + `UserScope`），
  不经过三大主界面外壳，省掉切换标签的噪声；只有真正验证外壳联动的用例才用
  `LostAndFoundApp`。注意 `IndexedStack` 会把三个标签都挂在树上，
  断言时**按 Key 认控件，不要按文案认**（「发布信息」在导航栏和提交按钮上各有一个）。

## 尚未实现 / 留给后续事项

- 详细信息界面（事项 4）与搜索界面（事项 5）仍是 `ComingSoon` 占位；
  「我的发布」里点卡片不会跳转到详情页（`MyPostCard` 没传 `onTap`）。
- 应用设置界面（事项 7）未开工；系统级控件（日期 / 时间选择器）仍是英文。
- 图片（选填）未实现：`TODO(image)`。
- 数据只在内存里，**重启应用即丢**；账户同样不落盘（`TODO(storage)`）。
  接入 SQLite 后应改为账户表 + 登录态，并用发布者 id 取代 `isMine`。
- 没有密码 / 实名 / 多账户，没有「恢复已删除的信息」，也不支持把标记改回「进行中」。
- 首页的列表仍不支持下拉刷新，也不支持「只看我发的」这类筛选。

## 验证

```bash
dart analyze .        # 等价于 flutter analyze 的静态检查
flutter test
```

**最近一次验证结果（本轮）**：

- `flutter analyze` → `No issues found! (ran in 0.9s)`
- `flutter test` → `00:03 +25: All tests passed!`（首页 6 + 发布 6 + 我的 13 共 25 个）

注意：这两个命令在受限沙箱下会因无法启动分析器 / 测试子进程而失败
（`CreateFile failed 5 ... 拒绝访问。(process_win.cc:744)`），
需在放宽权限（danger-full-access）下运行或由用户手动执行，详见 basic-info.md 的环境备忘。

新增的 `test/profile_page_test.dart` 覆盖：

1. 我的界面展示账户入口与「我的发布」区块（含空态）；
2. 示例数据不会出现在「我的发布」里；
3. 注册账户：空提交时两条提醒，填好后卡片显示称呼与联系方式，且写入仓库；
4. 登记账户后发布界面的「联系方式」自动带出（跨界面，用 `LostAndFoundApp`）；
5. 「我的发布」列出自己发布的信息与统计数字；
6. 标记已找到：先弹确认，确认后状态写入仓库、按钮换成说明文字；
7. 招领信息标记的是「已归还」（文案随类型变化）；
8. 修改发布内容：表单回填原值，改完保存后回到「我的」且仓库同步更新；
9. 编辑时清空必填项会被拦下，页面不关闭、仓库不变；
10. 删除：先取消（什么都不发生），再确认（从仓库移除并回到空态）；
11. 退出登录后回到未登记状态，已发布内容不受影响；
12. 「去发布一条」能切到发布标签；
13. 端到端：走完发布流程后新信息出现在「我的发布」里且 `isMine` 为 `true`。

上一轮的 `test/widget_test.dart`（6 个首页测试）与 `test/publish_page_test.dart`（6 个发布测试）
在表单抽出、模型加字段后**全部保持通过**，未做任何改动。
