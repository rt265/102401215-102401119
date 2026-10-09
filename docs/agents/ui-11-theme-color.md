# UI 事项 11：MD3 主题自定义取色

对应 `docs/agents/basic-info.md` 中「UI」→ 优先级列表的第 11 项
「MD3 主题自定义取色」。需求原文（同一份文档的「Setting」一节）：
「外观：主题模式（自动/深/浅色模式）、**自定义主题色彩（MD3）**」。

## 本轮目标

UI 事项 7 只做到「让用户选明 / 暗」，种子色是写死的品牌青 `#00695C`。
本轮把**那一颗种子色交给用户挑**：预设一批 + 自己调，选完立刻换肤并落库。
这也是 `ui-07-settings-page.md` 里明确留给后续的一条（「浅色 / 深色只有一套种子色……没做『主题色可选』」）。

范围决策（**不引第三方取色包**）：不引 `dynamic_color` / `flex_seed_scheme` 之类，
只用 Flutter 自带的 `ColorScheme.fromSeed`。理由：MD3 的取色规则由 Flutter 实现，
第三方包能多给的只是「从壁纸取色」这类系统集成，而本项目不做系统壁纸联动；
少一个依赖就少一次版本冲突与原生通道风险。

## 交付内容

| 部分 | 说明 |
| --- | --- |
| 种子色表 | 新增 `lib/theme/theme_seeds.dart`：11 颗色相分散的预设色 + 名字 |
| 主题可变 | `AppTheme.light({Color seed})` / `dark({Color seed})`，`_build` 收种子色 |
| 持久化 | 新增设置项 `theme_seed`（键值表加一项，**不用升库版本**），值形如 `#FF6750A4` |
| 外观界面 | 新增 `lib/pages/appearance_page.dart`：主题模式 + 主题色网格 + 实时预览 |
| 自定义取色器 | `AlertDialog` + 三根 HSV 渐变滑杆（色相 / 饱和度 / 明度），实时预览 |
| 预览样本 | 新增 `lib/widgets/theme_sample.dart`：把候选配色套在真控件上画出来 |

## 文件清单

```
lib/
  theme/theme_seeds.dart        预设种子色表 + 名字（新增）
  theme/app_theme.dart          light() / dark() 收 seed 参数（改写）
  data/settings_store.dart      SettingNames.themeSeed + setThemeSeed + encodeColor/parseColor（改写）
  pages/appearance_page.dart    外观界面 + 自定义取色器（新增）
  pages/settings_page.dart      外观分区的入口卡片（改写，见 ui-12）
  widgets/theme_sample.dart     主题色样本（新增）
  main.dart                     MaterialApp 的 theme/darkTheme 传当前种子色（改写）
test/
  appearance_page_test.dart     外观界面 7 个 widget 测试（新增）
  sqlite_storage_test.dart      「设置」group 补 3 个种子色用例（改写）
  helpers/page_harness.dart     四个设置相关界面共用的测试脚手架（新增，见 ui-12）
```

## 设计要点

- **只让用户挑「种子色」，不让用户逐色调色**：`ColorScheme.fromSeed` 会把一颗种子
  压成一整套明暗层级（primary / container / onXxx……），这才是 MD3 的做法。
  界面上放十几个颜色选择器既难用，也一定会调出对比度不足的配色。
- **预设色刻意选「色相分散」的 11 颗**：同色相的两颗种子（比如两颗蓝）派生出的界面几乎一样，
  摆在一起只会让人以为点错了。表里覆盖青绿 / 蓝 / 靛 / 紫 / 玫红 / 红 / 橙 / 琥珀 / 绿等色相。
- **`HSVColor` 而不是 `HSLColor`**：HSL 在 `L = 1` 时任何色相都是纯白，
  「明度」滑杆拖到最右预览就白了、看着像坏了；HSV 的 `V` 才是「越右越亮但不失真」。
