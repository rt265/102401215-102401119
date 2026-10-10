import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/data/image_file_store.dart';
import 'package:lost_and_found/data/photo_store.dart';
import 'package:lost_and_found/models/item_post.dart';
import 'package:lost_and_found/services/photo_picker.dart';
import 'package:lost_and_found/widgets/post_form.dart';
import 'package:path/path.dart' as p;

/// 换掉真机相册的假选择器：`paths` 是「用户每次挑中的文件」的队列。
class _TestPhotoPicker implements PhotoPicker {
  _TestPhotoPicker();

  final List<List<String>> paths = <List<String>>[];
  final List<PhotoPickSource> sources = <PhotoPickSource>[];

  @override
  Future<List<String>> pick(PhotoPickSource source) async {
    sources.add(source);
    if (paths.isEmpty) {
      throw PhotoPickCanceled();
    }
    return paths.removeAt(0);
  }
}

/// 永远失败的选择器：验证错误提示，而不是把异常抛到界面上。
class _FailingPhotoPicker implements PhotoPicker {
  @override
  Future<List<String>> pick(PhotoPickSource source) async =>
      throw const PhotoPickFailure('相册被系统拦住了。');
}

/// 内存版图片目录：只在 Map 里记账，绝不碰磁盘。
///
/// widget 测试跑在 `testWidgets` 的虚拟时间区里，真实文件 I/O 的 future
/// 不会被驱动（`File.copy` 一 await 就永远挂着），所以表单选图这条路必须在
/// 内存里走完。真实的文件读写由 `photo_storage_test.dart` 用普通 `test()` 覆盖。
class _MemoryImageFileStore implements ImageFileStore {
  final Map<String, String> files = <String, String>{};

  /// 假想目录：只用于拼路径，不会真的被创建。
  static final Directory _fakeDirectory = Directory(
    p.join(Directory.systemTemp.path, 'laf-memory-photos'),
  );

  @override
  Directory get directory => _fakeDirectory;

  @override
  String get path => _fakeDirectory.path;

  @override
  String resolve(String filename) =>
      p.isAbsolute(filename) ? filename : p.join(path, filename);

  @override
  String filenameFor(String filePath) =>
      p.isAbsolute(filePath) ? p.basename(filePath) : filePath;

  @override
  bool ownsPath(String filePath) =>
      p.isAbsolute(filePath) && p.isWithin(path, filePath);

  @override
  Future<String> saveCopy(
    String sourcePath, {
    bool keepSource = true,
    String? filename,
  }) async {
    // 源文件是否真实存在不在这里判断：真实现会抛 PathNotFoundException，
    // 但改用内存实现后「文件存不存在」这件事只由 files 这张表说了算。
    final String name = filename ?? ImageFileStore.uniqueName(sourcePath);
    files[name] = sourcePath;
    return name;
  }

  @override
  Future<String> save(String sourcePath, {String? filename}) =>
      saveCopy(sourcePath, keepSource: false, filename: filename);

  @override
  Future<void> deleteAll(Iterable<String> filenames) async {
    for (final String name in filenames) {
      files.remove(name);
    }
  }

  @override
  Future<List<String>> deleteUnreferenced(Set<String> referenced) async {
    final List<String> removed = files.keys
        .where((String name) => !referenced.contains(name))
        .toList();
    for (final String name in removed) {
      files.remove(name);
    }
    return removed;
  }

  @override
  Future<Set<String>> listFilenames() async => files.keys.toSet();
}

