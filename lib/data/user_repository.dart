import 'package:sqflite/sqflite.dart';

import '../models/user_account.dart';
import 'db_schema.dart';

/// 账户仓库：读写的都是「本机这一份」账户。
abstract interface class UserRepository {
  /// 读回本机账户；还没登记过时返回 `null`。
  Future<UserAccount?> loadAccount();

  /// 保存（覆盖）本机账户。
  Future<void> saveAccount(UserAccount account);

  /// 清掉本机账户（退出登录）。
  Future<void> clearAccount();
}

/// 落到本地 SQLite 的 [UserRepository]。
///
/// 表是单行的：固定主键 1 + `REPLACE` 写入，所以「保存」永远是覆盖那一行。
class SqliteUserRepository implements UserRepository {
  SqliteUserRepository(this._database);

  /// 执行 SQL 的句柄，通常是 [AppDatabase.database]。
  final DatabaseExecutor _database;

  @override
  Future<UserAccount?> loadAccount() async {
    final List<Map<String, Object?>> rows = await _database.query(
      DbSchema.userAccountTable,
      where: '${DbSchema.accountRowKey} = ?',
      whereArgs: <Object?>[DbSchema.accountRowId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final Map<String, Object?> row = rows.first;
    return UserAccount(
      displayName: row[DbSchema.accountDisplayName]! as String,
      contact: row[DbSchema.accountContact]! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row[DbSchema.accountCreatedAt]! as int,
      ),
    );
  }

  @override
  Future<void> saveAccount(UserAccount account) async {
    await _database.insert(DbSchema.userAccountTable, <String, Object?>{
      DbSchema.accountRowKey: DbSchema.accountRowId,
      DbSchema.accountDisplayName: account.displayName,
      DbSchema.accountContact: account.contact,
      DbSchema.accountCreatedAt: account.createdAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearAccount() async {
    await _database.delete(
      DbSchema.userAccountTable,
      where: '${DbSchema.accountRowKey} = ?',
      whereArgs: <Object?>[DbSchema.accountRowId],
    );
  }
}
