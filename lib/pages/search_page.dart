import 'package:flutter/material.dart';

import '../data/post_store.dart';
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
/// 和数据的关系只有一条：结果**每次从 [PostStore] 现查**，不自己留一份快照，
/// 别处改了 / 删了信息，这里的结果跟着变（与详情页同一套规矩）。
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
  static const List<String> _hotKeywords = <String>[
    '雨伞',
    '一卡通',
    '钥匙',
    '耳机',
  ];

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

  /// 点「试试这些关键词」：把词填进输入框再搜，用户看得见自己搜了什么。
  void _searchKeyword(String keyword) {
    _controller.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
    setState(() {
      _keyword = keyword;
      _clearFiltersQuiet();
    });
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
          onSubmitted: (String _) => FocusScope.of(context).unfocus(),
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
          Expanded(child: _buildBody(query: query, posts: posts, results: results)),
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
        onPick: _searchKeyword,
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

/// 还没输入关键词时的引导：说明能搜什么，并给几个能直接点的词。
class _SearchIntro extends StatelessWidget {
  const _SearchIntro({required this.keywords, required this.onPick});

  final List<String> keywords;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      key: const Key('search-intro'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              size: 56,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text('搜索校园里的失物与招领', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '物品名称、地点、描述里的词都能搜。\n比如「雨伞」「图书馆」「学生证」。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            _KeywordChips(keywords: keywords, onPick: onPick),
          ],
        ),
      ),
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
              '换个说法试试，比如只留物品名称里的两个字；\n也可以直接点下面的词。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
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
              '关键词本身是找得到的，只是被类型或分类筛掉了。放宽筛选就能看到。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
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
          style: Theme.of(context)
              .textTheme
              .labelLarge
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
