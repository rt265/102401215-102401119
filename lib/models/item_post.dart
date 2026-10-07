import 'package:flutter/material.dart';

/// 信息类型：失物（自己丢了东西，等人归还） / 招领（捡到东西，等人认领）。
enum PostType {
  lost('失物', Icons.search_off_rounded),
  found('招领', Icons.volunteer_activism_rounded);

  const PostType(this.label, this.icon);

  final String label;
  final IconData icon;

  /// 尚未处理完时的状态文案。
  String get pendingLabel => this == PostType.lost ? '寻找中' : '待认领';

  /// 已处理完时的状态文案。
  String get resolvedLabel => this == PostType.lost ? '已找到' : '已归还';
}

/// 信息状态：发布者是否已经找回 / 归还物品。
enum PostStatus {
  pending('进行中'),
  resolved('已完成');

  const PostStatus(this.label);

  final String label;
}

/// 物品分类。
enum ItemCategory {
  card('证件卡类', Icons.badge_outlined),
  digital('电子产品', Icons.smartphone_outlined),
  book('书籍资料', Icons.menu_book_outlined),
  key('钥匙', Icons.vpn_key_outlined),
  clothing('衣物服饰', Icons.checkroom_outlined),
  daily('生活用品', Icons.shopping_bag_outlined),
  other('其他', Icons.category_outlined);

  const ItemCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 一条失物 / 招领信息。
///
/// 字段与《Basic Info》中“每个信息应当包含以下内容”一一对应；
/// UI 构建阶段先用内存中的示例数据填充，后续接入本地 SQLite 时保持不变。
@immutable
class ItemPost {
  const ItemPost({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.location,
    required this.eventTime,
    required this.contact,
    required this.createdAt,
    this.description,
    this.imagePaths = const <String>[],
    this.status = PostStatus.pending,
    this.isMine = false,
  });

  final String id;

  /// 失物 / 招领。
  final PostType type;

  /// 物品名称。
  final String title;

  final ItemCategory category;

  /// 丢失 / 拾取地点。
  final String location;

  /// 丢失 / 拾取发生的时间。
  final DateTime eventTime;

  /// 发布者提供的联系方式。
  final String contact;

  /// 信息发布时间，用于排序。
  final DateTime createdAt;

  final String? description;

  /// 图片文件路径，选填。
  final List<String> imagePaths;

  final PostStatus status;

  /// 是否为「本机用户自己发布的」信息。
  ///
  /// 「我的」界面只列出这一类信息：示例数据不是用户发的，只有发布界面新建的才是。
  /// 这个标记已经随信息一起落库（`posts.is_mine`）。
  ///
  /// 现在判的是「本机用户发的 vs 示例数据」。要改成按发布者 id 判，
  /// 缺的不是落库（那步已完成），而是**多账户**：`user_account` 目前是固定
  /// 单行表（见 db_schema.dart），全应用只有一个本地账户，
  /// 多一列 `author_id` 得不出比这个布尔值更多的信息。
  final bool isMine;

  /// 复制一份并替换若干字段。
  ///
  /// 用于「标记已找到 / 已归还」这类只改一两个字段的操作。
  ItemPost copyWith({
    PostType? type,
    String? title,
    ItemCategory? category,
    String? location,
    DateTime? eventTime,
    String? contact,
    String? description,
    List<String>? imagePaths,
    PostStatus? status,
    bool? isMine,
  }) {
    return ItemPost(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      category: category ?? this.category,
      location: location ?? this.location,
      eventTime: eventTime ?? this.eventTime,
      contact: contact ?? this.contact,
      createdAt: createdAt,
      description: description ?? this.description,
      imagePaths: imagePaths ?? this.imagePaths,
      status: status ?? this.status,
      isMine: isMine ?? this.isMine,
    );
  }

  /// 是否通过 [type] / [category] 筛选。
  ///
  /// `null` 表示该维度不筛选。
  bool matchesFilter({PostType? type, ItemCategory? category}) {
    if (type != null && this.type != type) {
      return false;
    }
    if (category != null && this.category != category) {
      return false;
    }
    return true;
  }

  /// 是否命中关键词（物品名称 / 地点 / 描述 / 分类）。
  ///
  /// 关键词按空白拆成多个词，**全部命中才算命中**（「图书馆 雨伞」＝两样都得沾边）：
  /// 多打一个词是收窄结果，而不是换一批结果。
  bool matchesKeyword(String keyword) {
    final List<String> tokens = keyword
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return true;
    }
    return tokens.every(_matchesToken);
  }

  bool _matchesToken(String token) =>
      _contains(title, token) ||
      _contains(location, token) ||
      _contains(description ?? '', token) ||
      _contains(category.label, token);

  static bool _contains(String source, String lowerKeyword) =>
      source.toLowerCase().contains(lowerKeyword);
}
