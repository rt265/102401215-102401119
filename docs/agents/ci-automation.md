# CI 自动化工作流（.github/workflows）

本轮（GitHub Actions 接入）新增的内容。

## 目标

用 GitHub Actions 覆盖 **Build / Test / Release** 三条线，把本机那套
`flutter pub get && flutter analyze && flutter test` 与 Android / iOS 构建搬到 CI 上。

## 工作流一览

| 文件 | 名称 | 触发 | 做什么 |
| --- | --- | --- | --- |
| [.github/workflows/test.yml](../../.github/workflows/test.yml) | Test | push 到 `main`、任何 PR、手动 | Ubuntu：装系统 SQLite → `flutter pub get` → `flutter analyze` → `flutter test --coverage` → 传 `coverage/lcov.info`（artifact `coverage-lcov`） |
| [.github/workflows/build.yml](../../.github/workflows/build.yml) | Build | push 到 `main`、任何 PR、手动 | 两个 job：Android（Ubuntu + JDK 21）出 release APK；iOS（macOS）`flutter build ios --release --no-codesign` 出 `Runner-unsigned.zip` |
| [.github/workflows/release.yml](../../.github/workflows/release.yml) | Release | 推 `v*` 标签、手动触发 | 解析版本 → Android 出分 ABI 的 release APK → iOS 出不签名 zip → 全部挂到对应 GitHub Release（README 的下载入口） |

三个工作流都用 `concurrency` 取消同一 ref 上未跑完的旧任务；`build.yml` / `test.yml`
只申请 `contents: read`，只有 `release.yml` 的 `publish` job 需要 `contents: write`。

## 关键设计

### 1. runner 上没有本机专用的 Gradle 配置，构建前就地剥掉

仓库里的 `android/gradle.properties` 与 `android/gradle/wrapper/gradle-wrapper.properties`
带着**只在本机成立**的三项配置，直接拿到 GitHub 托管 runner 上会把构建打死：

| 配置 | 本机为什么这样写 | 在 CI 上会怎样 | CI 的处置 |
| --- | --- | --- | --- |
| `systemProp.http(s).proxyHost/Port=127.0.0.1:7890` | 本机直连 Google / GitHub 不稳，走本地代理 | runner 上没有这个代理，Gradle 拉依赖全超时 | `grep -v` 删掉这几行 |
| `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G` | 本机内存充裕 | runner 只有 7GB 内存，daemon 起不来 | 改成 `-Xmx4g -XX:MaxMetaspaceSize=1G` |
| `distributionUrl=…mirrors.cloud.tencent.com/gradle/gradle-9.3.1-all.zip` | 本机下 Gradle 发行包走腾讯云镜像 | runner 上直连 `services.gradle.org` 更快 | 换回官方源，并改用体积更小的 `-bin` 包 |

**只改 CI 工作区里的副本**，仓库文件不动 —— 本机开发仍然走代理 + 镜像。
以后如果想让仓库配置干净些，可以把代理与镜像移到用户级 `~/.gradle/gradle.properties`
（不过 `org.gradle.jvmargs` 的项目级配置优先级更高，仍要单独处理）。

### 2. `sqlite3` 用的是 `source: system`，所以 CI 要先装系统 SQLite

`pubspec.yaml` 里 sqlite3 配了 `hooks.user_defines.sqlite3.source: system`（本机网络到
GitHub 不稳，改用各平台自带库，见 [basic-info.md](./basic-info.md)）。
Linux 上这意味着运行期 `dlopen("libsqlite3.so")`，而 Ubuntu runner 默认不带开发包，
**`test.yml` 与 Android 构建 job 都会先 `apt-get install libsqlite3-dev`**，否则
`sqlite_storage_test.dart` / `photo_storage_test.dart` 这类用例会以
「Failed to load dynamic library」失败。

### 3. Android 签名：配了 Secrets 才启用

`android/app/build.gradle.kts` 改成「**`android/key.properties` 存在才启用正式签名**」，
不存在时照旧用 debug 密钥 —— 本机与 CI 的默认行为与改动前完全一致。

要出可上架的产物，在仓库 Settings → Secrets and variables → Actions 配四个 Secret：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore 的 base64，本机生成：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-keystore.jks"))` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 别名 |
| `ANDROID_KEY_PASSWORD` | 别名密码 |

四个都配齐时，`release.yml` 会把 keystore 落到 `android/app/release-keystore.jks`，
并生成 `android/key.properties`（`storeFile` 用绝对路径，避免 `file()` 相对谁解析的歧义）；
缺任何一个就发一条 `::warning::` 并使用 debug 签名（产物仅供测试，不能上架）。

**密码那两个 Secret 一定要填成同一个值**：JDK 9 之后 `keytool` 默认生成 PKCS12 格式的
keystore，PKCS12 里条目密码必须等于库密码，`ANDROID_KEY_PASSWORD` 与
`ANDROID_KEYSTORE_PASSWORD` 不一致时构建会在 `:app:packageRelease` 报
`KeytoolException: Failed to read key … Get Key failed: Given final block not properly padded.`
（本地验证这个分支时就踩到了这个坑，改成一模一样的密码即可）。

`key.properties`、`*.jks` 已被 `android/.gitignore` 忽略，不会误提交。

### 4. iOS 的边界

runner 上没有 Apple 开发者证书，所以 iOS 只做 **`--no-codesign` 的构建验证**，
产物是 `Runner.app` 打的 zip。**装不到普通用户手机上**；要出可分发的 ipa，
需要证书 + provisioning profile，把 `release.yml` 的 iOS job 换成
`flutter build ipa --export-options-plist=...` 即可（仓库目前没有证书）。

### 5. 版本号口径

- 标签触发：`v1.0.0` → `--build-name=1.0.0`；
- 手动触发且填了 tag 输入：同上，并创建 / 更新该标签的 Release；
- 手动触发、没填 tag：用 `pubspec.yaml` 的 `version:`，**只出 artifact 不发 Release**；
- `--build-number` 一律用 `github.run_number`（单调递增，当 `versionCode` 用）。

标签与 `pubspec.yaml` 版本不一致时只会发 `::warning::`，不中断发布（产物按标签版本命名）。

## 本轮验证到什么程度

| 内容 | 验证方式 | 结果 |
| --- | --- | --- |
| `android/app/build.gradle.kts` 改动后 Android release 构建仍可用（无 `key.properties` → debug 签名） | 本机 `flutter build apk --release --split-per-abi` | ✅ 出 3 个分 ABI APK |
| 正式签名分支（有 `key.properties` → release 签名） | 本机用临时 keystore 生成 `key.properties` 后构建，再 `apksigner verify --print-certs` | ✅ APK 签名者为该临时证书；随后已删除 `key.properties` 与临时 keystore |
| 三个工作流在 GitHub 上实际运行 | — | ✅ 已跑通 |

`flutter analyze` / `flutter test` 本轮没有重跑（改动只碰了 CI 配置与 Android 构建脚本，
没动 `lib/` 与 `test/`）。

## 尚未验证 / 待办

- 未加 `dart format` 检查：本机 Dart 3.13 的 formatter 是新排版风格，全量格式化和仓库
  既有代码风格不一致，要开就得单独一轮、单独提交（见 [basic-info.md](./basic-info.md)）。
- `org.gradle.jvmargs` 等项目级配置会盖过用户级 `~/.gradle/gradle.properties`，
  清理方式目前是「CI 里就地剥掉」，长期更干净的做法是把本机专用的代理 / 镜像配置
  搬出仓库（本轮没动，以免影响本机构建）。