- **滑杆轨道画成渐变色条**（`_GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape`）：
  纯色轨道看不出这根滑杆在调什么。重写 `paint()` 时注意 Flutter 3.47 的签名是
  `paint(PaintingContext, Offset, {required RenderBox parentBox, required SliderThemeData sliderTheme, required Animation<double> enableAnimation, required Offset thumbCenter, Offset? secondaryOffset, bool isDiscrete = false, bool isEnabled = false, required TextDirection textDirection})`
  ——**没有 `additionalActiveTrackHeight`**，且 `BaseSliderTrackShape.getPreferredRect` **不收 `textDirection`**。
  配 `activeTrackColor: Colors.transparent` + `trackHeight: 12`，让自绘轨道露出来。
- **落库存 `#AARRGGBB` 文本，不存十进制 int**：`app_settings` 是「一行一项」的文本键值表，
  存 `4285096100` 这种数字既看不出是什么、也没法人工核对；`#FF6750A4` 直接能跟设计稿对照。
  转换放在 `SettingsStore` 的 `encodeColor()` / `parseColor()` 两个静态函数里
  （`parseColor` 是公开的，测试直接对拍）。
- **认不出的颜色退回默认，不崩**：`parseColor()` 对「没有 `#`」「位数不对」「`#xyz`」
  「全透明（`#00……`）」一律返回 `null`，`load()` 拿到 `null` 就用 `AppTheme.seedColor`。
  与既有 `parseThemeMode()` 认不出退回 `ThemeMode.system` 是同一套路——库里可能留着旧版本或其他程序写下的值。
  **全透明也算认不出**：种子色带 alpha 会让整套配色变得不可预期，不如当无效值。
- **不用升库版本**：`theme_seed` 只是键值表里的**一行新数据**，表结构没动，
  `DbSchema.version` 保持 2。这是 ui-07 把设置做成键值表换来的好处（「以后加设置项只写一行数据、不动表结构」）。
- **`ThemeSample` 与 `AppTheme` 解耦**：样本只做
  `ColorScheme.fromSeed(seedColor: seed, brightness: Theme.of(context).brightness)` +
  `Theme(data: ..., child: Material(...))`，不生成全局 `ThemeData`。
  这样取色器对话框里能随滑杆**实时预览还没生效的颜色**。
  样本里的 `FilledButton` / `FilterChip` 等只展示不交互（`onPressed: () {}`，
  筛选标签再套 `IgnorePointer`）——样本上点几下不该改变任何设置。
- **预设色表里不重复默认色**：`ThemeSeeds.defaultColor` 与 `AppTheme.seedColor`
  是同一颗（`0xFF00695C`），但 `presets` 里不再额外列一颗同名色，
  否则网格上会出现两个一模一样的圆点。
- **`ThemeSeeds.nameOf()` 只用来出文案**：名字不落库（落库的是颜色值），
  所以以后改名字不会让用户的选择失效；不在表里的颜色显示「自定义」。

## Key 约定

| Key | 位置 |
| --- | --- |
| `appearance-back-button` | 外观界面 AppBar 返回（中文 tooltip） |
| `appearance-card` | 主题模式卡（`SegmentedButton<ThemeMode>`） |
| `appearance-theme-selector` | 主题模式选择器 |
| `appearance-theme-hint` | 当前模式说明（三态文案同 ui-07） |
| `appearance-section-color` | 「主题色」分区标题 |
| `appearance-seed-card` | 主题色卡 |
| `appearance-seed-grid` | 预设色网格（`Wrap`） |
| `appearance-seed-<hex>` | 每颗预设色圆点（如 `appearance-seed-ff6750a4`，由 `value.toRadixString(16)` 拼） |
| `appearance-seed-custom-current` | 「当前：自定义色 #…… 」那行 |
| `appearance-seed-custom-hint` | 「正在使用自定义色。」提示 |
| `appearance-seed-custom-button` | 「自定义颜色…」按钮 |
| `appearance-seed-dialog` | 取色器对话框 |
| `appearance-seed-dialog-value` | 对话框里的色值文本（实时变） |
| `appearance-seed-dialog-cancel` / `-confirm` | 对话框的取消 / 使用这个颜色 |
| `appearance-seed-hue` / `-saturation` / `-brightness` | 三根滑杆 |
| `appearance-seed-label` | 预览卡上「当前主题色：X」 |
| `appearance-sample-card` | 预览卡 |
| `theme-sample` | 样本本体（`ThemeSample` 内部，测试用 `find.byKey` 找它） |

