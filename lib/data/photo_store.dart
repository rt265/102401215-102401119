import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_schema.dart';
import 'image_file_store.dart';

/// 图片仓库：应用私有目录里的图片文件（保存 / 删除 / 清理 / 路径换算）。
///
/// 和 `PostStore` / `UserStore` 的分工一样——界面层只跟这里打交道，不直接碰
/// [File]：
///
/// ```dart
/// final PhotoStore photos = PhotoScope.of(context);
/// final String name = await session.savePicked(pickedPath); // 存图，拿到文件名
/// Image.file(File(photos.resolve(name)));                   // 显示
/// ```
///
/// 库里存的是**文件名**而不是绝对路径，理由见 [ImageFileStore]。
///
/// [notifyListeners] 目前不会被触发；继承 [ChangeNotifier] 只是为了能被
/// [PhotoScope]（[InheritedNotifier]）直接下发，和另外两个仓库保持一致。
class PhotoStore extends ChangeNotifier {
  PhotoStore(this._files);

  final ImageFileStore _files;

  /// 底层文件读写入口。
  ///
  /// 应用启动时用它做一次图片迁移（`PhotoStore.applyPendingUpdates`）——
  /// 那件事要在数据库与文件系统之间来回，仓库本身不掺和。
  ImageFileStore get files => _files;

  /// 图片目录的绝对路径。
  String get directoryPath => _files.path;

  /// 打开图片目录（不存在就建）并返回仓库。
  ///
  /// [directory] 由调用方给：应用里是数据库目录下的 `photos/`，测试里是临时
  /// 目录——和 `AppDatabase.open` 的 `path` 是同一个路子。
  static Future<PhotoStore> open(String directory) async {
    final FileImageFileStore files = FileImageFileStore(Directory(directory));
    await files.directory.create(recursive: true);
    return PhotoStore(files);
  }

  /// 文件名 → 可以直接交给 `File` / `Image.file` 的绝对路径。
  String resolve(String filename) => _files.resolve(filename);

  /// 文件名 → 文件名（库里的值统一从这里过一道，绝对路径会被剥成文件名）。
  String filenameOf(String path) => _files.filenameFor(path);

  /// 从磁盘上删掉若干张图片（信息被删除时用）。
  Future<void> deleteFiles(Iterable<String> filenames) =>
      _files.deleteAll(filenames);

  /// 开始一次「正在编辑的表单」会话。
  ///
  /// 表单里新存进来的图片先记在会话上：用户点了「还原」、清空或者直接退出
  /// 编辑页时，[FormImageSession.discard] 把它们删掉；正常保存则
  /// [FormImageSession.commit]，这些文件归信息所有。
  ///
  /// 会话一开出来就登记在册：清理孤儿文件时（[reconcile]）要按这份名册放过
  /// 还没落库的草稿图，登记晚一步就可能把它们删掉。
  FormImageSession beginSession() {
    final FormImageSession session = FormImageSession._(this);
    _sessions.add(session);
    return session;
  }

  final Set<FormImageSession> _sessions = <FormImageSession>{};

  void _commitSession(FormImageSession session) {
    _sessions.remove(session);
    session._clear();
  }

  Future<void> _discardSession(FormImageSession session) async {
    _sessions.remove(session);
    final List<String> files = session._clear();
    await deleteFiles(files);
  }

  /// 当前还有几个没提交的表单会话（测试用）。
  @visibleForTesting
  int get activeSessionCount => _sessions.length;

  /// 清理没有被任何信息引用的图片。
  ///
  /// [referenced] 是数据库里所有信息引用的文件名。**不能拿 `PostStore` 的
  /// 内存快照来算**——快照是启动前一刻的状态，而清理发生在启动时；这里要的是
  /// 库里的真值（见 [referencedFilenames]）。
  ///
  /// 正在编辑的表单里刚存下的图片会被跳过：它们还没落库，但马上要被引用。
  ///
  /// 返回删掉的文件名（测试与排查用）。
  Future<List<String>> reconcile(Set<String> referenced) async {
    final Set<String> protectedNames = <String>{
      ...referenced,
      for (final FormImageSession session in _sessions) ...session.filenames,
    };
    final List<String> removed = await _files.deleteUnreferenced(
      protectedNames,
    );
    if (removed.isNotEmpty) {
      debugPrint('[photos] 清理了 ${removed.length} 个未被引用的图片文件');
    }
    return removed;
  }

