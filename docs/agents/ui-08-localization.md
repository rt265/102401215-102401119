# 控件文字本地化：接入 flutter_localizations（2026-10-10）

对应《Basic Info》「UI」优先级列表第 8 项「控件文字本地化」。此前项目所有自有文案
（界面文字、校验提示、枚举 label）都是中文硬编码（集中在 `lib/l10n/`），但**系统级控件**
仍走 Flutter 默认的英文，两者混排。这一轮把 `flutter_localizations` 接进来，补齐系统控件。

## 背景

改之前是这种「中英文混杂」的状态：

- `showDatePicker` / `showTimePicker`（`lib/widgets/post_form.dart` 里选丢失/拾取时间）：
  `helpText` 已手动写成「选择日期 / 选择时间」，但日历里的**月份、星期、星期首日、
  「确定 / 取消」按钮**仍是英文。
- `SelectableText`（详情页联系方式）与 `TextField`（搜索栏、主题样本）的**长按文本选择菜单**
  （复制 / 粘贴 / 全选）仍是英文。
- 系统 `BackButton` 的默认 tooltip 是英文 `Back`——这是次级界面各自手绘一个
  `tooltip: '返回'` 的圆角返回键（`Icons.arrow_back_rounded`）的直接原因。

各处 `docs/agents/ui-*.md` 里「中文化未做」「系统级控件仍是英文」的记录，指的都是这件事。

## 改动

| 文件 | 改动 |
| --- | --- |
| `pubspec.yaml` | 新增 `flutter_localizations: {sdk: flutter}`（Flutter SDK 自带，`pub get` 不联网） |
| `lib/main.dart` | `MaterialApp` 增加 `localizationsDelegates` / `supportedLocales` / `locale`，固定中文 |
| `lib/pages/settings_page.dart` | 订正「未接 flutter_localizations」的过时注释 |
| `lib/pages/appearance_page.dart` | 同上 |

### `main.dart` 的三行

```dart
localizationsDelegates: GlobalMaterialLocalizations.delegates,
supportedLocales: const <Locale>[Locale('zh')],
locale: const Locale('zh'),
