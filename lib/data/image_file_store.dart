import 'dart:io';

import 'package:path/path.dart' as p;

/// 图片文件在应用私有目录里的存放规则与读写。
///
/// 库里 `posts.image_paths` 存的是**文件名**（如 `p001-1.jpg`），不是绝对路径：
/// 应用目录在 iOS 上每次安装都会变，存下来的绝对路径重装后就指不到文件了。
/// 绝对路径与文件名之间的换算都收在 [resolve] / [filenameFor] 里。
///
/// 这里只管文件，不认 [dart:io] 以外的东西——没有 Flutter、没有数据库，
/// 所以在纯 Dart 测试里可以直接拿一个临时目录跑。
/// 抽象成接口是为了让上层能被测试替换：表单选图那套逻辑一跑起来就真的读写磁盘，
/// 而 `testWidgets` 的虚拟时间不驱动真实 I/O（`Directory.createTemp` 一类调用会一直
/// 挂着），所以 widget 测试给 [PhotoStore] 塞一个内存实现，真实实现
/// （[FileImageFileStore]）留给应用自己与 `test()` 里的存储测试。
abstract interface class ImageFileStore {
  /// 应用私有目录下的图片目录，调用方保证它已被创建。
  Directory get directory;

  /// 图片目录的绝对路径。
  String get path;

  /// 文件名 → 绝对路径。
  ///
  /// 绝对值原样返回（兼容库里遗留的旧数据），其余按图片目录拼。
  String resolve(String filename);

  /// 绝对路径 → 文件名。
  ///
  /// 这个方法**不碰文件系统**（不对文件是否存在下结论），只换算路径：
  /// 迁移与清理都要按文件名比较，比较前统一从这里过一道。
  String filenameFor(String filePath);

  /// 这个路径是否落在图片目录里。
  bool ownsPath(String filePath);

  /// 把 [sourcePath] 复制进图片目录，返回新文件名。
  ///
  /// [filename] 为空时按 [uniqueName] 起名；源文件不存在时抛
  /// [PathNotFoundException]，调用方据此跳过这一张。[keepSource] 为 `false`
  /// 时复制完删掉源文件（源文件是系统临时目录里的，本来就该由我们收尾）。
  Future<String> saveCopy(
    String sourcePath, {
    bool keepSource = true,
    String? filename,
  });

  /// [saveCopy] 的「搬」版本：源文件不再保留。
  Future<String> save(String sourcePath, {String? filename});

  /// 删掉若干张图片。文件不存在不算错（用户可能已经在系统相册里删过）。
  Future<void> deleteAll(Iterable<String> filenames);

  /// 删掉目录里所有不在 [referenced] 中的文件，返回删掉的文件名。
  ///
  /// 这是「清孤儿」：上次运行留下的、已经没有任何信息引用的图片。
  Future<List<String>> deleteUnreferenced(Set<String> referenced);

  /// 目录里现有的所有文件名。
  Future<Set<String>> listFilenames();

  /// 生成一个不会重名的文件名。
  static String uniqueName(String sourcePath) =>
      FileImageFileStore.uniqueName(sourcePath);

  /// 从路径里取扩展名，认不出来时退回 `.jpg`。
  static String extensionOf(String sourcePath) =>
      FileImageFileStore.extensionOf(sourcePath);
}

/// 真实实现：读写 [directory] 指向的那个目录。
class FileImageFileStore implements ImageFileStore {
  FileImageFileStore(this.directory);

  @override
  final Directory directory;

  @override
  String get path => directory.path;

  @override
  String resolve(String filename) =>
      p.isAbsolute(filename) ? filename : p.join(path, filename);

  /// 绝对路径 → 文件名。
  ///
  /// 这个方法**不碰文件系统**（不对文件是否存在下结论），只换算路径：
  /// 迁移与清理都要按文件名比较，比较前统一从这里过一道。
  @override
  String filenameFor(String filePath) {
    if (!p.isAbsolute(filePath)) {
      return filePath;
    }
    try {
      return p.basename(filePath);
    } on ArgumentError {
      // Windows 上 `C:` 这类没有结尾分隔符的路径取不出 basename；
      // 库里的数据不该长这样，真碰上了就原样带回去，让上层的存在性检查去兜。
      return filePath;
    }
  }

