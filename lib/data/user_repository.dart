import 'package:sqflite/sqflite.dart';

import '../models/user_account.dart';
import 'db_schema.dart';

/// 账户仓库：账户资料按稳定 ID 分行保存。
abstract interface class UserRepository {
  /// 读回本机账户；还没登记过时返回 `null`。
  Future<UserAccount?> loadAccount();
  Future<List<UserAccount>> loadAccounts();

  /// 保存（覆盖）本机账户。
  Future<void> saveAccount(UserAccount account);

  /// 清掉本机账户（退出登录）。
  Future<void> clearAccount();
}

/// 落到本地 SQLite 的 [UserRepository]。
///
class SqliteUserRepository implements UserRepository {
  SqliteUserRepository(this._database);

  /// 执行 SQL 的句柄，通常是 [AppDatabase.database]。
  final DatabaseExecutor _database;

  @override
  Future<UserAccount?> loadAccount() async {
    final List<Map<String, Object?>> rows = await _database.query(
      DbSchema.userAccountTable,
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    return _fromRow(rows.first);
  }

  @override
  Future<List<UserAccount>> loadAccounts() async {
    final List<Map<String, Object?>> rows = await _database.query(
      DbSchema.userAccountTable,
      orderBy: '${DbSchema.accountCreatedAt} ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  UserAccount _fromRow(Map<String, Object?> row) => UserAccount(
      id: row[DbSchema.accountRowKey]! as String,
      displayName: row[DbSchema.accountDisplayName]! as String,
      contact: row[DbSchema.accountContact]! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row[DbSchema.accountCreatedAt]! as int,
      ),
    );

  @override
  Future<void> saveAccount(UserAccount account) async {
    await _database.insert(DbSchema.userAccountTable, <String, Object?>{
      DbSchema.accountRowKey:
          account.id ?? 'user-${account.createdAt.microsecondsSinceEpoch}',
      DbSchema.accountDisplayName: account.displayName,
      DbSchema.accountContact: account.contact,
      DbSchema.accountCreatedAt: account.createdAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearAccount() async {
    await _database.delete(DbSchema.userAccountTable);
  }
}
