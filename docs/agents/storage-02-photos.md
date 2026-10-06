# 本地后端事项 2：支持照片存储

对应 `docs/agents/basic-info.md` 中「然后是本地后端建设」的第 2 项：**支持照片存储**，
补上的正是「尚未开始的技术工作：图片选择与展示」。

## 本轮目标

「每个信息应当包含以下内容」里的最后一项是**图片（选填）**，但到上一轮为止它只是个占位：
`PostForm` 里是 `_ImagePlaceholder`（「暂不支持选择图片」），卡片与详情页统一用分类图标。
本轮把这条链路接通：

- 表单里能**从相册选图 / 拍照**，能删、能看缩略图，最多 9 张；
- 图片**真正落盘**（应用私有目录），库里只记文件名，重开应用还在；
- 卡片显示首图 + 张数角标，详情页显示可左右滑动的轮播；
- 信息被删 / 图片被摘掉时，**盘上的文件跟着清掉**，不在私有目录里留垃圾。

范围：不碰远端（本项目本地闭环）、不做图片编辑 / 裁剪 / 压缩以外的处理、不做相册权限引导页。

## 核心决策（后继 Agent 改这块之前先读）

| 决策 | 理由 |
| --- | --- |
| 库里 `posts.image_paths` **只存文件名**（如 `1791294449997-1.jpg`），不存绝对路径 | iOS 的应用目录**每次安装都会变**，存下来的绝对路径重装后指向不存在的文件。文件名 ↔ 绝对路径的换算收在 `ImageFileStore.resolve` / `filenameFor` 一处 |
| **不改表结构、不升库版本**（`DbSchema.version` 仍是 1、`_upgrade` 仍是空实现） | 该列本来就是 `TEXT NOT NULL` + JSON 数组，换成语义「文件名」不需要改 DDL。旧数据（万一存过绝对路径）由启动时的迁移就地改写 |
| 图片目录 = `databaseFactory.getDatabasesPath()` 下的 `photos/` | 与数据库同生共死，备份 / 清理都在一处；**不引入 `path_provider`**（少一个依赖） |
| 目录路径**作为参数注入**（应用传数据库目录，测试传临时目录 / 内存实现） | `PhotoStore` / `ImageFileStore` 完全不认 Flutter，纯 Dart 就能测 |
| 新依赖只加 `image_picker`，且**只出现在 `lib/services/photo_picker.dart`** | 界面通过 `PhotoPicker` 抽象拿图，测试可以整个换掉，不必碰平台通道 |
| 清孤儿文件放在**启动时**（`PostStore.load()` 之前） | 运行中删文件要处理「正被别的信息引用」这类竞态；启动时一次性对齐最简单 |
| 表单**新选的**图由 `FormImageSession` 追踪，`commit()` / `discard()` 决定归属 | 用户选完图又清空 / 直接返回时，那些图还不属于任何信息——记在会话里，discard 时删掉，`reconcile` 也把它们算作受保护集合 |
| 图片以**绝对路径**下发到界面（`PostStore` 解析后放进 `ItemPost.imagePaths`） | `Image.file` 只吃绝对路径。在 Store 一处解析，卡片 / 详情 / 表单三个界面都拿到能直接用的路径，改动面最小 |
| 图片显示不出来是**正常状态**，兜底成分类图标而不是报错 | 用户可能在系统相册里删了原图，或数据是「只有文件名、文件已不在」的迁移残留。`PostPhotoView` 的 `errorBuilder` 统一降级 |

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 文件仓库 | `lib/data/image_file_store.dart`：`ImageFileStore` 接口 + `FileImageFileStore`（真实读写）。落盘、起名、删文件、路径换算都在这里 |
| 图片仓库 | `lib/data/photo_store.dart`：`PhotoStore`（会话、迁移、清理）+ `PhotoScope` + `FormImageSession` + `PhotoMigrationResult` |
| 相册接入 | `lib/services/photo_picker.dart`：`PhotoPicker` 接口 + `DevicePhotoPicker`（`image_picker` 的唯一落点）+ `PhotoPickerScope` + `PhotoPickCanceled` / `PhotoPickFailure` |
| 图片显示 | `lib/widgets/post_photo.dart`：`PostPhotoView`（缩略图 / 轮播页，带兜底）、`imageFilenamesOf()`、`resolvePhotoPath()` |
| 表单选图 | `lib/widgets/post_form.dart`：`_PhotoField` 网格 + `_AddTile`，选图 / 删图 / 来源选择 / 9 张上限 |
| 卡片与详情 | `lib/widgets/post_card.dart` 的 `_Thumbnail` 改成首图 + 张数角标；`lib/pages/post_detail_page.dart` 的 `_Hero` 改成 `PageView` 轮播 + 页码 |
| 启动装配 | `lib/main.dart`：开图片目录 → **先迁移** → **再清孤儿** → 注入 `PhotoScope` |
| 平台配置 | `android/app/build.gradle.kts`（`minSdk` 抬到 24）、`ios/Runner/Info.plist`（相机 / 相册用途说明） |
| 依赖 | `image_picker: ^1.2.4`（已 `flutter pub get`） |