  /// [filePath] 是否已经在这个图片目录里。
  @override
  bool ownsPath(String filePath) =>
      p.isAbsolute(filePath) && p.isWithin(path, filePath);

  /// 把 [sourcePath] 收进图片目录，返回新的文件名。
  ///
  /// - [keepSource] 为 `false` 时会顺手删掉源文件：从相册/相机选来的图片
  ///   落在系统临时目录里，留着只是占空间。删不掉也不报错——临时目录本来就
  ///   会被系统回收。
  /// - 源文件不存在时抛 [PathNotFoundException]，由调用方（界面）提示。
  @override
  Future<String> saveCopy(
    String sourcePath, {
    bool keepSource = true,
    String? filename,
  }) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw PathNotFoundException(sourcePath, const OSError('图片文件不存在'));
    }

    await directory.create(recursive: true);
    final String name = filename ?? uniqueName(sourcePath);
    final File target = File(resolve(name));
    if (p.equals(source.path, target.path)) {
      return name;
    }

    await source.copy(target.path);
    if (!keepSource) {
      await _deleteQuietly(source);
    }
    return name;
  }

  /// 删除若干张图片；已经被删过 / 本来就不存在的不算错。
  @override
  Future<void> deleteAll(Iterable<String> filenames) async {
    for (final String filename in filenames) {
      await _deleteQuietly(File(resolve(filename)));
    }
  }

  /// 把图片目录里**没有被任何信息引用**的文件删掉。
  ///
  /// [referenced] 是当前数据库里所有信息引用的文件名集合（见
  /// `PhotoStore.reconcile`）。只清图片目录这一层，不递归——
  /// 目录是应用自己写的，正常只有一层图片文件。
  ///
  /// 返回删掉的文件名，测试与日志用。
  @override
  Future<List<String>> deleteUnreferenced(Set<String> referenced) async {
    if (!await directory.exists()) {
      return const <String>[];
    }

    final List<String> removed = <String>[];
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final String name = p.basename(entity.path);
      if (referenced.contains(name)) {
        continue;
      }
      if (await _deleteQuietly(entity)) {
        removed.add(name);
      }
    }
    return removed;
  }

  /// 目录里现有的文件名（测试与排查用）。
  @override
  Future<Set<String>> listFilenames() async {
    if (!await directory.exists()) {
      return <String>{};
    }
    final Set<String> names = <String>{};
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is File) {
        names.add(p.basename(entity.path));
      }
    }
    return names;
  }

  /// 生成一个不重名的文件名：`<毫秒时间戳>-<序号><扩展名>`。
  ///
  /// 时间戳在前是为了目录里按时间排得开、肉眼能看出先后；
  /// 序号兜住「同一毫秒连存两张」（用户连点两次选图）。
  static String uniqueName(String sourcePath) {
    _sequence = _sequence % 1000 + 1;
    return '${DateTime.now().millisecondsSinceEpoch}-'
        '$_sequence${extensionOf(sourcePath)}';
  }

  /// 同一次运行内的递增序号（见 [uniqueName]）。
  static int _sequence = 0;

  /// 源路径的扩展名，认不出来时退回 `.jpg`。
  ///
  /// 相册里出来的图片都会带扩展名；真遇到没带的，写一个默认值也强过
  /// 落一个没有扩展名的文件（图片解码器靠它判断格式）。
  static String extensionOf(String sourcePath) {
    final String ext = p.extension(sourcePath).toLowerCase();
    if (ext.isEmpty || ext.length > 5) {
      return '.jpg';
    }
    return RegExp(r'^\.[a-z0-9]+$').hasMatch(ext) ? ext : '.jpg';
  }

  /// 目录里还没有文件时先建目录，再交给 [saveCopy]。
  @override
  Future<String> save(String sourcePath, {String? filename}) async {
    await directory.create(recursive: true);
    return saveCopy(sourcePath, keepSource: false, filename: filename);
  }

  /// 删一个文件，失败不抛（清理是尽力而为的）。
  static Future<bool> _deleteQuietly(FileSystemEntity entity) async {
    try {
      await entity.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
