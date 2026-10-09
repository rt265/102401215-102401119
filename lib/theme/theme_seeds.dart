import 'package:flutter/material.dart';

/// 可选的主题种子色（Material 3 取色用的那一颗「种子」）。
///
/// 用户在外观界面里挑的就是这里的颜色：一颗种子色交给
/// `ColorScheme.fromSeed()`，整套明 / 暗配色都由它派生出来，所以界面上不必
/// （也不该）逐色调色。种子色本身只是「用户挑了哪颗」，最终用的是派生出来的配色。
///
/// 表里刻意选了**色相分散**的十一颗：Material 3 的取色算法会把种子色压成
/// 一整套明暗层级，同色相的两颗种子（比如两颗蓝）派生出来的界面几乎一样，
/// 摆在一起只会让人以为点错了。
///
/// 名字用来给「当前主题色」那行文案取值（不在表里的自定义色显示「自定义」），
/// 名字本身不落库——落库的是颜色值，改名字不会丢用户的选择。
abstract final class ThemeSeeds {
  /// 默认种子色，与 [AppTheme.seedColor] 是同一颗（品牌青）。
  ///
  /// 单独写一份是为了让「颜色 ↔ 名字」这张表不依赖主题构建逻辑，
  /// 两处取值必须一致（`test/appearance_page_test.dart` 里有断言兜住）。
  static const int defaultColor = 0xFF00695C;

  /// 预设种子色，顺序就是界面上的排列顺序。
  static const List<ThemeSeed> presets = <ThemeSeed>[
    ThemeSeed(0xFF00695C, '青绿'),
    ThemeSeed(0xFF0061A4, '湖蓝'),
    ThemeSeed(0xFF3F51B5, '靛蓝'),
    ThemeSeed(0xFF6750A4, '紫罗兰'),
    ThemeSeed(0xFF9C27B0, '葡萄紫'),
    ThemeSeed(0xFFC2185B, '玫红'),
    ThemeSeed(0xFFB3261E, '砖红'),
    ThemeSeed(0xFFE65100, '橘橙'),
    ThemeSeed(0xFFB7791F, '琥珀'),
    ThemeSeed(0xFF43682B, '橄榄绿'),
    ThemeSeed(0xFF2E7D32, '松绿'),
  ];

  /// 取种子色对应的名字；不在预设表里（用户自己调的）返回「自定义」。
  static String nameOf(Color color) {
    for (final ThemeSeed seed in presets) {
      if (seed.color.toARGB32() == color.toARGB32()) {
        return seed.name;
      }
    }
    return '自定义';
  }
}

/// 一颗预设种子色：颜色值 + 界面上的名字。
class ThemeSeed {
  const ThemeSeed(this.value, this.name);

  /// 种子色的 ARGB 值（`0xFF` 开头，不透明）。
  final int value;

  final String name;

  Color get color => Color(value);
}