## 文件清单

```
lib/
  data/image_file_store.dart   新增：ImageFileStore 接口 + FileImageFileStore
  data/photo_store.dart        新增：PhotoStore / PhotoScope / FormImageSession
  services/photo_picker.dart   新增：PhotoPicker 抽象 + image_picker 实现
  widgets/post_photo.dart      新增：PostPhotoView 与路径换算
  data/post_store.dart         改动：注入 PhotoStore、解析图片绝对路径、删信息时删图
  widgets/post_form.dart       改动：_ImagePlaceholder → _PhotoField
  widgets/post_card.dart       改动：缩略图显示首图 + 张数角标
  pages/post_detail_page.dart  改动：_Hero 改成多图轮播
  main.dart                    改动：开图片目录、迁移、清理、注入 PhotoScope

test/
  photo_storage_test.dart      新增：13 个用例（文件层 + 数据库配合 + 坏数据容错）
  post_form_photo_test.dart    新增：12 个用例（表单选图全流程）
  publish_page_test.dart       改动：表单项文案「图片」→「图片（最多 9 张）」

android/app/build.gradle.kts   改动：minSdk = maxOf(flutter.minSdkVersion, 24)
ios/Runner/Info.plist          改动：NSCameraUsageDescription / NSPhotoLibraryUsageDescription
pubspec.yaml                   改动：+ image_picker
```

## 数据流

```
选图（相册 / 拍照）
  DevicePhotoPicker.pick() → 系统临时目录里的绝对路径
        ↓
FormImageSession.savePicked() → FileImageFileStore.save()
  复制进 <databases>/photos/<时间戳>-<序号>.<ext>，删掉临时文件，返回文件名
        ↓
表单 _imagePaths（文件名）→ 保存时写进 ItemPost.imagePaths
        ↓
PostStore.addPost()/updatePost() → SqliteItemRepository → posts.image_paths（JSON 文件名数组）
        ↓
读回：PostStore._resolveImages() → PhotoStore.resolve() → 绝对路径 → 界面 Image.file
```

删除路径：

```
信息被删 → PostStore.removePost()：先记下该信息引用的文件名 → 删库行 → photoStore.deleteFiles()
表单草稿 → FormImageSession.discard()（重置 / 退出编辑页 / dispose）→ deleteFiles()
启动兜底 → applyPendingUpdates（迁移）→ reconcile（删没被任何信息引用的文件）
```

**顺序不能反**：迁移必须在 `reconcile` 之前。反过来的话，刚被搬进图片目录、还没写回库的文件会被当成孤儿删掉。

## 已知限制 / 后续可做

- 选图时用的是 `image_picker` 的 `maxWidth/maxHeight: 2048, imageQuality: 88`：真机上会重新编码一次。
  这是有意为之（控制单张体积），但**没有做「原图 vs 压缩」的可选项**。
- 孤儿清理只在启动时跑一次。运行中如果某条信息被删且 `deleteFiles` 失败（文件被系统占用），
  那个文件要等下次启动才被清掉——这属于兜底，不是漏洞。
- 迁移把绝对路径改成文件名时，**优先沿用原名**；图片目录里已经有同名文件（或原名不能当文件名）才退回唯一名。
  这里用了「先查存在性再复制」，`File.copy` 会静默覆盖，不查就会盖掉另一条信息的图。
