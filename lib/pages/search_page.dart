import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../data/search_history_store.dart';
import '../models/item_post.dart';
import '../models/post_query.dart';
import '../widgets/post_card.dart';
import '../widgets/post_filter_bar.dart';
import 'post_detail_page.dart';

/// 搜索界面（次级界面）。
///
/// 对应《Basic Info》的「Search」：首页顶部的搜索栏把用户送到这里，
/// 用户按物品名称一类的关键词找信息，结果还能再用筛选器缩小。
///
/// 和数据的关系有两条：
/// - 结果**每次从 [PostStore] 现查**，不自己留一份快照，别处改了 / 删了信息，
///   这里的结果跟着变（与详情页同一套规矩）；
/// - 「最近搜索」来自 [SearchHistoryStore]（落在本地库，关掉应用也在），
///   只有**明确的搜索动作**才记一笔——敲回车、点最近搜索里的词、点示例词，
///   边打字边记会把每个前缀都塞进去。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.onGoHome});

  /// 从搜索结果打开详情后，详情页发现信息已被删除时要回的地方，由首页注入。
  ///
  /// 搜索界面本身没有管理入口（标记 / 修改 / 删除都在「我的」），
  /// 但详情页的空态按钮需要一条出路，所以照首页的做法一路传下去。
  final VoidCallback? onGoHome;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  /// 还没输入时给几个能点的例子：比一句“请输入关键词”有用，
  /// 也顺带告诉用户关键词可以是什么样子（物品名、地点都行）。
  static const List<String> _hotKeywords = <String>['雨伞', '一卡通', '钥匙', '耳机'];

  final TextEditingController _controller = TextEditingController();

  /// 当前关键词。输入即搜（数据在本地，不必等提交）。
  String _keyword = '';

  /// `null` 表示“全部”。
  PostType? _typeFilter;

  /// `null` 表示“全部分类”。
  ItemCategory? _categoryFilter;

  PostSortBy _sortBy = PostSortBy.newest;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasKeyword => _keyword.trim().isNotEmpty;

  PostQuery get _query => PostQuery(
    keyword: _keyword,
    type: _typeFilter,
    category: _categoryFilter,
    sortBy: _sortBy,
  );

  /// 输入框内容变化：输入即搜。
  void _onKeywordChanged(String value) {
    setState(() {
      _keyword = value;
      _clearFiltersQuiet();
    });
  }

  /// 点「试试这些关键词」/ 点「最近搜索」里的词：把词填进输入框再搜，
  /// 用户看得见自己搜了什么。这两种点击都算一次明确的搜索，顺手记一笔。
  void _searchKeyword(String keyword) {
    _controller.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
    setState(() {
      _keyword = keyword;
      _clearFiltersQuiet();
    });
    SearchHistoryScope.of(context).record(keyword);
  }

  /// 键盘上的搜索键：这次输入到此为止，记一笔再收起键盘。
  ///
  /// 边打字边记（`onChanged`）是不行的：敲「一卡通」会先记下「一」「一卡」……
  /// 把整个列表占满。
  void _onSubmitted(String value) {
    FocusScope.of(context).unfocus();
    SearchHistoryScope.of(context).record(value);
  }

  /// 删掉「最近搜索」里的一条。
  Future<void> _removeHistory(String keyword) async {
    await SearchHistoryScope.of(context).removeKeyword(keyword);
  }

  /// 清空搜索记录：这条动作收不回来，先问一句。
  Future<void> _clearHistory() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('清空搜索记录？'),
        content: const Text('清空后「最近搜索」就不剩什么了。'),
        actions: <Widget>[
          TextButton(
            key: const Key('search-history-clear-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('search-history-clear-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }
    await SearchHistoryScope.of(context).clear();
  }

  void _clearKeyword() {
    _controller.clear();
    setState(() {
      _keyword = '';
      _clearFiltersQuiet();
    });
  }

  /// 点「清除筛选」：关键词留着，只把筛选清掉。
  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _categoryFilter = null;
    });
  }

  /// 关键词空了，筛选条也藏起来了，留着上一轮的筛选就成了看不见的条件。
  void _clearFiltersQuiet() {
    if (_keyword.trim().isEmpty) {
      _typeFilter = null;
      _categoryFilter = null;
    }
  }

  void _openDetail(ItemPost post) {
    // 进详情前收起键盘，否则输入法会一直压着屏幕下半截。
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          postId: post.id,
          onGoHome: widget.onGoHome == null ? null : _backToHome,
        ),
      ),
    );
  }

  /// 详情页空态里的「回到首页」：先退掉搜索界面自己，再让外壳切回首页标签。
  void _backToHome() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    widget.onGoHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    final PostQuery query = _query;
    final List<ItemPost> posts = PostScope.of(context).posts;
    final List<ItemPost> results = query.apply(posts);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('search-back-button'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: TextField(
          key: const Key('search-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: const InputDecoration(
            hintText: '搜索物品名称、地点或描述',
            border: InputBorder.none,
          ),
          onChanged: _onKeywordChanged,
          onSubmitted: _onSubmitted,
        ),
        actions: <Widget>[
          if (_keyword.isNotEmpty)
            IconButton(
              key: const Key('search-clear'),
              tooltip: '清空',
              onPressed: _clearKeyword,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 还没输入时没有结果可筛，筛选条这时只是噪音，等有关键词再出现。
          if (_hasKeyword) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: PostFilterBar(
                keyPrefix: 'search-filter',
                typeFilter: _typeFilter,
                categoryFilter: _categoryFilter,
                sortBy: _sortBy,
                onTypeChanged: (PostType? value) =>
                    setState(() => _typeFilter = value),
                onCategoryChanged: (ItemCategory? value) =>
                    setState(() => _categoryFilter = value),
                onSortChanged: (PostSortBy value) =>
                    setState(() => _sortBy = value),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: _buildBody(query: query, posts: posts, results: results),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required PostQuery query,
    required List<ItemPost> posts,
    required List<ItemPost> results,
  }) {
    if (!query.hasKeyword) {
      return _SearchIntro(
        keywords: _hotKeywords,
        history: SearchHistoryScope.of(context).keywords,
        onPick: _searchKeyword,
        onRemoveHistory: _removeHistory,
        onClearHistory: _clearHistory,
      );
    }

    if (results.isEmpty) {
      // 分清两种“没结果”：关键词本身就没沾到边，还是被筛选筛掉了——
      // 两者的下一步动作不一样（换个词 / 放宽筛选）。
      final bool keywordHit = posts.any(
        (ItemPost post) => post.matchesKeyword(_keyword),
      );
      return keywordHit
          ? _FilteredOutResult(onClear: _clearFilters)
          : _NoMatchResult(
              keyword: _keyword.trim(),
              keywords: _hotKeywords,
              onPick: _searchKeyword,
            );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '找到 ${results.length} 条相关信息',
              key: const Key('search-result-count'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('search-results'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: results.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) => PostCard(
              post: results[index],
              onTap: () => _openDetail(results[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// 还没输入关键词时的引导：说明能搜什么，给出最近搜过的词和几个能直接点的词。
///
/// 这一屏是纵向排下来的（说明 → 最近搜索 → 示例词），不用居中布局：
/// 有了「最近搜索」之后内容会变高，居中会让它在窄屏上从中间被切掉。
/// 横向仍然居中，读起来还是引导的样子。
///
/// **搜过东西之后就不再解释「这里能搜什么」了**：用户已经用过了，图标和那句
/// 说明只是挡在「最近搜索」前面的噪音，这时直接把最近搜索顶到最上面。
class _SearchIntro extends StatelessWidget {
  const _SearchIntro({
    required this.keywords,
    required this.history,
    required this.onPick,
    required this.onRemoveHistory,
    required this.onClearHistory,
  });

  final List<String> keywords;
  final List<String> history;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemoveHistory;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final bool fresh = history.isEmpty;

    return SingleChildScrollView(
      key: const Key('search-intro'),
      padding: EdgeInsets.fromLTRB(24, fresh ? 32 : 16, 24, 24),
      child: Column(
        // 撑满整行：不然 Column 只按最宽的子控件取宽，居中/两端对齐都无从谈起。
        // 没有搜索记录时子控件最窄，整块内容会贴着左边——这就是「提示偏左」的成因。
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (fresh) ...<Widget>[
            Icon(
              Icons.search_rounded,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              '搜索校园里的失物与招领',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '物品名称、地点、描述里的词都能搜。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          // 没搜过任何东西时不摆这块——空标题加一个「清空」按钮只是噪音。
          if (history.isNotEmpty) ...<Widget>[
            if (!fresh) const SizedBox(height: 8),
            _SearchHistorySection(
              history: history,
              onPick: onPick,
              onRemove: onRemoveHistory,
              onClear: onClearHistory,
            ),
          ],
          const SizedBox(height: 28),
          _KeywordChips(keywords: keywords, onPick: onPick),
        ],
      ),
    );
  }
}

/// 「最近搜索」区块：标题 + 清空按钮 + 若干能直接点的词，每个词带个删除小叉。
///
/// 顺序就是 [SearchHistoryStore] 给的顺序（最近搜的在最前），这里不再排序。
///
/// 标题行用 `spaceBetween`，「清空」靠右——这要求外层把宽度撑满
/// （`_SearchIntro` 的 `crossAxisAlignment: stretch` 就是为此）。
class _SearchHistorySection extends StatelessWidget {
  const _SearchHistorySection({
    required this.history,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      key: const Key('search-history'),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '最近搜索',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              key: const Key('search-history-clear'),
              onPressed: onClear,
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final String keyword in history)
              InputChip(
                key: Key('search-history-$keyword'),
                label: Text(keyword),
                onPressed: () => onPick(keyword),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                // 不弹 tooltip：词本身就写在 chip 上了，悬浮提示反而挡视线。
                deleteButtonTooltipMessage: '',
                onDeleted: () => onRemove(keyword),
              ),
          ],
        ),
      ],
    );
  }
}

/// 关键词没沾到任何信息时的空态。
class _NoMatchResult extends StatelessWidget {
  const _NoMatchResult({
    required this.keyword,
    required this.keywords,
    required this.onPick,
  });

  final String keyword;
  final List<String> keywords;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      key: const Key('search-empty-keyword'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到与「$keyword」相关的信息',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '换个说法试试？',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _KeywordChips(keywords: keywords, onPick: onPick),
          ],
        ),
      ),
    );
  }
}

/// 关键词找得到东西、只是被筛选条件筛空了的空态。
class _FilteredOutResult extends StatelessWidget {
  const _FilteredOutResult({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      key: const Key('search-empty-filter'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.filter_alt_off_rounded,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('当前筛选条件下没有结果', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '放宽筛选试试？',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              key: const Key('search-clear-filters'),
              onPressed: onClear,
              child: const Text('清除筛选'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 几个示例关键词，点一下就用它搜。
class _KeywordChips extends StatelessWidget {
  const _KeywordChips({required this.keywords, required this.onPick});

  final List<String> keywords;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '试试这些关键词',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final String keyword in keywords)
              ActionChip(
                key: Key('search-suggestion-$keyword'),
                label: Text(keyword),
                onPressed: () => onPick(keyword),
              ),
          ],
        ),
      ],
    );
  }
}
