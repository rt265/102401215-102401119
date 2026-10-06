import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/photo_store.dart';
import '../models/item_post.dart';

/// 一条信息引用的图片**文件名**列表。
///
/// 库里存的是文件名，`ItemPost.imagePaths` 在绝大多数时候就是文件名；但迁移前的
/// 旧数据可能还留着绝对路径，统一在这里剥成文件名，比较与删除才不会漏。
List<String> imageFilenamesOf(ItemPost post) {
  final Set<String> seen = <String>{};
  final List<String> names = <String>[];
  for (final String path in post.imagePaths) {
    final String name = p.isAbsolute(path) ? p.basename(path) : path;
    if (name.isEmpty || !seen.add(name)) {
      continue;
    }
    names.add(name);
  }
  return names;
}

/// 把「库里存的图片路径」换算成能直接交给 `Image.file` 的绝对路径。
///
/// 已经是绝对路径的原样返回（旧数据 / 迁移中），文件名则按图片目录拼；
/// 没有 `PhotoScope`（纯内存测试）时把文件名原样返回——`File(name)` 读不到文件，
/// [PostPhotoView] 会降级成分类图标，而不是崩。
String resolvePhotoPath(BuildContext context, String path) {
  if (p.isAbsolute(path)) {
    return path;
  }
  return PhotoScope.maybeOf(context)?.resolve(path) ?? path;
}

/// 一张本地图片，读不出来时降级成 [fallbackIcon]。
///
/// 选完图之后文件可能被用户在系统相册里删掉；迁移时也可能只留下文件名而文件
/// 已经不在（见 `PhotoStore.applyPendingUpdates`）。所以「图片打不开」是一种正常
/// 状态，不该在界面上留一块红色报错。
class PostPhotoView extends StatelessWidget {
  const PostPhotoView({
    super.key,
    required this.filePath,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  /// 图片的绝对路径；`null` 表示这条信息没有图片。
  final String? filePath;

  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;

  /// 没有图片或读不出来时显示的图标。
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? path = filePath;

    // 相册原图动辄几千像素宽，缩略图不必按原图解码：给解码器一个上限，
    // 列表里滚动时才不会一路吃内存。
    int? cacheWidth;
    final double? width = this.width;
    if (path != null && width != null && width.isFinite && width > 0) {
      cacheWidth = (width * MediaQuery.devicePixelRatioOf(context)).round();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: path == null
            ? _fallback(scheme, broken: false)
            : Image.file(
                File(path),
                fit: fit,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => _fallback(scheme, broken: true),
              ),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme, {required bool broken}) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          fallbackIcon,
          color: broken ? scheme.outline : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