- 相册多选上限由 `image_picker` 与系统决定，我们只截前 9 张并提示忽略了剩余几张。

## 本轮踩到的坑（有价值，别重踩）

1. **`testWidgets` 的虚拟时间不驱动真实文件 I/O。**
   `Directory.systemTemp.createTemp()` / `File.copy()` 这类调用在 `testWidgets` 体内 `await` 会**永远挂着**
   （实测：`createTemp` 后连推 5 次 `pump(100ms)`，回调仍未执行）。所以：
   - 真实文件读写的测试用普通 `test()`（`photo_storage_test.dart` 就是这样）；
   - 需要驱动 widget 的测试**必须在 `tester.runAsync()` 里做 I/O**，或者干脆不碰磁盘——
     `test/post_form_photo_test.dart` 给 `PhotoStore` 注入了一个内存版 `ImageFileStore`。
   这次卡死留下的 dart / flutter_tester 子进程还占住了 Android 构建的 Kotlin 增量缓存
   （见下一条），代价很高。

2. **`late final X = f(otherField)` 是「第一次读时才求值」，不是「构造时求值」。**
   `_initialImagePaths` 原本写成 `late final List<String> _initialImagePaths = List<String>.of(_imagePaths);`，
   而第一次读它的地方正是 `reset()`——那时 `_imagePaths` 已经被用户选过图了，
   于是「清空 / 还原」变成「还原到你刚选的那张」，图删不掉。改成在字段初始化式里按
   `widget.initial` 重算（不再引用 `_imagePaths`）。凡是「初始快照」类字段，都要留意这一点。

3. **测试里拼 `posts.image_paths` 必须用 `jsonEncode`**，不要手写 `'["$path"]'`：
   Windows 路径带反斜杠，手拼出来的不是合法 JSON，会被 `decodeImagePaths` 容错成空列表，
   表现为迁移用例「莫名其妙没搬」。这个容错是给坏数据准备的，别用它掩盖测试自身的错。

4. **`flutter test` 被杀不会杀掉它派生的 `flutter_tester` / `dart` 子进程**，
   残留进程会占住 `build/<plugin>/kotlin/.../caches-jvm/` 的文件句柄，
   之后 Android 构建报：
   ```
   Execution failed for task ':image_picker_android:compileDebugKotlin'.
   > java.lang.Exception: Could not close incremental caches in .../caches-jvm/jvm/kotlin:
     class-fq-name-to-source.tab, source-to-classes.tab, internal-name-to-source.tab
   ```
   这是**文件锁问题，不是代码问题**。处置：`Get-Process dart,flutter_tester,java` 找出残留进程 →
   停掉 Gradle daemon 与 Kotlin `KotlinCompileDaemon` → 删掉 `build/<plugin>/kotlin` 目录 → 重新构建即可。
   本机 `android\gradlew.bat --stop` 不可用（`JAVA_HOME` 指向一个不存在的 JDK 目录），
   构建实际使用 Android Studio 自带 JBR（`C:\Program Files\Android\Android Studio\jbr`）。

5. **`image_picker` 的 Android 实现要求 `minSdk >= 24`**
   （`image_picker_android-0.8.13+25/android/build.gradle.kts` 里写死 `minSdk = 24`），
   所以 `android/app/build.gradle.kts` 要抬到 `maxOf(flutter.minSdkVersion, 24)`。

## 验证

- `flutter analyze`：No issues found!
- `flutter test`：**103 个用例全部通过**（含既有 91 个未回归）。
  新增覆盖：文件名 / 绝对路径换算、落盘删源不重名、源文件不存在抛 `PathNotFoundException`、
  孤儿清理只删没引用的、迁移幂等且优先沿用原名、会话中的草稿图不被清理、
  相册选图 / 拍照 / 取消 / 失败 / 超 9 张截断、删图连盘一起删、选图算 `isDirty`、
  保存后会话结束、清空与还原都回到初值并删掉本次新选的图、编辑带出原有图片。
- 未做：真机 / 模拟器上跑一遍选图（依赖用户手动验证）。