/// 先把控件滚进视口再点，避免长表单里的控件在屏幕外点不到。
///
/// 这里用 `pump` 而不是 `pumpAndSettle`：图片缩略图走的是 `Image.file`，
/// 真去读磁盘文件时帧调度不会真正静止，`pumpAndSettle` 会一直等到超时。
Future<void> tapAt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// 点系统日期 / 时间选择器里的确认按钮。
///
/// 这里 `pumpForm` 用的是裸 `MaterialApp`（没挂 `localizationsDelegates`），
/// 所以系统控件是 Flutter 默认的英文——确认键仍是 `OK`，与固定中文 locale 的
/// `LostAndFoundApp` 不同（那边是「确定」，见 publish_page_test.dart）。
Future<void> confirmPicker(WidgetTester tester) async {
  final Finder ok = find.text('OK');
  expect(ok, findsWidgets, reason: '未接本地化的裸 MaterialApp 里应是英文 OK 按钮');
  await tester.tap(ok.last);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryImageFileStore imageFiles;
  late PhotoStore photoStore;
  late _TestPhotoPicker picker;

  setUp(() {
    imageFiles = _MemoryImageFileStore();
    photoStore = PhotoStore(imageFiles);
    picker = _TestPhotoPicker();
  });

  tearDown(() {
    photoStore.dispose();
  });

  /// 图片目录里现有的文件名（有序，便于按下标断言）。
  List<String> storedNames() => imageFiles.files.keys.toList();

  /// 造一个「刚拍 / 刚选」的源文件路径（内存实现不检查它是否真的存在）。
  String fakeSource(String name) => p.join(r'C:\laf-picked', name);

  Future<void> pumpForm(
    WidgetTester tester, {
    ItemPost? initial,
    GlobalKey<PostFormState>? formKey,
    PhotoPicker? customPicker,
  }) async {
    await tester.pumpWidget(
      PhotoScope(
        store: photoStore,
        child: PhotoPickerScope(
          picker: customPicker ?? picker,
          child: MaterialApp(
            home: Scaffold(
              body: PostForm(key: formKey, initial: initial, onSaved: (_) {}),
            ),
          ),
        ),
      ),
    );
  }

  /// 走完选图流程：点「加一张」→ 在来源弹窗里选一项。
  Future<void> addPhoto(WidgetTester tester, {bool fromCamera = false}) async {
    await tapAt(tester, find.byKey(const Key('publish-photo-add')));
    await tapAt(
      tester,
      find.byKey(
        Key(
          fromCamera
              ? 'publish-photo-source-camera'
              : 'publish-photo-source-gallery',
        ),
      ),
    );
  }

  /// 填满所有必填项（含时间），让 `save()` 能通过校验。
  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tapAt(
      tester,
      find.descendant(
        of: find.byKey(const Key('publish-type-selector')),
        matching: find.text('失物'),
      ),
    );
    await tapAt(tester, find.byKey(const Key('publish-category-daily')));
    await tapAt(tester, find.byKey(const Key('publish-title-field')));
    await tester.enterText(
      find.byKey(const Key('publish-title-field')),
      '一个水杯',
    );
    await tester.enterText(
      find.byKey(const Key('publish-location-field')),
      '图书馆三楼',
    );
    await tester.enterText(
      find.byKey(const Key('publish-contact-field')),
      '13800000000',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tapAt(tester, find.byKey(const Key('publish-time-picker')));
    await confirmPicker(tester);
    await confirmPicker(tester);
  }

  testWidgets('点「加一张」能从相册选图并显示缩略图', (WidgetTester tester) async {
    picker.paths.add(<String>[fakeSource('cup.jpg')]);
    await pumpForm(tester);

    expect(find.byKey(const Key('publish-photo-add')), findsOneWidget);
    expect(find.text('已选 0 / 9 张，点右上角的 × 可以删掉。'), findsNothing);

    await addPhoto(tester);

    // 图片已经收进图片目录（这里是内存里的记账），界面上显示的就是它。
    expect(storedNames(), hasLength(1));
    expect(picker.sources, <PhotoPickSource>[PhotoPickSource.gallery]);
    expect(find.byKey(const Key('publish-photo-0')), findsOneWidget);
    expect(find.text('已选 1 / 9 张，点右上角的 × 可以删掉。'), findsOneWidget);
  });

  testWidgets('拍照入口走的是相机来源', (WidgetTester tester) async {
    picker.paths.add(<String>[fakeSource('shot.jpg')]);
    await pumpForm(tester);

    await addPhoto(tester, fromCamera: true);

    expect(picker.sources, <PhotoPickSource>[PhotoPickSource.camera]);
    expect(find.byKey(const Key('publish-photo-0')), findsOneWidget);
  });

  testWidgets('用户取消选择时界面不变、也不报错', (WidgetTester tester) async {
    await pumpForm(tester);
    // picker 队列是空的 → 抛 PhotoPickCanceled，等同用户点了取消。
    await addPhoto(tester);

    expect(find.byKey(const Key('publish-photo-0')), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(storedNames(), isEmpty);
  });

  testWidgets('选择失败时提示原因，不往界面上抛异常', (WidgetTester tester) async {
    await pumpForm(tester, customPicker: _FailingPhotoPicker());

    await addPhoto(tester);

    expect(find.text('相册被系统拦住了。'), findsOneWidget);
    expect(storedNames(), isEmpty);
  });

  testWidgets('多选超过 9 张时只留下前 9 张并提示', (WidgetTester tester) async {
    picker.paths.add(<String>[
      for (int i = 0; i < 10; i++) fakeSource('p$i.jpg'),
    ]);
    await pumpForm(tester);

    await addPhoto(tester);

    expect(storedNames(), hasLength(9));
    expect(find.byKey(const Key('publish-photo-8')), findsOneWidget);
    expect(find.byKey(const Key('publish-photo-9')), findsNothing);
    expect(find.text('最多只能带 9 张图片，已忽略多选的 1 张。'), findsOneWidget);
    // 满了以后入口就收起来了。
    expect(find.byKey(const Key('publish-photo-add')), findsNothing);
  });

  testWidgets('删掉刚选的图会连盘上的文件一起删', (WidgetTester tester) async {
    picker.paths.add(<String>[fakeSource('temp.jpg')]);
    await pumpForm(tester);
    await addPhoto(tester);
    expect(storedNames(), hasLength(1));

    await tapAt(tester, find.byKey(const Key('publish-photo-remove-0')));

    expect(find.byKey(const Key('publish-photo-0')), findsNothing);
    expect(storedNames(), isEmpty);
  });

  testWidgets('在表单里选了图就算有未保存改动', (WidgetTester tester) async {
    picker.paths.add(<String>[fakeSource('dirty.jpg')]);
    final GlobalKey<PostFormState> key = PostForm.createKey();
    await pumpForm(tester, formKey: key);
    expect(key.currentState!.isDirty, isFalse);

    await addPhoto(tester);

    expect(key.currentState!.isDirty, isTrue);
  });

  testWidgets('没有图片目录时提示不支持，而不是崩掉', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PostForm(onSaved: (_) {})),
      ),
    );

    await tapAt(tester, find.byKey(const Key('publish-photo-add')));

    expect(find.text('当前环境不支持选择图片。'), findsOneWidget);
  });

  testWidgets('保存时图片跟着信息一起落库，会话随之结束', (WidgetTester tester) async {
    picker.paths.add(<String>[fakeSource('saved.jpg')]);
    final GlobalKey<PostFormState> key = PostForm.createKey();
    await pumpForm(tester, formKey: key);

    await addPhoto(tester);
    await fillRequiredFields(tester);
    final String filename = storedNames().single;

    final ItemPost? saved = key.currentState!.save();

    expect(saved, isNotNull);
    expect(saved!.imagePaths, <String>[filename]);
    // 保存后图片归信息所有：会话不再保护它，靠数据库里的引用留住它。
    expect(photoStore.activeSessionCount, 0);
    expect(await photoStore.reconcile(<String>{filename}), isEmpty);
    expect(storedNames(), <String>[filename]);
  });

  testWidgets('清空表单会回到初值并把本次选的图删掉', (WidgetTester tester) async {
    picker.paths.add(<String>[fakeSource('reset.jpg')]);
    final GlobalKey<PostFormState> key = PostForm.createKey();
    await pumpForm(tester, formKey: key);

    await addPhoto(tester);
    expect(storedNames(), hasLength(1));

    key.currentState!.reset();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('publish-photo-0')), findsNothing);
    expect(storedNames(), isEmpty);
  });

  testWidgets('还原编辑时新加的图会被丢掉、原有的图留着', (WidgetTester tester) async {
    // 这条信息本来就带一张图。
    imageFiles.files['existing.jpg'] = r'C:\laf-picked\existing.jpg';
    final ItemPost post = ItemPost(
      id: 'p1',
      type: PostType.lost,
      title: '旧信息',
      category: ItemCategory.daily,
      location: '食堂',
      eventTime: DateTime(2026, 5, 1, 12),
      contact: '13800000000',
      createdAt: DateTime(2026, 5, 1, 12),
      imagePaths: const <String>['existing.jpg'],
      isMine: true,
    );
    picker.paths.add(<String>[fakeSource('new.jpg')]);
    final GlobalKey<PostFormState> key = PostForm.createKey();
    await pumpForm(tester, initial: post, formKey: key);

    await addPhoto(tester);
    expect(storedNames(), hasLength(2));

    key.currentState!.reset();
    await tester.pump(const Duration(milliseconds: 300));

    // 还原回「刚打开时」：只剩原有的那张，本次新加的从盘上也删掉了。
    expect(find.byKey(const Key('publish-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('publish-photo-1')), findsNothing);
    expect(storedNames(), <String>['existing.jpg']);
    expect(key.currentState!.isDirty, isFalse);
  });

  testWidgets('编辑已有信息时会带出原来的图片', (WidgetTester tester) async {
    // 造一张已经归这条信息所有的图（库里只存文件名）。
    imageFiles.files['existing.jpg'] = r'C:\laf-picked\existing.jpg';
    final ItemPost post = ItemPost(
      id: 'p1',
      type: PostType.lost,
      title: '旧信息',
      category: ItemCategory.daily,
      location: '食堂',
      eventTime: DateTime(2026, 5, 1, 12),
      contact: '13800000000',
      createdAt: DateTime(2026, 5, 1, 12),
      imagePaths: const <String>['existing.jpg'],
      isMine: true,
    );

    final GlobalKey<PostFormState> key = PostForm.createKey();
    await pumpForm(tester, initial: post, formKey: key);

    expect(find.byKey(const Key('publish-photo-0')), findsOneWidget);
    expect(find.text('已选 1 / 9 张，点右上角的 × 可以删掉。'), findsOneWidget);
    // 这条信息本来就有图：没动它就不算「有改动」。
    expect(key.currentState!.isDirty, isFalse);
  });
}
