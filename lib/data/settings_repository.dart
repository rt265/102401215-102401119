import 'package:sqflite/sqflite.dart';

import 'db_schema.dart';

/// 应用设置仓库：按名字读写一项设置，值都是字符串。
///
/// 值统一按字符串存，编码与解码留给上层（比如主题模式存 `ThemeMode.name`）：
/// 表结构因此不用跟着设置项类型变。
abstract interface class SettingsRepository {
  /// 读一项设置；这一项还没存过时返回 `null`。
  Future<String?> read(String name);

  /// 写入（覆盖）一项设置。
  Future<void> write(String name, String value);
}

/// 落到本地 SQLite 的 [SettingsRepository]。
///
/// 表以设置名为主键，所以「写入」永远是覆盖那一行，不会攒出重复项。
class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._database);

  /// 执行 SQL 的句柄，通常是 [AppDatabase.database]。
  final DatabaseExecutor _database;

  @override
  Future<String?> read(String name) async {
    final List<Map<String, Object?>> rows = await _database.query(
      DbSchema.settingsTable,
      columns: <String>[DbSchema.settingValue],
      where: '${DbSchema.settingName} = ?',
      whereArgs: <Object?>[name],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first[DbSchema.settingValue]! as String;
  }

  @override
  Future<void> write(String name, String value) async {
    await _database.insert(DbSchema.settingsTable, <String, Object?>{
      DbSchema.settingName: name,
      DbSchema.settingValue: value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
