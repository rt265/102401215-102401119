import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/post_store.dart';
import '../models/item_post.dart';
import '../utils/time_format.dart';
import '../widgets/post_photo.dart';

/// 详细信息界面（次级界面）。
///
/// 对应《Basic Info》「View Detail」：展示一条信息的全部内容，
/// 以及**发布者提供的联系方式**——联系方式是这里唯一需要用户动手的地方，
/// 因此给了一键复制，并在底部再放一个同样动作的按钮。
///
/// 页面只做出两件事：把信息读全、把联系方式交出去。
/// 标记「已找到 / 已归还」、修改、删除都留在「我的」界面（UI 事项 3），
/// 免得同一条信息在详情页和「我的发布」里各有一套管理入口。
class PostDetailPage extends StatelessWidget {
  const PostDetailPage({super.key, required this.postId, this.onGoHome});

  /// 要展示的信息 id。
  ///
  /// 页面按 id 从 [PostStore] 现查，而不是认一份传进来的快照：
  /// 用户可能先打开详情，再回到「我的」改了内容又切回来，这时显示的应当是新内容；
  /// 信息被删掉时，这里也就查不到，正好落到空态。
  final String postId;

  /// 信息已被删除时，空态里「回到首页」的动作，由外壳注入。
  final VoidCallback? onGoHome;

  ItemPost? _resolve(BuildContext context) =>
      PostScope.of(context).postById(postId);

