import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'settings_repository.dart';

/// 应用设置里那些落库的设置项的名字。
///
/// 名字是库里 `setting_name` 的值，改名字等于丢掉老数据，所以定下来就别动。
abstract final class SettingNames {
  /// 外观：主题模式，值是 `ThemeMode.name`（`system` / `light` / `dark`）。
  static const String themeMode = 'theme_mode';

  /// 外观：主题种子色，值是 `#AARRGGBB`（见 [encodeColor]）。
  static const String themeSeed = 'theme_seed';
}

/// 应用设置仓库。
///
/// 与 `PostStore` / `UserStore` 一个套路：内存里留一份当前设置给界面**同步**读取，
/// 有仓储时每次改动都顺手写进本地库，启动时用 [load] 读回上次的选择。
///
/// 存的是 Flutter 自带的 [ThemeMode]，不另建一套自己的枚举：主题最终要交给
/// `MaterialApp.themeMode`，中间多一层映射只会多一处对不上的机会。
class SettingsStore extends ChangeNotifier {
  /// [repository] 为空时是纯内存实现（测试与预览用）；
  /// [themeMode] / [themeSeed] 是读库之前的初值，配合 [repository] 使用时以库里的为准。
  SettingsStore({
    SettingsRepository? repository,
    ThemeMode themeMode = ThemeMode.system,
    Color themeSeed = AppTheme.seedColor,
  }) // 不能写成 `this._repository`：命名参数用私有写法后，`main()` 与测试就没法用
    // `repository:` 传参了。
    // ignore: prefer_initializing_formals
    : _repository = repository,
       // ignore: prefer_initializing_formals
       _themeMode = themeMode,
       // ignore: prefer_initializing_formals
       _themeSeed = themeSeed;

  final SettingsRepository? _repository;

  ThemeMode _themeMode;

  Color _themeSeed;

  /// 外观主题：跟随系统 / 浅色 / 深色，默认跟随系统。
  ThemeMode get themeMode => _themeMode;

  /// 外观主题的**种子色**：整套 Light / Dark 配色都由它派生，默认品牌青。
  ///
  /// 只存这一颗种子，不存整套配色：派生规则留在 `AppTheme`，
  /// 换配色算法时用户的选择仍然有效。
  Color get themeSeed => _themeSeed;

  /// 从本地库读回设置。
  ///
  /// 启动时调一次（`main()`）；纯内存实现下什么都不做。
  /// 库里没存过、或者存着认不出来的值时，保持当前值（默认跟随系统 + 品牌青）。
  Future<void> load() async {
    final SettingsRepository? repository = _repository;
    if (repository == null) {
      return;
    }

    final ThemeMode? storedMode = parseThemeMode(
      await repository.read(SettingNames.themeMode),
    );
    final Color? storedSeed = parseColor(
      await repository.read(SettingNames.themeSeed),
    );

    // 一次读完再通知一遍：两项设置分别 notify 会让界面白重建一次。
    bool changed = false;
    if (storedMode != null && storedMode != _themeMode) {
      _themeMode = storedMode;
      changed = true;
    }
    if (storedSeed != null && storedSeed != _themeSeed) {
      _themeSeed = storedSeed;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// 改外观主题。
  ///
  /// 先改内存并通知界面（立刻换肤），再落库；写库出错会从这个 Future 抛出。
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();

    final SettingsRepository? repository = _repository;
    if (repository != null) {
      await repository.write(SettingNames.themeMode, mode.name);
    }
  }

  /// 改主题种子色（外观界面里挑的颜色）。
  ///
  /// 与 [setThemeMode] 一样：先改内存立刻换肤，再落库。
  Future<void> setThemeSeed(Color seed) async {
    if (seed == _themeSeed) {
      return;
    }
    _themeSeed = seed;
    notifyListeners();

    final SettingsRepository? repository = _repository;
    if (repository != null) {
      await repository.write(SettingNames.themeSeed, encodeColor(seed));
    }
  }
}

/// 把库里存的字符串读回 [ThemeMode]。
///
/// 认不出来的值（更早版本写的、被手改过的）当作没存过，返回 `null`：
/// 一项设置读不懂，不该让整个应用起不来。
ThemeMode? parseThemeMode(String? stored) {
  for (final ThemeMode mode in ThemeMode.values) {
    if (mode.name == stored) {
      return mode;
    }
  }
  return null;
}

/// 把颜色编成落库的字符串：`#AARRGGBB`。
///
/// 不写 `Color.value` 那个十进制整数：键值表的 `setting_value` 是给人看的文本列，
/// 十六进制与设计稿 / 主题文件里的写法一致，出问题直接查库就能看懂。
String encodeColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// 把 [encodeColor] 写下的字符串读回颜色。
///
/// 同样按「认不出来就当没存过」处理（返回 `null`），并且额外挡掉全透明的值：
/// 种子色完全透明的话 `ColorScheme.fromSeed` 派生出来的界面会是灰的，
/// 那不是用户挑得到的颜色，更像是坏数据。
Color? parseColor(String? stored) {
  final String text = stored?.trim() ?? '';
  if (!text.startsWith('#')) {
    return null;
  }
  final int? value = int.tryParse(text.substring(1), radix: 16);
  if (value == null || value <= 0xFFFFFF) {
    // 缺 A 通道（6 位）或全透明（0x00______）都不认。
    return null;
  }
  return Color(value);
}

/// 把 [SettingsStore] 沿 widget 树下发。
///
/// 与 `PostScope` / `UserScope` 一样用 [InheritedNotifier]：设置变化后依赖它的
/// 界面（设置界面本身）自动重建。
class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({
    super.key,
    required SettingsStore store,
    required super.child,
  }) : super(notifier: store);

  /// 取当前设置仓库并订阅它的变化。
  static SettingsStore of(BuildContext context) {
    final SettingsScope? scope = context
        .dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, '未找到 SettingsScope：页面需要放在 LostAndFoundApp 之下。');
    return scope!.notifier!;
  }
}
