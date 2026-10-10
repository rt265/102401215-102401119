import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 主题色样本：拿一颗**候选**种子色现算出一套配色，画几个真控件给人看。
///
/// 光看一个圆点分不出「这套配色到底好不好看」，所以这里用
/// `ColorScheme.fromSeed` 把种子色派生出的主色 / 容器色铺在按钮、标签、
/// 输入框这些真控件上——用户在外观界面挑颜色时看到的就是落地后的样子。
///
/// 与 `AppTheme` 无关：这里不生成 [ThemeData] 的全局配置，只是把候选配色
/// 套在样本控件上，所以能在外观界面里**预览**还没生效的颜色，
/// 也能在取色器对话框里随滑杆实时变。
class ThemeSample extends StatelessWidget {
  const ThemeSample({super.key, required this.seed, this.compact = false});

  /// 候选种子色。
  final Color seed;

  /// 紧凑模式：取色器对话框里位置有限，少画几个控件。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // 用外层主题当前的明暗：预览的是「换了颜色之后长什么样」，
    // 不是「换明暗之后长什么样」。
    final Brightness brightness = Theme.of(context).brightness;
    final ColorScheme scheme = AppTheme.colorScheme(
      brightness: brightness,
      seed: seed,
    );
    final ThemeData theme = Theme.of(context).copyWith(colorScheme: scheme);

    return Theme(
      data: theme,
      child: Material(
        // Material 才能让按钮 / 输入框拿到这套配色的墨水效果与背景。
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: const Key('theme-sample'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton(onPressed: () {}, child: const Text('主要按钮')),
              FilledButton.tonal(
                onPressed: () {},
                child: const Text('次要按钮'),
              ),
              // 只展示不交互：样本上点几下不该改变任何设置。
              IgnorePointer(
                child: FilterChip(
                  selected: true,
                  label: const Text('已选中标签'),
                  onSelected: (_) {},
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '容器色',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '输入框',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                Text(
                  '正文示例',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
