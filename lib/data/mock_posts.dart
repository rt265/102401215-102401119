import '../models/item_post.dart';

/// 首页在“UI 构建”阶段使用的示例数据。
///
/// 时间基于当前时刻生成，因此无论何时运行都显示得比较自然。
///
/// TODO(storage): 接入本地 SQLite 后，这个函数由 `ItemRepository` 的查询结果替换，
/// 页面本身不需要改动。
List<ItemPost> buildMockPosts({DateTime? now}) {
  final DateTime base = now ?? DateTime.now();

  return <ItemPost>[
    ItemPost(
      id: 'p001',
      type: PostType.lost,
      title: '校园一卡通（蓝色卡套）',
      category: ItemCategory.card,
      location: '第三教学楼 302',
      eventTime: base.subtract(const Duration(hours: 3)),
      contact: '微信 card_zhang',
      createdAt: base.subtract(const Duration(hours: 2)),
      description: '卡套是蓝色的，背面贴了一张小熊贴纸，姓名张同学。',
    ),
    ItemPost(
      id: 'p002',
      type: PostType.found,
      title: '黑色自动雨伞',
      category: ItemCategory.daily,
      location: '图书馆一楼大厅',
      eventTime: base.subtract(const Duration(hours: 6)),
      contact: '手机 138****6621',
      createdAt: base.subtract(const Duration(hours: 5)),
      description: '伞柄上有一圈透明胶带，暂时放在图书馆前台。',
    ),
    ItemPost(
      id: 'p003',
      type: PostType.lost,
      title: '蓝色保温杯',
      category: ItemCategory.daily,
      location: '第二食堂二楼',
      eventTime: base.subtract(const Duration(hours: 10)),
      contact: 'QQ 1024****215',
      createdAt: base.subtract(const Duration(hours: 9)),
      description: '杯身有轻微掉漆，杯盖是白色的。',
    ),
    ItemPost(
      id: 'p004',
      type: PostType.lost,
      title: '白色无线耳机充电盒',
      category: ItemCategory.digital,
      location: '体育馆羽毛球场 3 号场',
      eventTime: base.subtract(const Duration(days: 1, hours: 2)),
      contact: '微信 earbuds_li',
      createdAt: base.subtract(const Duration(days: 1)),
      description: '只有充电盒，盒盖内侧刻了一个字母 L。',
    ),
    ItemPost(
      id: 'p005',
      type: PostType.found,
      title: '《线性代数》课本',
      category: ItemCategory.book,
      location: '理科楼 A203',
      eventTime: base.subtract(const Duration(days: 1, hours: 5)),
      contact: '手机 157****3388',
      createdAt: base.subtract(const Duration(days: 1, hours: 3)),
      description: '扉页写了班级和姓名，已交给理科楼值班室。',
    ),
    ItemPost(
      id: 'p006',
      type: PostType.found,
      title: '一串宿舍钥匙（挂小熊挂件）',
      category: ItemCategory.key,
      location: '一号宿舍楼下快递柜旁',
      eventTime: base.subtract(const Duration(days: 2)),
      contact: '微信 key_help',
      createdAt: base.subtract(const Duration(days: 2)),
      description: '三把钥匙，挂了一个棕色小熊挂件。',
    ),
    ItemPost(
      id: 'p007',
      type: PostType.found,
      title: '灰色连帽卫衣',
      category: ItemCategory.clothing,
      location: '操场看台',
      eventTime: base.subtract(const Duration(days: 3)),
      contact: '手机 139****2200',
      createdAt: base.subtract(const Duration(days: 3)),
      description: '口袋里有一张校车票根。',
      status: PostStatus.resolved,
    ),
    ItemPost(
      id: 'p008',
      type: PostType.lost,
      title: '学生证（李同学）',
      category: ItemCategory.card,
      location: '校医院门口',
      eventTime: base.subtract(const Duration(days: 4)),
      contact: '微信 studentcard_li',
      createdAt: base.subtract(const Duration(days: 4)),
      description: '证件照是蓝色底，已经联系上拾到的同学。',
      status: PostStatus.resolved,
    ),
    ItemPost(
      id: 'p009',
      type: PostType.lost,
      title: '银色手机',
      category: ItemCategory.digital,
      location: '校车 3 号线',
      eventTime: base.subtract(const Duration(days: 5)),
      contact: 'QQ 8877****01',
      createdAt: base.subtract(const Duration(days: 5)),
      description: '手机壳是透明磨砂的，锁屏壁纸是猫。',
    ),
  ];
}
