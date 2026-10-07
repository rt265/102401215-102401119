# 修复：Android 构建失败

用户报告「图片的本地保存现在还没有跑通，无法构建」。经排查，构建失败与图片保存代码无关，
是两个环境层面的问题叠加导致 `flutter build apk --debug` 一直失败。

## 根因与修复

### 1. Kotlin 增量编译跨盘符 bug

**现象**：`:image_picker_android:compileDebugKotlin` 任务失败，报
`Could not close incremental caches in .../caches-jvm/jvm/kotlin: class-fq-name-to-source.tab, ...`。

**真正原因**（此前 basic-info.md 坑 4 误诊为「残留进程占文件锁」）：

Kotlin 增量编译关闭缓存时，`RelocatableFileToPathConverter.toPath` 用 `kotlin.io.FilesKt.toRelativeString`
计算源文件与项目目录的相对路径。源文件和项目目录的路径跨盘符，`toRelativeString` 抛
`IllegalArgumentException: this and base files have different roots`，导致缓存无法关闭，
整个编译任务失败。

某次错误的完整堆栈关键行：
```
Suppressed: java.lang.IllegalArgumentException: this and base files have different roots:
  C:\...\image_picker_android-0.8.13+25\...\Messages.kt and D:\...\lost-and-found\android.
  at kotlin.io.FilesKt__UtilsKt.toRelativeString(Utils.kt:119)
  at ...RelocatableFileToPathConverter.toPath(RelocatableFileToPathConverter.kt:24)
```

**修复**：`android/gradle.properties` 加 `kotlin.incremental=false`，禁用增量编译绕过该 bug。
代价是 Kotlin 全量编译稍慢，但项目 Kotlin 代码量小，影响可忽略。

### 2. sqlite3 原生库下载超时

**现象**：禁用增量编译后，构建卡在 `:app:compileFlutterBuildDebug`，报
`Target build_hooks failed` / `HttpException: 信号灯超时时间已到`。

**原因**：`sqlite3` 3.5.2 默认通过 Dart hooks 从 GitHub release 下载预编译原生库
（`libsqlite3.arm.android.so` 等）。`gradle.properties` 里配的 `127.0.0.1:7890` 代理只对
Gradle 生效，Dart hooks runner 的 HTTP 请求不走该代理，直连 GitHub 超时。

**修复**：`pubspec.yaml` 加 `hooks: user_defines: sqlite3: source: system`，改用各平台系统自带的
SQLite 库，不再下载。系统库编译选项可能与预编译版略有差异（如缺少 FTS5/RTREE），但本项目用到的
基本 SQL 功能不受影响。

## 改动文件

| 文件 | 改动 |
| --- | --- |
| `android/gradle.properties` | 加 `kotlin.incremental=false`（绕过跨盘符 bug） |
| `pubspec.yaml` | 显式依赖 `sqlite3: ^3.5.2`；加 `hooks: user_defines: sqlite3: source: system`（用系统库，不下载） |

## 验证

- `flutter analyze`：No issues found!
- `flutter build apk --debug`：**成功**，`√ Built build\app\outputs\flutter-apk\app-debug.apk`（144.5 MB）

## 后续注意

- `kotlin.incremental=false` 是针对本机 C:/D: 跨盘符环境的 workaround。若后续把项目或 Pub Cache
  挪到同一盘符，可以去掉这行恢复增量编译。
- `source: system` 在 Android 上 `dlopen("libsqlite3.so")`，依赖系统自带该库。Android 各版本均有。
  Windows 上加载 `winsqlite3.dll`（Win10+ 自带）。
