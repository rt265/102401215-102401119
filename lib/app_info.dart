/// 应用自己的固定信息（「设置 → 应用信息」与开源许可页用到）。
///
/// [version] / [buildNumber] 与 `pubspec.yaml` 里的 `version: 1.0.0+1` 手工保持一致：
/// 改版本号时记得两处一起改。
abstract final class AppInfo {
  /// 应用名称，与 `MaterialApp.title`、「我的」界面里的名字一致。
  static const String name = '速拾失';

  /// 版本号（`pubspec.yaml` 里 `+` 之前的部分）。
  static const String version = '1.0.1';

  /// 构建号（`pubspec.yaml` 里 `+` 之后的部分）。
  static const String buildNumber = '2';

  /// 展示用的版本：`1.0.0（1）`。
  static String get versionLabel => '$version（$buildNumber）';
}
