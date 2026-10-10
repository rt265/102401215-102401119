import 'package:flutter/material.dart';

/// 全局 Material 3 主题。
///
/// 三大主界面与各次级界面统一从这里取色，避免页面里硬编码颜色。
///
/// 整套配色由**一颗种子色**派生（`ColorScheme.fromSeed`），用户能在外观界面
/// 换这颗种子（见 `lib/theme/theme_seeds.dart` 与 `SettingsStore.themeSeed`），
/// 所以 [light] / [dark] 都收一个种子色参数：界面层只把用户选的颜色传进来，
/// 派生规则留在这里一处。
abstract final class AppTheme {
  /// 品牌种子色，Material 3 会据此派生整套明 / 暗配色。
  ///
  /// 也是用户没改过主题色时的默认值（与 [ThemeSeeds.defaultColor] 一致）。
  static const Color seedColor = Color(0xFF00695C);

  static ThemeData light({Color seed = seedColor}) =>
      _build(Brightness.light, seed);

  static ThemeData dark({Color seed = seedColor}) =>
      _build(Brightness.dark, seed);

  /// Builds the Material 3 scheme while keeping the user's selected color as
  /// the actual primary color. `fromSeed` intentionally adjusts its input to
  /// a tonal palette, which makes the applied color look different from the
  /// color selected in the appearance page.
  static ColorScheme colorScheme({
    required Brightness brightness,
    Color seed = seedColor,
  }) {
    final ColorScheme generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final bool useDarkForeground = seed.computeLuminance() > 0.5;

    return generated.copyWith(
      primary: seed,
      onPrimary: useDarkForeground ? Colors.black : Colors.white,
    );
  }

  static ThemeData _build(Brightness brightness, Color seed) {
    final ColorScheme scheme = colorScheme(
      brightness: brightness,
      seed: seed,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      // 宽屏（平板 / 横屏）上主界面导航换成侧边栏（见 MainShell 与
      // AppLayout.navigationRailBreakpoint）。配色与底部导航栏保持一致，
      // 同一套界面在两种尺寸下只是换个摆法，不该跟着换颜色。
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        // 三个标签只有两个字，全显示出来最省心——宽屏上没必要再藏。
        labelType: NavigationRailLabelType.all,
      ),
    );
  }
}