  Future<void> _copyContact(BuildContext context, String contact) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: contact));
    messenger.showSnackBar(const SnackBar(content: Text('联系方式已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final ItemPost? post = _resolve(context);

    if (post == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('信息详情'),
          leading: IconButton(
            key: const Key('detail-back-button'),
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: _DeletedState(
          onGoHome: onGoHome == null
              ? null
              : () {
                  // 先退出详情页本身，再执行外壳给的「回到首页」。
                  Navigator.of(context).pop();
                  onGoHome!();
                },
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool resolved = post.status == PostStatus.resolved;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          key: const Key('detail-back-button'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        key: const Key('detail-content'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _Hero(post: post, dimmed: resolved),
          const SizedBox(height: 16),

          _TypeBadge(type: post.type),
          const SizedBox(height: 8),
          Text(
            post.title,
            key: const Key('detail-title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: resolved ? scheme.onSurfaceVariant : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '发布于 ${formatRelativeTime(post.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),

          if (resolved) ...<Widget>[
            const SizedBox(height: 16),
            _Notice(
              key: const Key('detail-resolved-notice'),
              icon: Icons.task_alt_rounded,
              title: post.type.resolvedLabel,
              message: '发布者已把这条信息标记为“${post.type.resolvedLabel}”',
            ),
          ],

          const SizedBox(height: 20),
          _SectionTitle('物品信息'),
          const SizedBox(height: 8),
          _InfoCard(
            rows: <_InfoRow>[
              _InfoRow(
                icon: post.category.icon,
                label: '物品分类',
                value: post.category.label,
              ),
              _InfoRow(
                icon: Icons.place_outlined,
                label: post.type == PostType.lost ? '丢失地点' : '拾取地点',
                value: post.location,
              ),
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: post.type == PostType.lost ? '丢失时间' : '拾取时间',
                value: _eventTimeText(post.eventTime),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SectionTitle('物品描述'),
          const SizedBox(height: 8),
          _DescriptionCard(description: post.description),

          const SizedBox(height: 20),
          _SectionTitle('联系方式'),
          const SizedBox(height: 8),
          _ContactCard(
            contact: post.contact,
            isMine: post.isMine,
            onCopy: () => _copyContact(context, post.contact),
          ),

          const SizedBox(height: 20),
          _Notice(
            key: const Key('detail-contact-tip'),
            icon: Icons.info_outline_rounded,
            title: '联系时请注意',
            message: post.type == PostType.lost
                ? '这是失主留下的联系方式。如果你捡到了这件物品，'
                      '或者知道它在哪儿，请直接联系失主。'
                : '这是拾到者留下的联系方式。如果这是你的物品，'
                      '请联系对方并说明物品特征，认领时注意核对。',
          ),

          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('detail-copy-contact-button'),
            onPressed: () => _copyContact(context, post.contact),
            icon: const Icon(Icons.copy_rounded, size: 20),
            label: const Text('复制联系方式'),
          ),
        ],
      ),
    );
  }
}

/// 丢失 / 拾取时刻的完整写法。
///
/// 今天、昨天、前天的说法清单用 [formatEventTime]（“昨天 14:20”），
/// 更早的则给完整日期时间——详情页比首页卡片更该把时间说清楚。
String _eventTimeText(DateTime time) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(time.year, time.month, time.day);
  return today.difference(day).inDays <= 2
      ? formatEventTime(time)
      : formatDateTime(time);
}

/// 顶部展示区：带图片时是轮播，没有图片时仍是分类图标撑起版面。
///
/// 图片可能不止一张，所以给翻页：主图下方一条小圆点能看出「还有几张」，
/// 点一下换页。图片读不出来时由 [PostPhotoView] 退回分类图标（见它的注释）。
class _Hero extends StatefulWidget {
  const _Hero({required this.post, required this.dimmed});

  final ItemPost post;
  final bool dimmed;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 打开全屏图片查看器，从 [initialIndex] 这张开始。
  void _openPhotoGallery(BuildContext context, List<String> images, int initialIndex) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _PhotoGalleryViewer(
          images: images,
          initialIndex: initialIndex,
          resolvePath: (String name) => resolvePhotoPath(context, name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> images = imageFilenamesOf(widget.post);

    if (images.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          widget.post.category.icon,
          size: 72,
          color: widget.dimmed
              ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
              : scheme.primary,
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 240,
          child: PageView.builder(
            key: const Key('detail-photo-carousel'),
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (int page) => setState(() => _page = page),
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                key: Key('detail-photo-$index'),
                onTap: () => _openPhotoGallery(context, images, index),
                child: PostPhotoView(
                  filePath: resolvePhotoPath(context, images[index]),
                  borderRadius: 20,
                  fallbackIcon: widget.post.category.icon,
                ),
              );
            },
          ),
        ),
        if (images.length > 1) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '${_page + 1} / ${images.length}',
            key: const Key('detail-photo-indicator'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 全屏图片查看器：支持双指 / 双击缩放、左右滑动切换、点击退出。
///
/// 从详情页的轮播点击进入：拿到的是**文件名**列表，由 [resolvePath] 换算成绝对
/// 路径（和详情页用的是同一套口径，`PhotoScope` 没有时照原样返回、`Image.file`
/// 读不到会触发 `errorBuilder`）。全屏下不打折扣地解码原图——用户就是要看清细节。
class _PhotoGalleryViewer extends StatefulWidget {
  const _PhotoGalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.resolvePath,
  });

  final List<String> images;
  final int initialIndex;
  final String Function(String filename) resolvePath;

  @override
  State<_PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<_PhotoGalleryViewer> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          // 点击图片本身不退出——避免放大后挪动时误触。
          // 只有上下边的留白区域或「关闭」按钮才退出。
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SafeArea(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (int page) => setState(() => _page = page),
                itemBuilder: (BuildContext context, int index) {
                  return _ZoomablePhoto(
                    path: widget.resolvePath(widget.images[index]),
                  );
                },
              ),
            ),
          ),
          // 顶栏：页码 + 关闭按钮
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      key: const Key('gallery-close'),
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const Spacer(),
                    if (widget.images.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${_page + 1} / ${widget.images.length}',
                          key: const Key('gallery-indicator'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张可缩放的图片。
///
/// `InteractiveViewer` 支持双指捏合与拖动；双击在 1x ↔ 3x 之间切换。
/// 图片读不出来时显示提示文字而不是崩。
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.path});

  final String path;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_broken) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text('图片无法显示', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1.0,
      maxScale: 5.0,
      clipBehavior: Clip.none,
      child: GestureDetector(
        onDoubleTapDown: (_) => _toggleZoom(),
        onDoubleTap: () {},
        child: Center(
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _broken = true);
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  void _toggleZoom() {
    final Matrix4 current = _controller.value;
    final bool isZoomed = current.row0.x > 1.5;
    _controller.value = isZoomed ? Matrix4.identity() : Matrix4.diagonal3Values(3.0, 3.0, 1.0);
  }
}

/// 失物 / 招领标签。
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final PostType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isLost = type == PostType.lost;
    final Color background = isLost
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final Color foreground = isLost
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(type.icon, size: 14, color: foreground),
              const SizedBox(width: 4),
              Text(
                type.label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 区块小标题。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// 一条信息里的一行“字段 + 取值”。
class _InfoRow {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// 物品信息卡：分类、地点、时间。
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      key: const Key('detail-info-card'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: <Widget>[
            for (final _InfoRow row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(row.icon, size: 18, color: scheme.primary),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 68,
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 物品描述卡。描述是选填项，为空时给出说明而不是留一片空白。
class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? text = description?.trim();
    final bool empty = text == null || text.isEmpty;

    return Card(
      key: const Key('detail-description-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          empty ? '发布者没有填写物品描述。' : text,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: empty ? scheme.onSurfaceVariant : null,
            fontStyle: empty ? FontStyle.italic : null,
          ),
        ),
      ),
    );
  }
}

/// 联系方式卡：联系方式与一键复制。
///
/// 这是《Basic Info》「View Detail」里唯一要求“能拿到手”的东西，
/// 所以给足视觉重量：卡片用主色容器底色，值用大一号的字，右侧直接一个复制按钮。
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.isMine,
    required this.onCopy,
  });

  final String contact;

  /// 自己发布的信息：联系方式就是自己的，不必再复制一遍。
  final bool isMine;

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      key: const Key('detail-contact-card'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.contact_phone_outlined, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isMine ? '你留下的联系方式' : '发布者留下的联系方式',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  contact,
                  key: const Key('detail-contact'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('detail-copy-contact'),
            tooltip: '复制联系方式',
            onPressed: onCopy,
            color: scheme.onPrimaryContainer,
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// 带图标的说明块（完成提示、联系须知）。
class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 信息在查看期间被删除时的空态。
///
/// 详情页订阅了仓库：用户在「我的发布」里删掉这条信息后再切回来，就会落到这里，
/// 而不是对着一份已经不存在的数据继续渲染。
class _DeletedState extends StatelessWidget {
  const _DeletedState({this.onGoHome});

  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      key: const Key('detail-deleted'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.delete_outline_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('这条信息已被删除', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '发布者撤回了它，或者内容已被移除。你可以返回列表看看其他信息。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (onGoHome != null)
              FilledButton.tonal(
                key: const Key('detail-go-home'),
                onPressed: onGoHome,
                child: const Text('回到首页'),
              ),
          ],
        ),
      ),
    );
  }
}