## 测试

新增 `test/appearance_page_test.dart`（7 个）：

1. 控件齐全（返回键、模式选择器、模式说明、主题色分区与网格、自定义按钮、预览区与样本）；
2. 主题模式说明三态；
3. 挑预设色：先断言 11 颗全在网格里，再点第 3 颗（靛蓝），断言
   `settings.themeSeed`、`repository.values[SettingNames.themeSeed] == encodeColor(picked.color)`、
   `appearance-seed-label` 文案，以及**真的换肤**（`Theme.of(page).colorScheme.primary`
   与 `ColorScheme.fromSeed(seedColor: picked.color, brightness: Brightness.light).primary` 相等）；
4. 自定义取色器：打开时回填当前色（`encodeColor(AppTheme.seedColor)`）→ 拖色相滑杆 →
   确认后落库、标签变「自定义」、提示变「正在使用自定义色。」；
5. 自定义取色器点取消不改动设置；
6. 深色模式下挑色也换肤（对拍的是 `brightness: Brightness.dark` 的 primary）；
7. 返回键能关掉外观界面。

`test/sqlite_storage_test.dart` 的 `group('设置')` 补 3 个：

- 种子色写入读回、跟着 `SettingsStore` 装载、`setThemeSeed` 内存先变后落库；
- 库里存着认不出的颜色（`'teal'` / `'#12345'` / `'#00FF0000'`）时退回默认种子色；
- `encodeColor` / `parseColor` 互转（含前后空格、缺 `#`、`#xyz`、全透明一律 `null`）。

### 本轮踩到的坑

- **`ThemeSample` 里那个「一直在转」的进度圈会让 `pumpAndSettle` 永远超时**：
  非紧凑模式画了一个 `CircularProgressIndicator`（用来展示配色里的主色），
  它按定义不会停，于是任何包含外观界面的测试只要调 `pumpAndSettle()`
  就报 `pumpAndSettle timed out`——**不是界面坏了，是测试等不到「没有待调度帧」**。
  处置见 `ui-12-settings-redesign.md` 的「测试脚手架」一节（`pumpBriefly`）。
- **`SliderTrackShape.paint` 的签名**：见上文「设计要点」，
  多写了 `additionalActiveTrackHeight` 会被 `invalid_override` 拦下，`getPreferredRect` 多传 `textDirection` 会
  `undefined_named_parameter`。

## 尚未实现 / 留给后续事项

- 不做「跟随壁纸取色」（`dynamic_color`），也不做「明暗两套不同种子色」——一颗种子派生两套，这是 MD3 的默认口径。
- 没有「重置为默认色」按钮：默认色本来就在预设网格的第一颗上，点它即可。
- `AppTheme` 的其余全局配置（AppBar / Card / NavigationBar 的圆角与阴影）不随种子色变。

## 验证

```bash
flutter analyze
flutter test
```

**最近一次验证结果（本轮）**：

- `flutter analyze` → `No issues found! (ran in 1.0s)`
- `flutter test` → `00:07 +140: All tests passed!`

（两个命令在受限沙箱下会因无法启动分析器 / 测试子进程而失败，
需在 danger-full-access 下运行或由用户手动执行，详见 basic-info.md 的环境备忘。）