  /// 从库里读出所有信息引用的文件名。
  ///
  /// 直接查 `image_paths` 列自己解析：这样清理只依赖库，不依赖 [PostStore]
  /// 有没有被装载。
  static Future<Set<String>> referencedFilenames(DatabaseExecutor db) async {
    final List<Map<String, Object?>> rows = await db.query(
      DbSchema.postsTable,
      columns: <String>[DbSchema.postImagePaths],
    );
    return referencedFilenamesOfRows(rows);
  }

  /// [referencedFilenames] 的纯函数部分（不碰数据库，测试直接喂行）。
  static Set<String> referencedFilenamesOfRows(
    List<Map<String, Object?>> rows,
  ) {
    final Set<String> names = <String>{};
    for (final Map<String, Object?> row in rows) {
      for (final String path in decodeImagePaths(
        row[DbSchema.postImagePaths],
      )) {
        names.add(_basenameOrSelf(path));
      }
    }
    return names;
  }

  /// 解析 `image_paths` 这一列的 JSON 数组；坏数据当作「没有图片」。
  ///
  /// 与 `PostRow._imagePathsOf` 同一套容错口径：一条坏数据不该让整个列表打不开。
  static List<String> decodeImagePaths(Object? stored) {
    if (stored is! String || stored.isEmpty) {
      return const <String>[];
    }
    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // 落到下面的空列表。
    }
    return const <String>[];
  }

  /// 把库里遗留的**绝对路径**改成文件名（图片搬进应用私有目录）。
  ///
  /// 本地后端事项 1 只把图片路径当字符串存了下来；真正接上选图之前，库里
  /// （或更早的手工数据里）可能存着绝对路径。绝对路径在 iOS 上重装一次就失效，
  /// 所以在启动时迁一次：
  ///
  /// 1. 文件还在 → 复制进图片目录，库里改写成文件名；
  /// 2. 文件已经不在了 → 按**保留文件名**处理：`/tmp/a/b.jpg` 写成 `b.jpg`。
  ///    这个位置可能本来就有同名文件，也可能没有；没有的话界面按「图挂了」
  ///    降级显示（`PostPhoto` 的兜底），不会崩。
  ///
  /// 整个过程是幂等的：库里已经是文件名的行原样跳过，重复跑没有副作用。
  /// 迁移必须放在清理孤儿文件**之前**，否则一个刚搬进来的文件会被当成孤儿删掉。
  static Future<PhotoMigrationResult> applyPendingUpdates(
    ImageFileStore files,
    DatabaseExecutor db,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      DbSchema.postsTable,
      columns: <String>[DbSchema.postId, DbSchema.postImagePaths],
    );

    // 先算清楚每一行该改成什么，最后批量写回：查询循环里不夹写操作。
    final List<Map<String, Object?>> updates = <Map<String, Object?>>[];
    final Map<String, String> adopted = <String, String>{};
    int missing = 0;

    for (final Map<String, Object?> row in rows) {
      final List<String> stored = decodeImagePaths(
        row[DbSchema.postImagePaths],
      );
      if (stored.isEmpty) {
        continue;
      }

      bool changed = false;
      final List<String> migrated = <String>[];
      for (final String path in stored) {
        if (files.ownsPath(path)) {
          // 已经在图片目录里：只把绝对路径写成文件名。
          migrated.add(files.filenameFor(path));
          changed = true;
          continue;
        }
        if (!p.isAbsolute(path)) {
          // 本来就是文件名（常规情况）：原样保留。
          migrated.add(path);
          continue;
        }

        String? name = adopted[path];
        if (name == null) {
          name = await _adopt(files, path);
          if (name == null) {
            // 原文件没了，退化成文件名保留，别把这条引用整个丢掉。
            missing++;
            name = files.filenameFor(path);
          } else {
            adopted[path] = name;
          }
        }
        migrated.add(name);
        changed = true;
      }

      if (changed) {
        updates.add(<String, Object?>{
          DbSchema.postId: row[DbSchema.postId],
          DbSchema.postImagePaths: jsonEncode(migrated),
        });
      }
    }

    if (updates.isEmpty) {
      return const PhotoMigrationResult(migratedPosts: 0, missingFiles: 0);
    }

    final Batch batch = db.batch();
    for (final Map<String, Object?> update in updates) {
      batch.update(
        DbSchema.postsTable,
        <String, Object?>{
          DbSchema.postImagePaths: update[DbSchema.postImagePaths],
        },
        where: '${DbSchema.postId} = ?',
        whereArgs: <Object?>[update[DbSchema.postId]],
      );
    }
    await batch.commit(noResult: true);

    debugPrint(
      '[photos] 迁移了 ${updates.length} 条信息的图片路径'
      '（其中 $missing 张找不到原文件）',
    );
    return PhotoMigrationResult(
      migratedPosts: updates.length,
      missingFiles: missing,
    );
  }

  /// 把 [path] 上的文件复制进图片目录，返回库里的新值（文件名）。
  ///
  /// 优先用原来的文件名：库里那条路径原本就是 `/相册/水杯.jpg`，搬家后叫
  /// `水杯.jpg` 最贴近原意，也方便对着库排错。目录里已经有人用了这个名字，或者
  /// 这个名字不能当文件名，就退回唯一名——`saveCopy` 会直接覆盖同名文件，
  /// 硬搬会把另一条信息的图盖掉。
  ///
  /// 文件已经不在时返回 `null`：迁移失败不该拦住应用启动。
  static Future<String?> _adopt(ImageFileStore files, String path) async {
    final String preferred = files.filenameFor(path);
    if (!await File(files.resolve(preferred)).exists()) {
      try {
        return await files.saveCopy(
          path,
          keepSource: true,
          filename: preferred,
        );
      } on FileSystemException {
        // 落到下面的唯一名再试一次。
      } on ArgumentError {
        // 同上：名字里带不能当文件名的字符。
      }
    }
    try {
      return await files.saveCopy(path, keepSource: true);
    } on FileSystemException {
      return null;
    }
  }

  /// 取 basename，取不出来就原样返回（不依赖 [ImageFileStore] 实例）。
  static String _basenameOrSelf(String path) {
    if (!p.isAbsolute(path)) {
      return path;
    }
    try {
      return p.basename(path);
    } on ArgumentError {
      return path;
    }
  }
}

