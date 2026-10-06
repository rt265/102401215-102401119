# 详情页图片点击放大

## 背景

详细信息页（`lib/pages/post_detail_page.dart`）的顶部轮播只能看缩略图，用户反映图片不能点击放大，
需要加上全屏查看功能。

## 本轮改动

在详情页的图片轮播上包一层 `GestureDetector`，点击后通过 `Navigator.push` 弹出全屏查看器
`_PhotoGalleryViewer`（`PageRouteBuilder` + 黑色半透明遮罩）。

### 全屏查看器功能

- **双指缩放**：`InteractiveViewer`（1x–5x），支持捏合与拖动
- **双击切换**：1x ↔ 3x
- **左右滑动切换**：`PageView`，多图时与详情页轮播当前页对齐
- **页码指示**：顶部右上角 `N / M`（多图时显示）
- **关闭**：左上角「关闭」按钮，或点图片以外的留白区域
- **图片读不出来**：降级显示「图片无法显示」提示（和列表/详情页的兜底口径一致）

### 设计决策

| 决策 | 理由 |
| --- | --- |
| 用 `rootNavigator: true` push | 全屏查看器要盖住整个页面（含 `AppBar`），不能只盖 `body` |
| `opaque: false` + `barrierColor: Colors.black` | 图片查看器不是独立路由栈页面，是覆盖层 |
| 全屏解码原图（不加 `cacheWidth`） | 用户点开就是要看清细节，缩略图那套 `cacheWidth` 限制不适用 |
| 点击图片本身不退出 | 放大后拖动容易误触，只有留白区域和关闭按钮才退出 |
| 双击用 `Matrix4.diagonal3Values(3.0, 3.0, 1.0)` | `Matrix4..scale()` 已 deprecated，`diagonal3Values` 是等价写法 |

## 改动文件

| 文件 | 改动 |
| --- | --- |
| `lib/pages/post_detail_page.dart` | `_Hero` 图片加 `GestureDetector`；新增 `_PhotoGalleryViewer`、`_ZoomablePhoto` |
| `test/post_detail_page_test.dart` | 新增「点图片打开全屏查看器再关闭」用例 |

## 验证

- `flutter analyze`：No issues found
- `flutter test test/post_detail_page_test.dart`：13 个用例全部通过（12 原有 + 1 新增，无回归）
