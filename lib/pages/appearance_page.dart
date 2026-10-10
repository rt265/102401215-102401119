import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../theme/theme_seeds.dart';
import '../widgets/max_width_body.dart';
import '../widgets/theme_sample.dart';

/// 外观界面（次级界面）。
///
/// 对应《Basic Info》「UI」优先级列表的第 11 项：MD3 主题自定义取色。
/// 它是从设置界面（第 12 项优化）里拆出来的子界面：设置页只列条目，
/// 具体调什么在子界面里做。
///
/// 两件事：
/// - **主题模式**：跟随系统 / 浅色 / 深色；
/// - **主题色**：从预设的 [ThemeSeeds.presets] 里挑一颗种子色，或者自己调
///   （色相 / 饱和度 / 明度三根滑杆）。
///
/// 两项都只写 [SettingsStore]：换肤靠 `main.dart` 里 `ListenableBuilder` 重建
/// `MaterialApp` 完成，本页自己不持有主题状态——
/// 页面上看到的颜色样本是拿候选种子现算的（见 [ThemeSample]）。
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        // 返回键沿用自绘的圆角箭头（顺带固定测试 Key）。接入 flutter_localizations 后
        // 系统 BackButton 的 tooltip 已是中文，这里保留自定义只为图标与 Key。
        leading: IconButton(
          key: const Key('appearance-back-button'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('外观'),
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            Card(
              key: const Key('appearance-card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SectionLabel('主题模式'),
                    const SizedBox(height: 12),
                    // 只放文字不放图标：三段带图标在窄屏上会挤到换行。
                    SegmentedButton<ThemeMode>(
                      key: const Key('appearance-theme-selector'),
                      showSelectedIcon: false,
                      segments: <ButtonSegment<ThemeMode>>[
                        for (final _ThemeOption option in _themeOptions)
                          ButtonSegment<ThemeMode>(
                            value: option.mode,
                            label: Text(option.label),
                          ),
                      ],
                      selected: <ThemeMode>{settings.themeMode},
                      onSelectionChanged: (Set<ThemeMode> selection) =>
                          settings.setThemeMode(selection.first),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _modeHint(context, settings.themeMode),
                      key: const Key('appearance-theme-hint'),
                      style: _hintStyle(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const _SectionTitle(
              key: Key('appearance-section-color'),
              title: '主题色',
            ),
            Card(
              key: const Key('appearance-seed-card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '整套配色由这一颗「种子色」派生，深浅色主题共用它。',
                      style: _hintStyle(context),
                    ),
                    const SizedBox(height: 14),
                    _SeedGrid(
                      selected: settings.themeSeed,
                      onSelected: settings.setThemeSeed,
                    ),
                    const Divider(height: 28),
                    _CustomSeedRow(
                      current: settings.themeSeed,
                      onSelected: settings.setThemeSeed,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const _SectionTitle(
              key: Key('appearance-section-preview'),
              title: '预览',
            ),
            Card(
              key: const Key('appearance-sample-card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '当前主题色：${ThemeSeeds.nameOf(settings.themeSeed)}'
                      '（${encodeColor(settings.themeSeed)}）',
                      key: const Key('appearance-seed-label'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    ThemeSample(seed: settings.themeSeed),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主题模式的提示文案（同一段 `Text`，内容随模式变）。
String _modeHint(BuildContext context, ThemeMode mode) {
  // 「跟随系统」时说明当前实际跟到的是哪一边。
  final bool systemIsDark =
      MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  return switch (mode) {
    ThemeMode.system => '当前跟随系统设置，本机为${systemIsDark ? '深色' : '浅色'}。',
    ThemeMode.light => '始终使用浅色主题。',
    ThemeMode.dark => '始终使用深色主题。',
  };
}

TextStyle? _hintStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

/// 一个主题模式选项：模式 + 按钮上的文案。
class _ThemeOption {
  const _ThemeOption(this.mode, this.label);

  final ThemeMode mode;
  final String label;
}

/// 顺序就是按钮上的顺序：跟随系统、浅色、深色。
const List<_ThemeOption> _themeOptions = <_ThemeOption>[
  _ThemeOption(ThemeMode.system, '跟随系统'),
  _ThemeOption(ThemeMode.light, '浅色'),
  _ThemeOption(ThemeMode.dark, '深色'),
];

/// 分区里的一行小标题。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// 分区标题（与设置界面上的同款）。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// 预设种子色的取色网格。
///
/// 每个色块是一个圆形色点：选中的那个多一圈描边 + 一个对勾——
/// 只靠颜色本身分不出「选中」和「没选中」，加形状记号才看得出来。
class _SeedGrid extends StatelessWidget {
  const _SeedGrid({required this.selected, required this.onSelected});

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('appearance-seed-grid'),
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (final ThemeSeed seed in ThemeSeeds.presets)
          _SeedSwatch(
            seed: seed,
            selected: seed.color.toARGB32() == selected.toARGB32(),
            onTap: () => onSelected(seed.color),
          ),
      ],
    );
  }
}

/// 网格里的一颗种子色。
class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final ThemeSeed seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '主题色 ${seed.name}',
      selected: selected,
      button: true,
      child: Tooltip(
        message: seed.name,
        child: InkWell(
          key: Key('appearance-seed-${seed.value.toRadixString(16)}'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: seed.color,
              shape: BoxShape.circle,
              // 选中：外圈用主题色描边；未选中留一圈透明占位，
              // 免得选中时色块跳一下大小。
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 「自定义颜色」一行：色点 + 说明 + 打开取色器。
class _CustomSeedRow extends StatelessWidget {
  const _CustomSeedRow({required this.current, required this.onSelected});

  final Color current;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isCustom = ThemeSeeds.nameOf(current) == '自定义';

    return Row(
      children: <Widget>[
        // 已经是自定义色时，这里显示的就是用户调出来的那颗，一眼能对上。
        Container(
          key: const Key('appearance-seed-custom-current'),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: current,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '自定义颜色',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isCustom ? '正在使用自定义色。' : '调一颗自己的种子色。',
                key: const Key('appearance-seed-custom-hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          key: const Key('appearance-seed-custom-button'),
          onPressed: () => _openPicker(context),
          child: const Text('调整'),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final Color? picked = await showDialog<Color>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _SeedPickerDialog(initial: current),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }
}

/// 自定义取色器：色相 / 饱和度 / 明度三根滑杆 + 实时预览。
///
/// 用 [HSVColor] 而不是 HSL：HSV 的明度拉到底一定是黑、饱和度拉到底一定是白，
/// 三根滑杆的表现和用户的直觉一致（HSL 的 L=1 恒为白，会让人以为滑杆坏了）。
/// 滑杆的轨道直接画成「这一根滑杆能取到的颜色」，不靠数字猜。
class _SeedPickerDialog extends StatefulWidget {
  const _SeedPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_SeedPickerDialog> createState() => _SeedPickerDialogState();
}

class _SeedPickerDialogState extends State<_SeedPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      key: const Key('appearance-seed-dialog'),
      title: const Text('自定义主题色'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 预览跟着滑杆实时变：改完才知道好不好看就没意义了。
            ThemeSample(seed: _color, compact: true),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  encodeColor(_color),
                  key: const Key('appearance-seed-dialog-value'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _GradientSlider(
              sliderKey: const Key('appearance-seed-hue'),
              label: '色相',
              value: _hsv.hue,
              max: 360,
              colors: <Color>[
                for (int hue = 0; hue <= 360; hue += 60)
                  HSVColor.fromAHSV(1, hue.toDouble() % 360, 1, 1).toColor(),
              ],
              onChanged: (double value) =>
                  setState(() => _hsv = _hsv.withHue(value)),
            ),
            _GradientSlider(
              sliderKey: const Key('appearance-seed-saturation'),
              label: '饱和度',
              value: _hsv.saturation,
              max: 1,
              colors: <Color>[
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              onChanged: (double value) =>
                  setState(() => _hsv = _hsv.withSaturation(value)),
            ),
            _GradientSlider(
              sliderKey: const Key('appearance-seed-brightness'),
              label: '明度',
              value: _hsv.value,
              max: 1,
              colors: <Color>[
                const Color(0xFF000000),
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
              onChanged: (double value) =>
                  setState(() => _hsv = _hsv.withValue(value)),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('appearance-seed-dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('appearance-seed-dialog-confirm'),
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('应用'),
        ),
      ],
    );
  }
}

/// 一根带渐变色轨的滑杆：轨道就是「这根滑杆能取到的颜色」。
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.max,
    required this.colors,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final double value;
  final double max;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelLarge),
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            trackHeight: 12,
            // 轨道自带渐变了，再叠一层主题色会把渐变盖掉。
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            trackShape: _GradientTrackShape(colors),
          ),
          child: Slider(
            key: sliderKey,
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 把轨道画成渐变色条（默认轨道是「已选一段实心 + 未选一段空白」，看颜色不够直观）。
class _GradientTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  _GradientTrackShape(this.colors);

  final List<Color> colors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    required TextDirection textDirection,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
      ).createShader(trackRect)
      ..isAntiAlias = true;

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(trackRect.height / 2)),
      paint,
    );
  }
}
