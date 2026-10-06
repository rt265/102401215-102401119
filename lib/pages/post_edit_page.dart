import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../models/item_post.dart';
import '../widgets/post_form.dart';

/// 编辑界面（次级界面，UI 事项 6）。
///
/// 对应《Basic Info》「Manage」中的「允许发布者修改发布内容」。
///
/// 表单实体与发布界面共用 [PostForm]，这里只做四件事：
/// 用原信息回填、保存时替换仓库里的同 id 信息、保存后把新信息交回「我的」界面，
/// 以及兜住「改到一半」的用户——返回前问一句，AppBar 里提供「还原」退回打开时的内容。
///
/// 界面入口在「我的」界面的卡片上（「修改」，见 UI 事项 3）。
class PostEditPage extends StatefulWidget {
  const PostEditPage({super.key, required this.post});

  /// 待修改的信息。
  final ItemPost post;

  @override
  State<PostEditPage> createState() => _PostEditPageState();
}

class _PostEditPageState extends State<PostEditPage> {
  final GlobalKey<PostFormState> _formKey = PostForm.createKey();

  /// 表单里有没有还没保存的改动，由 [PostFormState.isDirty] 经
  /// [PostForm.onChanged] 回填。
  ///
  /// 它管两件事：返回时要不要先确认、AppBar 里的「还原」能不能点。
  bool _dirty = false;

  /// 表单内容一变就重新读一次 [PostFormState.isDirty]。
  void _onFormChanged() {
    final bool dirty = _formKey.currentState?.isDirty ?? false;
    if (dirty != _dirty) {
      setState(() => _dirty = dirty);
    }
  }

  /// 表单校验通过后才会走到这里。
  void _onSaved(ItemPost updated) {
    PostScope.of(context).updatePost(updated);
    // 把改好的信息带回上一页，它好给出「已更新」的提示。
    Navigator.of(context).pop(updated);
  }

  /// 还原：把表单退回刚打开时的内容。
  ///
  /// 这同样是「丢掉没保存的输入」，所以和返回一样先确认。
  /// 仓库里的信息一直没动过，还原只是把表单改回原样，不写数据。
  Future<void> _restore() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool confirmed = await _confirm(
      key: const Key('edit-restore-dialog'),
      title: '还原为打开时的内容？',
      message: '“${widget.post.title}”还没保存的改动会丢掉；已保存的信息不受影响。',
      confirmLabel: '还原',
    );
    if (!confirmed || !mounted) {
      return;
    }

    // 同一个 reset()：新建表单时是「清空」，编辑表单时正是「还原」。
    // 复位后 PostForm 会回调 onChanged，_dirty 随之收回 false。
    _formKey.currentState?.reset();
    messenger.showSnackBar(const SnackBar(content: Text('已还原为打开时的内容')));
  }

  /// 返回：有未保存的改动时先问一句，避免白填一场。
  ///
  /// 表单与已保存的信息没有共享状态（[PostForm] 只读 [PostEditPage.post] 做初值），
  /// 直接返回不会改动仓库，所以这里只提醒「改动会丢」，不碰数据。
  Future<void> _cancel() async {
    // 没动过任何东西就直接走，不打扰用户。
    final bool discard = !_dirty || await _confirmDiscard();
    if (!discard || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  /// 放弃未保存改动的确认弹窗。
  Future<bool> _confirmDiscard() => _confirm(
    key: const Key('edit-discard-dialog'),
    title: '放弃这次修改？',
    message: '“${widget.post.title}”的改动还没有保存，返回后不会保留。',
    confirmLabel: '放弃修改',
  );

  /// 编辑界面里的确认弹窗：确认「执行」返回 `true`，选「继续编辑」返回 `false`。
  Future<bool> _confirm({
    required Key key,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: key,
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            key: const Key('edit-dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            key: const Key('edit-dialog-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<ItemPost>(
      // 有未保存的改动时先拦下系统返回（返回键 / 返回手势），问过再走。
      // 编辑界面保存时是直接 pop 的，不受这里影响。
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, ItemPost? result) {
        if (didPop) {
          return;
        }
        _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('修改信息'),
          leading: IconButton(
            key: const Key('edit-cancel-button'),
            tooltip: '返回',
            onPressed: _cancel,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: <Widget>[
            // 与发布界面「清空」同一个位置：那边回到空白，这边回到打开时的内容。
            // 没有改动时这个按钮没有意义，直接置灰。
            TextButton(
              key: const Key('edit-restore-button'),
              onPressed: _dirty ? _restore : null,
              child: const Text('还原'),
            ),
          ],
        ),
        body: PostForm(
          key: _formKey,
          onSaved: _onSaved,
          initial: widget.post,
          submitLabel: '保存修改',
          hint: '带 * 的为必填项；保存后首页与「我的」都会显示修改后的内容。',
          onChanged: _onFormChanged,
        ),
      ),
    );
  }
}
