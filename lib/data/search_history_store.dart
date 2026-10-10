import 'package:flutter/widgets.dart';

import 'search_history_repository.dart';

/// 搜索记录仓库。
///
/// 与 `PostStore` / `UserStore` / `SettingsStore` 一个套路：内存里留一份
/// 「最近搜过的词」给搜索界面**同步**读取，有仓储时每次改动顺手写进本地库，
/// 启动时用 [load] 读回上次留下的那几个词。
///
/// 列表里的顺序就是显示顺序：**最近搜的排在最前**，长度不超过 [maxKeywords]。
/// 这两个规矩都在这里落地（[record] 一手包办），所以界面只管画，
/// 不必自己判重、自己截断。
class SearchHistoryStore extends ChangeNotifier {
  /// 最多留几个词。
  ///
  /// 10 是「一屏放得下、又足够复现上一次找东西的过程」的量：
  /// 再多也不会有人往下翻，反而把引导语挤没了。
  static const int maxKeywords = 10;

  /// [repository] 为空时是纯内存实现（测试与预览走这条）；
  /// [initialKeywords] 是读库之前的初值，配合 [repository] 使用时以库里的为准。
  SearchHistoryStore({
    this.repository,
    List<String>? initialKeywords,
  }) : _keywords = List<String>.of(
         (initialKeywords ?? const <String>[]).take(maxKeywords),
       );

  /// 搜索记录仓储；空表示这次运行不落盘（测试与预览走这条）。
  final SearchHistoryRepository? repository;

  final List<String> _keywords;

  /// 最近搜过的关键词，最近在前。
  List<String> get keywords => List<String>.unmodifiable(_keywords);

  /// 有没有搜索记录——搜索界面据此决定要不要摆出「最近搜索」那一块。
  bool get isEmpty => _keywords.isEmpty;

  /// 从本地库把搜索记录读进内存。
  ///
  /// 启动时调一次（`main()`）；纯内存实现下什么都不做。
  Future<void> load() async {
    final SearchHistoryRepository? repository = this.repository;
    if (repository == null) {
      return;
    }

    _keywords
      ..clear()
      ..addAll(await repository.loadKeywords(limit: maxKeywords));
    notifyListeners();
  }

  /// 记下一个关键词：[keyword] 排到最前，超出的老词丢掉。
  ///
  /// 空词（或只有空白的）直接忽略：用户敲了空格就提交很常见，
  /// 那不是一次搜索，不该占一格。
  ///
  /// 同一个词再搜一次只是挪到最前，列表里不会出现两遍——判重时忽略大小写
  /// （`IPHONE` 与 `iphone` 是同一个词，库里也只会留一行）。
  Future<void> record(String keyword) async {
    final String word = keyword.trim();
    if (word.isEmpty) {
      return;
    }

    final String folded = word.toLowerCase();
    final int existing = _keywords.indexWhere(
      (String item) => item.toLowerCase() == folded,
    );

    // 已经在最前：列表不用动，但库里的时间还是要往前推一推，
    // 不然库里按时间排出来的顺序会和屏幕上看到的不一样。
    // （屏幕上看到的就是要它留在最前，所以这种时候不必通知界面重建。）
    final bool alreadyFirst = existing == 0;

    // 老的那份先摘掉（连同它原来的位置），新的插到最前，
    // 这样「同一个词只出现一遍、而且排在最前」是一步到位的。
    if (existing != -1) {
      _keywords.removeAt(existing);
    }
    _keywords.insert(0, word);
    if (_keywords.length > maxKeywords) {
      _keywords.removeRange(maxKeywords, _keywords.length);
    }

    final SearchHistoryRepository? repository = this.repository;
    if (repository != null) {
      await repository.addKeyword(word, DateTime.now());
    }
    if (!alreadyFirst) {
      notifyListeners();
    }
  }

  /// 删掉一个关键词（「最近搜索」里那个小叉）。
  Future<void> removeKeyword(String keyword) async {
    final int before = _keywords.length;
    _keywords.removeWhere((String item) => item == keyword);
    if (_keywords.length == before) {
      return;
    }
    notifyListeners();

    final SearchHistoryRepository? repository = this.repository;
    if (repository != null) {
      await repository.removeKeyword(keyword);
    }
  }

  /// 清空搜索记录。
  Future<void> clear() async {
    if (_keywords.isEmpty) {
      return;
    }
    _keywords.clear();
    notifyListeners();

    final SearchHistoryRepository? repository = this.repository;
    if (repository != null) {
      await repository.clearKeywords();
    }
  }
}

/// 把 [SearchHistoryStore] 沿 widget 树下发。
///
/// 与 `PostScope` / `SettingsScope` 一样用 [InheritedNotifier]：
/// 记录一变，读过它的界面（搜索界面）自动重建。
class SearchHistoryScope extends InheritedNotifier<SearchHistoryStore> {
  const SearchHistoryScope({
    super.key,
    required SearchHistoryStore store,
    required super.child,
  }) : super(notifier: store);

  /// 取当前仓库并订阅它的变化。
  static SearchHistoryStore of(BuildContext context) {
    final SearchHistoryScope? scope = context
        .dependOnInheritedWidgetOfExactType<SearchHistoryScope>();
    assert(
      scope != null,
      '未找到 SearchHistoryScope：页面需要放在 LostAndFoundApp 之下。',
    );
    return scope!.notifier!;
  }
}