/// 一次图片迁移的结果。
@immutable
class PhotoMigrationResult {
  const PhotoMigrationResult({
    required this.migratedPosts,
    required this.missingFiles,
  });

  /// 被改写过的信息条数。
  final int migratedPosts;

  /// 库里记着、但文件已经不在了的图片张数（已降级成文件名保留）。
  final int missingFiles;

  @override
  String toString() =>
      'PhotoMigrationResult(migratedPosts: $migratedPosts, '
      'missingFiles: $missingFiles)';
}

/// 一次「正在编辑的表单」的图片草稿。
///
/// 表单里每存一张图就往这里记一笔：保存（[commit]）之后这些文件归信息所有；
/// 还原 / 清空 / 退出（[discard]）则把它们删掉，不在图片目录里留垃圾。
class FormImageSession {
  FormImageSession._(this._store);

  final PhotoStore _store;
  final List<String> _files = <String>[];

  /// 本会话存下的文件名（[PhotoStore.reconcile] 要把它们算进受保护集合）。
  List<String> get filenames => List<String>.unmodifiable(_files);

  /// 本会话是否存过图片。
  bool get isEmpty => _files.isEmpty;

  /// 存一张刚选来的图片（相册 / 相机），返回落库用的文件名，并自动记账。
  ///
  /// 源文件是从系统临时目录里拿到的，复制完就删掉，不留垃圾；复制失败会抛
  /// [FileSystemException] / [PathNotFoundException]，由调用方提示用户。
  Future<String> savePicked(String sourcePath) async {
    final String name = await _store._files.save(sourcePath);
    _files.add(name);
    return name;
  }

  /// 保存成功：这些图片有了主人，不再当草稿。
  void commit() => _store._commitSession(this);

  /// 放弃这次编辑：把本会话存下的图片删掉。
  Future<void> discard() => _store._discardSession(this);

  List<String> _clear() {
    final List<String> files = List<String>.of(_files);
    _files.clear();
    return files;
  }
}

/// 把 [PhotoStore] 沿 widget 树下发（与 `PostScope` / `UserScope` 同款）。
///
/// 与另外两个仓库不同，这里的 [store] 可以为 `null`：图片依赖一块真实的磁盘
/// 目录，纯内存模式（不落盘的测试、预览）没有它，此时界面按「没有图片」显示，
/// 而不是崩在某个 `!` 上。
class PhotoScope extends InheritedNotifier<PhotoStore> {
  const PhotoScope({super.key, this.store, required super.child})
    : super(notifier: store);

  /// 当前图片仓库；`null` 表示这次运行没有图片目录。
  final PhotoStore? store;

  /// 取当前仓库；没有套 [PhotoScope]、或没有图片目录时返回 `null`。
  static PhotoStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoScope>()?.notifier;
}
