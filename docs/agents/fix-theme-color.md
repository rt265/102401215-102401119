# 自定义主题色视觉一致性修复

## 本轮目标

修复自定义主题色与实际界面颜色不一致，以及色彩参数滑条只显示滑块的问题。

## 改动

- [app_theme.dart](../../lib/theme/app_theme.dart) 新增统一的 `AppTheme.colorScheme`：
  `ColorScheme.fromSeed` 仍负责生成 Material 3 的完整配色，但用户选择的颜色会作为
  实际 `primary`、`secondary` 和 `tertiary`，并让三组 container 角色使用同色系，
  根据亮度设置对应的 `on*` 颜色。
- [theme_sample.dart](../../lib/widgets/theme_sample.dart) 复用同一套配色逻辑，预览和实际
  主题不再出现两套结果。
- [theme_seeds.dart](../../lib/theme/theme_seeds.dart) 扩展预设方案，增加更多蓝、红、黄、
  蓝灰，以及纯黑和纯白，提升同色系和极端颜色的选择自由度。
- [appearance_page.dart](../../lib/pages/appearance_page.dart) 将滑条渐变绘制为独立背景，
  保留 Slider 的交互和滑块，避免透明轨道在渲染时遮住渐变。
- [appearance_page_test.dart](../../test/appearance_page_test.dart) 更新主题主色断言，并覆盖
  黑白主题色的实际应用。

## 验证

运行 `flutter test test/appearance_page_test.dart`。
