import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../data/user_store.dart';
import '../models/item_post.dart';
import '../widgets/post_form.dart';

/// 发布界面（主界面）。
///
/// 对应《Basic Info》「Release Post」：用表单填写失物 / 招领信息，
/// 字段不合规时逐项提醒，发布成功后显式弹窗告知。
///
/// 表单实体在 [PostForm] 里（与编辑界面共用），本页只负责：
/// 顶部「清空」、提交后写入仓库、以及发布成功的弹窗。
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, this.onGoHome});

  /// 发布成功弹窗里「去首页看看」的动作，由外壳传入（切回首页标签）。
  final VoidCallback? onGoHome;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final GlobalKey<PostFormState> _formKey = PostForm.createKey();

  /// 清空表单：连同已出现的提醒一起复位。
  void _reset() => _formKey.currentState?.reset();

  /// 表单校验通过后才会走到这里（不通过时 [PostFormState.submit] 不会回调）。
  void _onSaved(ItemPost post) {
    PostScope.of(context).addPost(post);

    // 先清空表单，接着还能再发下一条。
    _reset();
    _showSuccessDialog(post.title);
  }

  /// 发布成功的显式提醒。
  void _showSuccessDialog(String title) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('publish-success-dialog'),
        icon: Icon(
          Icons.check_circle_rounded,
          size: 40,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: const Text('发布成功'),
        content: Text('“$title”已发布，回到首页就能看到它。'),
        actions: <Widget>[
          if (widget.onGoHome != null)
            TextButton(
              key: const Key('publish-success-go-home'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onGoHome!();
              },
              child: const Text('去首页看看'),
            ),
          FilledButton(
            key: const Key('publish-success-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布信息'),
        actions: <Widget>[
          TextButton(
            key: const Key('publish-reset-button'),
            onPressed: _reset,
            child: const Text('清空'),
          ),
        ],
      ),
      body: PostForm(
        key: _formKey,
        onSaved: _onSaved,
        // 账户里填过联系方式就带过来，省得每次重敲。
        initialContact: UserScope.maybeOf(context)?.contact,
      ),
    );
  }
}
