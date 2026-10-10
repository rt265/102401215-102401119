# 本地后端事项 3：多用户隔离

## 目标

在继续使用本地 SQLite 的前提下，为每个账户分配稳定 ID，并让信息的管理操作只作用于当前账户自己的信息。公开浏览和搜索仍然可以看到所有信息。

## 实现

- `user_account` 从固定主键单行表升级为可保存多行账户的表，`UserAccount.id` 保存稳定的本地账户 ID。
- `posts` 增加可为空的 `author_id`。示例数据和升级前信息保留空值，兼容旧数据。
- `SqliteItemRepository` 接收 `currentUserId`：
  - 查询结果中的 `isMine` 按 `author_id == currentUserId` 计算；
  - 新增信息写入当前账户 ID；
  - 修改和删除同时匹配信息 ID 与当前账户 ID，不能越权操作其他账户的信息。
- 数据库版本从 3 升到 4。迁移会先给 `posts` 增列，再把旧 `user_account` 重建为多行结构，并把旧账户迁移为 `legacy-account`。
- 未提供当前账户 ID 时保留旧的内存/测试语义，旧数据仍可正常读取。

## 验证

- `test/sqlite_storage_test.dart`：30 个用例通过。
- 新增“多用户隔离”用例，验证两个账户各自识别自己的信息，且不能修改或删除对方信息。
- `flutter analyze`：通过。

## 注意

当前应用仍是本地账户模型，不引入密码、实名认证或远程登录。账户资料与信息均留在本机 SQLite 中。
