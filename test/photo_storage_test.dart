import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/data/db_schema.dart';
import 'package:lost_and_found/data/image_file_store.dart';
import 'package:lost_and_found/data/photo_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 图片落盘这一层（`ImageFileStore` / `PhotoStore`）的测试。
///
/// 全部跑在真实临时目录上：这一层存在的意义就是「文件和数据库要一起对」，
/// 用假文件系统测等于没测。需要数据库的那两组用 sqflite 的 ffi 实现（内存库）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  /// 建一个临时图片目录，测试结束自动删掉。
  Future<Directory> makeTempDir() async {
    final Directory dir = await Directory.systemTemp.createTemp('laf-photos-');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    return dir;
  }

  /// 在临时目录里放一个「已经存在的图片文件」，返回它的绝对路径。
  Future<String> writeSourceFile(
    Directory dir,
    String name, [
    String content = 'fake-image-bytes',
  ]) async {
    final File file = File(p.join(dir.path, name));
    await file.writeAsString(content);
    return file.path;
  }

  Future<Database> openMemoryDatabase() async {
    final Database db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) => DbSchema.create(db),
      ),
    );
    addTearDown(db.close);
    return db;
  }

  /// 直接往表里塞一行：`image_paths` 按库里真实的存法（JSON 数组字符串）写。
  Future<void> insertPostRow(
    Database db,
    String id,
    List<String> imagePaths,
  ) async {
    // 用 jsonEncode 拼，别手写引号：Windows 的绝对路径里全是反斜杠，
    // 手拼出来的不是合法 JSON 字符串，读回来会被容错逻辑当成「没有图片」。
    final String encoded = jsonEncode(imagePaths);
    await db.insert(DbSchema.postsTable, <String, Object?>{
      DbSchema.postId: id,
      DbSchema.postType: 'lost',
      DbSchema.postTitle: '测试信息',
      DbSchema.postCategory: 'other',
      DbSchema.postLocation: '图书馆',
      DbSchema.postEventTime: 0,
      DbSchema.postContact: '13800000000',
      DbSchema.postCreatedAt: 0,
      DbSchema.postDescription: null,
      DbSchema.postImagePaths: encoded,
      DbSchema.postStatus: 'pending',
      DbSchema.postIsMine: 0,
      DbSchema.postSearchText: '测试信息',
    });
  }

  Future<List<String>> storedImagePaths(Database db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      DbSchema.postsTable,
      columns: <String>[DbSchema.postImagePaths],
      where: '${DbSchema.postId} = ?',
      whereArgs: <Object?>[id],
    );
    return PhotoStore.decodeImagePaths(rows.single[DbSchema.postImagePaths]);
  }

  group('ImageFileStore', () {
    test('文件名与绝对路径可以互相换算', () async {
      final Directory dir = await makeTempDir();
      final ImageFileStore store = FileImageFileStore(dir);

      expect(store.resolve('a.jpg'), p.join(dir.path, 'a.jpg'));
      // 已经是绝对路径的原样返回（库里遗留的旧数据）。
      expect(store.resolve('/tmp/x/a.jpg'), '/tmp/x/a.jpg');
      expect(store.filenameFor('a.jpg'), 'a.jpg');
      expect(store.filenameFor(p.join(dir.path, 'a.jpg')), 'a.jpg');
      expect(store.ownsPath(p.join(dir.path, 'a.jpg')), isTrue);
      expect(store.ownsPath('/tmp/x/a.jpg'), isFalse);
    });

    test('save 把图片复制进目录并删掉源文件，文件名唯一', () async {
      final Directory dir = await makeTempDir();
      final Directory source = await makeTempDir();
      final ImageFileStore store = FileImageFileStore(dir);

      final String first = await store.save(
        await writeSourceFile(source, 'picked.png', 'one'),
      );
      final String second = await store.save(
        await writeSourceFile(source, 'picked.png', 'two'),
      );

      expect(first, isNot(second), reason: '同一毫秒连存两张也不能重名');
      expect(p.extension(first), '.png');
      expect(await File(store.resolve(first)).readAsString(), 'one');
      expect(await File(store.resolve(second)).readAsString(), 'two');
      // 源文件是系统临时目录里的，复制完就该删掉。
      expect(await File(p.join(source.path, 'picked.png')).exists(), isFalse);
    });

    test('源文件不存在时抛 PathNotFoundException', () async {
      final Directory dir = await makeTempDir();
      final ImageFileStore store = FileImageFileStore(dir);

      expect(
        () => store.save(p.join(dir.path, '缺失.jpg')),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test('deleteUnreferenced 只删没人引用的文件', () async {
      final Directory dir = await makeTempDir();
      final Directory source = await makeTempDir();
      final ImageFileStore store = FileImageFileStore(dir);

      final String kept = await store.save(
        await writeSourceFile(source, 'kept.jpg'),
      );
      final String orphan = await store.save(
        await writeSourceFile(source, 'orphan.jpg'),
      );

      expect(await store.deleteUnreferenced(<String>{kept}), <String>[orphan]);
      expect(await store.listFilenames(), <String>{kept});
    });

    test('认不出来的扩展名退回 .jpg', () async {
      expect(ImageFileStore.extensionOf('/tmp/a/b.PNG'), '.png');
      expect(ImageFileStore.extensionOf('/tmp/a/b'), '.jpg');
      expect(ImageFileStore.extensionOf('/tmp/a/b.verylongext'), '.jpg');
      expect(ImageFileStore.extensionOf('/tmp/a/b.tar.gz'), '.gz');
    });
  });

  group('PhotoStore 与数据库的配合', () {
    test('referencedFilenames 从库里读引用，绝对路径也认', () async {
      final Database db = await openMemoryDatabase();
      await insertPostRow(db, 'p1', <String>['a.jpg', '/tmp/old/b.png']);
      await insertPostRow(db, 'p2', <String>[]);

      expect(await PhotoStore.referencedFilenames(db), <String>{'a.jpg', 'b.png'});
    });

    test('applyPendingUpdates 把绝对路径搬进目录并改写成文件名', () async {
      final Directory dir = await makeTempDir();
      final Directory source = await makeTempDir();
      final ImageFileStore files = FileImageFileStore(dir);
      final Database db = await openMemoryDatabase();

      final String oldPath = await writeSourceFile(source, 'old-photo.jpg');
      await insertPostRow(db, 'p1', <String>[oldPath, 'plain.jpg']);

      final PhotoMigrationResult result =
          await PhotoStore.applyPendingUpdates(files, db);

      expect(result.migratedPosts, 1);
      expect(result.missingFiles, 0);
      final List<String> stored = await storedImagePaths(db, 'p1');
      expect(stored, hasLength(2));
      // 第一张搬进了图片目录（文件名与原名一致），第二张本来就只是文件名。
      expect(stored.first, 'old-photo.jpg');
      expect(stored.last, 'plain.jpg');
      expect(await File(p.join(dir.path, 'old-photo.jpg')).exists(), isTrue);
      // 迁移是「搬一份」而不是「挪走」：库里那条老路径的文件不归我们管，不能动它。
      expect(await File(oldPath).exists(), isTrue);

      // 幂等：再跑一次不该有任何改动。
      final PhotoMigrationResult again = await PhotoStore.applyPendingUpdates(
        files,
        db,
      );
      expect(again.migratedPosts, 0);
      expect(await storedImagePaths(db, 'p1'), stored);
    });

    test('applyPendingUpdates 对已经不在的文件只保留文件名', () async {
      final Directory dir = await makeTempDir();
      final ImageFileStore files = FileImageFileStore(dir);
      final Database db = await openMemoryDatabase();

      await insertPostRow(db, 'p1', <String>['/tmp/gone/missing.jpg']);

      final PhotoMigrationResult result =
          await PhotoStore.applyPendingUpdates(files, db);

      expect(result.migratedPosts, 1);
      expect(result.missingFiles, 1);
      expect(await storedImagePaths(db, 'p1'), <String>['missing.jpg']);
    });

    test('applyPendingUpdates 遇到重名时改用唯一文件名', () async {
      final Directory dir = await makeTempDir();
      final Directory source = await makeTempDir();
      final ImageFileStore files = FileImageFileStore(dir);
      final Database db = await openMemoryDatabase();

      // 图片目录里已经有一张同名的（另一条信息的图）。
      await File(p.join(dir.path, 'same.jpg')).writeAsString('已经在目录里的');
      final String oldPath = await writeSourceFile(source, 'same.jpg', '新搬来的');
      await insertPostRow(db, 'p1', <String>[oldPath]);

      final PhotoMigrationResult result = await PhotoStore.applyPendingUpdates(
        files,
        db,
      );

      expect(result.migratedPosts, 1);
      final String stored = (await storedImagePaths(db, 'p1')).single;
      expect(stored, isNot('same.jpg'), reason: '不能盖掉目录里已有的同名文件');
      expect(
        await File(p.join(dir.path, 'same.jpg')).readAsString(),
        '已经在目录里的',
      );
      expect(await File(p.join(dir.path, stored)).readAsString(), '新搬来的');
    });

    test('reconcile 删掉没人引用的文件，留下还在用的', () async {
      final Directory dir = await makeTempDir();
      final Directory source = await makeTempDir();
      final PhotoStore store = await PhotoStore.open(dir.path);

      final FormImageSession session = store.beginSession();
      final String kept = await session.savePicked(
        await writeSourceFile(source, 'kept.jpg'),
      );
      final String orphan = await session.savePicked(
        await writeSourceFile(source, 'orphan.jpg'),
      );
      // 两张都交给信息了：这时才该按数据库里的引用集合来清理。
      session.commit();

      final List<String> removed = await store.reconcile(<String>{kept});

      expect(removed, <String>[orphan]);
      expect(await store.files.listFilenames(), <String>{kept});
    });

    test('会话里的图片不会被清理，discard 才删掉', () async {
      final Directory dir = await makeTempDir();
      final Directory source = await makeTempDir();
      final PhotoStore store = await PhotoStore.open(dir.path);

      final FormImageSession session = store.beginSession();
      final String draft = await session.savePicked(
        await writeSourceFile(source, 'draft.jpg'),
      );

      expect(store.activeSessionCount, 1);
      // 还没保存的草稿图：数据库里没有任何引用，但清理要放过它。
      expect(await store.reconcile(<String>{}), isEmpty);
      expect(await store.files.listFilenames(), <String>{draft});

      await session.discard();
      expect(store.activeSessionCount, 0);
      expect(await store.files.listFilenames(), isEmpty);
    });

    test('会话 commit 之后图片归信息所有', () async {
      final Directory dir = await makeTempDir();
      final Directory source = await makeTempDir();
      final PhotoStore store = await PhotoStore.open(dir.path);

      final FormImageSession session = store.beginSession();
      final String saved = await session.savePicked(
        await writeSourceFile(source, 'kept.jpg'),
      );
      session.commit();

      expect(store.activeSessionCount, 0);
      // 已经交给信息了：即便这次清理没把它算进引用，也该留着——
      // 真实流程里它已经落库，这里模拟「清理时引用集合是准的」。
      expect(await store.reconcile(<String>{saved}), isEmpty);
      expect(await store.files.listFilenames(), <String>{saved});
    });
  });

  group('PhotoStore.decodeImagePaths', () {
    test('坏数据当作没有图片', () {
      expect(PhotoStore.decodeImagePaths(null), isEmpty);
      expect(PhotoStore.decodeImagePaths(''), isEmpty);
      expect(PhotoStore.decodeImagePaths('not json'), isEmpty);
      expect(PhotoStore.decodeImagePaths('{"a":1}'), isEmpty);
      expect(PhotoStore.decodeImagePaths('["a.jpg", 3, "b.jpg"]'), <String>[
        'a.jpg',
        'b.jpg',
      ]);
    });
  });
}
