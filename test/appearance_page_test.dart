import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/settings_store.dart';
import 'package:lost_and_found/pages/appearance_page.dart';
import 'package:lost_and_found/theme/app_theme.dart';
import 'package:lost_and_found/theme/theme_seeds.dart';

import 'helpers/page_harness.dart';

/// 装一个「换种子色会真的重新派生整套配色」的宿主。
///
/// 只把 [AppearancePage] 塞进固定主题的 `MaterialApp` 测不了这件事：
/// 换肤是 `main.dart` 里 `ListenableBuilder` 重建 `MaterialApp` 的效果，
/// 所以宿主得照同一套结构搭（见 [buildSettingsHost]）。
Widget buildAppearance({SettingsStore? settings, bool dark = false}) {
  return buildSettingsHost(
    settings: settings,
    dark: dark,
    home: const AppearancePage(),
  );
}

void main() {
  testWidgets('外观界面同时给出主题模式与主题色', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildAppearance());

    expect(find.text('外观'), findsOneWidget);
    expect(find.byKey(const Key('appearance-back-button')), findsOneWidget);
    expect(find.byKey(const Key('appearance-theme-selector')), findsOneWidget);
    expect(find.byKey(const Key('appearance-theme-hint')), findsOneWidget);

    expect(find.byKey(const Key('appearance-section-color')), findsOneWidget);
    expect(find.byKey(const Key('appearance-seed-grid')), findsOneWidget);
    expect(
      find.byKey(const Key('appearance-seed-custom-button')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('appearance-section-preview')), findsOneWidget);
    expect(find.byKey(const Key('theme-sample')), findsWidgets);
  });

  testWidgets('主题提示说明当前是跟随系统还是固定', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      buildAppearance(settings: SettingsStore(themeMode: ThemeMode.light)),
    );
    expect(textAt(tester, const Key('appearance-theme-hint')), '始终使用浅色主题。');

    await tester.pumpWidget(
      buildAppearance(settings: SettingsStore(themeMode: ThemeMode.dark)),
    );
    expect(textAt(tester, const Key('appearance-theme-hint')), '始终使用深色主题。');

    await tester.pumpWidget(buildAppearance());
    // 测试环境的系统外观是浅色。
    expect(
      textAt(tester, const Key('appearance-theme-hint')),
      '当前跟随系统设置，本机为浅色。',
    );
  });

  // UI 事项 11 的主体：挑一颗预设种子色，整套配色跟着变，并且立刻落库。
  testWidgets('挑预设主题色后立刻换肤并落库', (WidgetTester tester) async {
    useTallScreen(tester);
    final RecordingSettingsRepository repository =
        RecordingSettingsRepository();
    final SettingsStore settings = SettingsStore(repository: repository);

    await tester.pumpWidget(buildAppearance(settings: settings));

    // 默认是品牌青。
    expect(settings.themeSeed, AppTheme.seedColor);
    expect(
      textAt(tester, const Key('appearance-seed-label')),
      '当前主题色：${ThemeSeeds.presets.first.name}'
      '（${encodeColor(AppTheme.seedColor)}）',
    );

    // 网格里每颗预设色都在。
    for (final ThemeSeed seed in ThemeSeeds.presets) {
      expect(find.byKey(seedSwatchKey(seed.value)), findsOneWidget);
    }

    final ThemeSeed picked = ThemeSeeds.presets[2];
    await tapAt(tester, find.byKey(seedSwatchKey(picked.value)));

    expect(settings.themeSeed, picked.color);
    expect(
      repository.values[SettingNames.themeSeed],
      encodeColor(picked.color),
    );
    expect(
      textAt(tester, const Key('appearance-seed-label')),
      '当前主题色：${picked.name}（${encodeColor(picked.color)}）',
    );

    // 真的换了配色：应用主色与用户选择的种子色保持一致。
    final BuildContext page = tester.element(find.byType(AppearancePage));
    expect(Theme.of(page).colorScheme.primary, picked.color);
  });

  // 自定义取色：三根滑杆改出来的颜色要能落库，而且要能被认出来是「自定义」。
  testWidgets('自定义取色器调出的颜色会落库并标为自定义', (WidgetTester tester) async {
    useTallScreen(tester);
    final RecordingSettingsRepository repository =
        RecordingSettingsRepository();
    final SettingsStore settings = SettingsStore(repository: repository);

    await tester.pumpWidget(buildAppearance(settings: settings));

    await tapAt(tester, find.byKey(const Key('appearance-seed-custom-button')));
    expect(find.byKey(const Key('appearance-seed-dialog')), findsOneWidget);
    // 打开时回填当前色，不是从零开始调。
    expect(
      textAt(tester, const Key('appearance-seed-dialog-value')),
      encodeColor(AppTheme.seedColor),
    );

    // 拉动色相滑杆：预览里的色值跟着变。
    final Finder hue = find.byKey(const Key('appearance-seed-hue'));
    await tester.drag(hue, const Offset(80, 0));
    await pumpBriefly(tester);
    final String dragged = textAt(
      tester,
      const Key('appearance-seed-dialog-value'),
    );
    expect(dragged, isNot(encodeColor(AppTheme.seedColor)));

    await tapAt(
      tester,
      find.byKey(const Key('appearance-seed-dialog-confirm')),
    );

    expect(find.byKey(const Key('appearance-seed-dialog')), findsNothing);
    expect(encodeColor(settings.themeSeed), dragged);
    expect(repository.values[SettingNames.themeSeed], dragged);
    // 不在预设表里的颜色显示为「自定义」，提示文案也跟着换。
    expect(
      textAt(tester, const Key('appearance-seed-label')),
      startsWith('当前主题色：自定义'),
    );
    expect(
      textAt(tester, const Key('appearance-seed-custom-hint')),
      '正在使用自定义色。',
    );
  });

  testWidgets('黑白主题色会按所选颜色应用', (WidgetTester tester) async {
    useTallScreen(tester);
    final SettingsStore settings = SettingsStore();

    await tester.pumpWidget(buildAppearance(settings: settings));

    for (final Color color in <Color>[
      const Color(0xFF000000),
      const Color(0xFFFFFFFF),
    ]) {
      final Finder swatch = find.byKey(seedSwatchKey(color.toARGB32()));
      await tapAt(tester, swatch);
      final BuildContext page = tester.element(find.byType(AppearancePage));
      expect(settings.themeSeed, color);
      final ColorScheme scheme = Theme.of(page).colorScheme;
      expect(scheme.primary, color);
      expect(scheme.secondary, color);
      expect(scheme.tertiary, isNot(color));
      expect(scheme.secondaryContainer.computeLuminance(), isNot(0));
      expect(scheme.primaryContainer, isNot(scheme.tertiaryContainer));
    }
  });

  testWidgets('自定义取色器点取消不改动设置', (WidgetTester tester) async {
    useTallScreen(tester);
    final SettingsStore settings = SettingsStore();

    await tester.pumpWidget(buildAppearance(settings: settings));
    await tapAt(tester, find.byKey(const Key('appearance-seed-custom-button')));
    await tester.drag(
      find.byKey(const Key('appearance-seed-hue')),
      const Offset(80, 0),
    );
    await pumpBriefly(tester);
    await tapAt(tester, find.byKey(const Key('appearance-seed-dialog-cancel')));

    expect(settings.themeSeed, AppTheme.seedColor);
  });

  testWidgets('深色模式下也能挑主题色', (WidgetTester tester) async {
    useTallScreen(tester);
    final SettingsStore settings = SettingsStore(themeMode: ThemeMode.dark);

    await tester.pumpWidget(buildAppearance(settings: settings, dark: true));

    final ThemeSeed picked = ThemeSeeds.presets[4];
    await tapAt(tester, find.byKey(seedSwatchKey(picked.value)));

    expect(settings.themeSeed, picked.color);
    final BuildContext page = tester.element(find.byType(AppearancePage));
    expect(Theme.of(page).colorScheme.primary, picked.color);
  });

  testWidgets('返回键能关掉外观界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildPushHost(() => const AppearancePage()));

    await tapAt(tester, find.byKey(const Key('open-page')));
    expect(find.byType(AppearancePage), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('appearance-back-button')));
    expect(find.byType(AppearancePage), findsNothing);
  });
}
