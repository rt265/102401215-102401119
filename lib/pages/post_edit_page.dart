import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../models/item_post.dart';
import '../widgets/post_form.dart';

/// 编辑界面（次级界面）。
///
/// 对应《Basic Info》「Manage」中的「允许发布者修改发布内容」。
///
/// 表单实体与发布界面共用 [PostForm]，这里只做三件不同的事：
/// 用原信息回填、保存时替换仓库里的同 id 信息、保存后把新信息交回「我的」界面。
/// 界面入口在「我的」界面（UI 事项 3），表单本身的打磨属 UI 事项 6。
class PostEditPage extends StatefulWidget {
  const PostEditPage({super.key, required this.post});

  /// 待修改的信息。
  final ItemPost post;

  @override
  State<PostEditPage> createState() => _PostEditPageState();
}

class _PostEditPageState extends State<PostEditPage> {
  final GlobalKey<PostFormState> _formKey = PostForm.createKey();

  /// 表单校验通过后才会走到这里。
  void _onSaved(ItemPost updated) {
    PostScope.of(context).updatePost(updated);
    // 把改好的信息带回上一页，它好给出「已更新」的提示。
    Navigator.of(context).pop(updated);
  }

  /// 放弃本次修改。
  ///
  /// 表单与已保存的信息没有共享状态（[PostForm] 只读 [PostEditPage.post] 做初值），
  /// 直接返回不会改动仓库，所以这里不弹「是否放弃」。
  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改信息'),
        leading: IconButton(
          key: const Key('edit-cancel-button'),
          tooltip: '返回',
          onPressed: _cancel,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: PostForm(
        key: _formKey,
        initial: widget.post,
        submitLabel: '保存修改',
        hint: '带 * 的为必填项；保存后首页与「我的」都会显示修改后的内容。',
        onSaved: _onSaved,
      ),
    );
  }
}
