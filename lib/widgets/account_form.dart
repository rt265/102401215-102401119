import 'package:flutter/material.dart';

import '../models/user_account.dart';

/// 登记 / 修改账户的共用表单：一个称呼 + 一个常用联系方式。
///
/// 「我的」界面（未登记时的登记入口）与设置界面（登记、修改资料）用的是同一份
/// 字段与校验，所以只有这一处实现，不各写一份。
///
/// 控件的 Key 由 [keyPrefix] 拼出来（`<prefix>-name-field` 等）：两处都用到这个
/// 表单时，Key 不能撞车（`post_filter_bar.dart` 的 `keyPrefix` 是同一个理由）。
class AccountForm extends StatefulWidget {
  const AccountForm({
    super.key,
    this.initial,
    required this.onSubmit,
    this.onCancel,
    this.title,
    this.description,
    this.submitLabel = '保存',
    this.keyPrefix = 'account',
  });

  /// 用来回填的账户；`null` 表示新登记（字段留空）。
  final UserAccount? initial;

  /// 校验通过后的回调（两个值都已 trim）。
  ///
  /// 表单不碰 `UserStore`：写库与提示由调用方负责，这样同一个表单既能用来登记，
  /// 也能用来修改资料。
  final void Function(String displayName, String contact) onSubmit;

  /// 取消回调；`null` 表示不显示取消按钮。
  final VoidCallback? onCancel;

  /// 表单标题；`null` 表示不显示。
  final String? title;

  /// 标题下面的一句说明；`null` 表示不显示。
  final String? description;

  /// 提交按钮的文案。
  final String submitLabel;

  /// Key 前缀，见类文档。
  final String keyPrefix;

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // late + 惰性初始化：这样能在初始化时读 widget.initial 回填。
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initial?.displayName ?? '',
  );
  late final TextEditingController _contactController = TextEditingController(
    text: widget.initial?.contact ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    widget.onSubmit(
      _nameController.text.trim(),
      _contactController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? title = widget.title;
    final String? description = widget.description;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (description != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (title != null || description != null) const SizedBox(height: 12),
          TextFormField(
            key: Key('${widget.keyPrefix}-name-field'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '称呼',
              hintText: '例如：张同学',
              border: OutlineInputBorder(),
            ),
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? '请填写称呼' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: Key('${widget.keyPrefix}-contact-field'),
            controller: _contactController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '常用联系方式',
              hintText: '例如：手机 138****6621',
              helperText: '发布信息时自动带出，之后可以修改',
              border: OutlineInputBorder(),
            ),
            validator: (String? value) =>
                (value ?? '').trim().isEmpty ? '请填写联系方式' : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (widget.onCancel != null)
                TextButton(
                  key: Key('${widget.keyPrefix}-cancel'),
                  onPressed: widget.onCancel,
                  child: const Text('取消'),
                ),
              if (widget.onCancel != null) const SizedBox(width: 8),
              FilledButton(
                key: Key('${widget.keyPrefix}-submit'),
                onPressed: _submit,
                child: Text(widget.submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
