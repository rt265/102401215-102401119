import 'package:flutter/material.dart';

import '../data/post_store.dart';
import '../models/item_post.dart';
import '../utils/time_format.dart';

/// 发布界面（主界面）。
///
/// 对应《Basic Info》「Release Post」：用表单填写失物 / 招领信息，
/// 字段不合规时逐项提醒，发布成功后显式弹窗告知。
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, this.onGoHome});

  /// 发布成功弹窗里「去首页看看」的动作，由外壳传入（切回首页标签）。
  final VoidCallback? onGoHome;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  /// 第一次提交失败后改为 [AutovalidateMode.onUserInteraction]：
  /// 提醒过一次之后，边填边校验，不必反复点发布。
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  // 以下字段由各个表单项的 onSaved 在提交通过校验后写入。
  PostType? _type;
  String _title = '';
  ItemCategory? _category;
  String _location = '';
  DateTime? _eventTime;
  String _description = '';
  String _contact = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 表单里文本输入框的统一外观。
  InputDecoration _decoration(String hint, {String? helper}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }

  /// 选择丢失 / 拾取的时间：先选日期，再选时刻。
  Future<void> _pickEventTime(FormFieldState<DateTime> field) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: field.value ?? now,
      firstDate: DateTime(now.year - 5),
      // 事情已经发生过，时间不可能晚于此刻。
      lastDate: now,
      helpText: '选择日期',
    );
    if (date == null || !mounted) {
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(field.value ?? now),
      helpText: '选择时间',
    );
    if (time == null || !mounted) {
      return;
    }

    field.didChange(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  /// 清空表单：连同已出现的提醒一起复位。
  void _reset() {
    _formKey.currentState?.reset();
    setState(() => _autovalidateMode = AutovalidateMode.disabled);
  }

  /// 把视口带回表单顶部，让最前面的提醒可见。
  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null) {
      return;
    }

    if (!form.validate()) {
      // 不合规：不发布，只把提醒显示出来。
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      _scrollToTop();
      return;
    }

    form.save();

    final DateTime now = DateTime.now();
    final ItemPost post = ItemPost(
      // TODO(storage): 接入本地 SQLite 后由数据库生成主键。
      id: 'local-${now.microsecondsSinceEpoch}',
      type: _type!,
      title: _title,
      category: _category!,
      location: _location,
      eventTime: _eventTime!,
      contact: _contact,
      createdAt: now,
      description: _description.isEmpty ? null : _description,
    );

    PostScope.of(context).addPost(post);

    final String title = _title;
    // 先清空表单，接着还能再发下一条。
    _reset();
    _showSuccessDialog(title);
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
    final ThemeData theme = Theme.of(context);

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
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: SingleChildScrollView(
          key: const Key('publish-form'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '带 * 的为必填项；发布后可以回到首页查看这条信息。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              const _FieldLabel('信息类型', isRequired: true),
              _TypeSelector(onSaved: (PostType? value) => _type = value),
              const SizedBox(height: 18),

              const _FieldLabel('物品名称', isRequired: true),
              TextFormField(
                key: const Key('publish-title-field'),
                textInputAction: TextInputAction.next,
                decoration: _decoration('例如：校园一卡通（蓝色卡套）'),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? '请填写物品名称' : null,
                onSaved: (String? value) => _title = value!.trim(),
              ),
              const SizedBox(height: 18),

              const _FieldLabel('物品分类', isRequired: true),
              _CategorySelector(
                onSaved: (ItemCategory? value) => _category = value,
              ),
              const SizedBox(height: 18),

              const _FieldLabel('地点', isRequired: true),
              TextFormField(
                key: const Key('publish-location-field'),
                textInputAction: TextInputAction.next,
                decoration: _decoration('例如：图书馆一楼大厅'),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? '请填写地点' : null,
                onSaved: (String? value) => _location = value!.trim(),
              ),
              const SizedBox(height: 18),

              const _FieldLabel('时间', isRequired: true),
              _EventTimeField(
                onTap: _pickEventTime,
                onSaved: (DateTime? value) => _eventTime = value,
              ),
              const SizedBox(height: 18),

              const _FieldLabel('描述'),
              TextFormField(
                key: const Key('publish-description-field'),
                maxLines: 4,
                maxLength: 200,
                decoration: _decoration('颜色、特征、存放位置等，写清楚更容易对上'),
                onSaved: (String? value) => _description = value!.trim(),
              ),
              const SizedBox(height: 10),

              const _FieldLabel('联系方式', isRequired: true),
              TextFormField(
                key: const Key('publish-contact-field'),
                textInputAction: TextInputAction.done,
                decoration: _decoration(
                  '例如：手机 138****6621',
                  helper: '留下手机号 / 微信 / QQ，方便对方联系你',
                ),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? '请填写联系方式' : null,
                onSaved: (String? value) => _contact = value!.trim(),
              ),
              const SizedBox(height: 18),

              const _FieldLabel('图片'),
              const _ImagePlaceholder(),
              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const Key('publish-submit-button'),
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded, size: 20),
                  label: const Text('发布信息'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表单里每个字段上方的小标题：必填项带红色星号，选填项标注「（选填）」。
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    // 分成两个 Text（而不是 Text.rich），测试里可以直接按文案找到字段标题。
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            text,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            isRequired ? ' *' : '（选填）',
            style: theme.textTheme.labelLarge?.copyWith(
              color: isRequired ? scheme.error : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 自定义表单项校验失败时的红字提醒，风格与 [InputDecorator] 的错误文案一致。
class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Text(
        message,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}

/// 失物 / 招领的类型选择。
///
/// 用 [FormField] 包住 [SegmentedButton]，让它和文本字段一样参与表单校验：
/// 没选类型就提交时，同样会在这里给出提醒。
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.onSaved});

  final FormFieldSetter<PostType> onSaved;

  @override
  Widget build(BuildContext context) {
    return FormField<PostType>(
      key: const Key('publish-type-field'),
      onSaved: onSaved,
      validator: (PostType? value) => value == null ? '请选择信息类型' : null,
      builder: (FormFieldState<PostType> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SegmentedButton<PostType>(
              key: const Key('publish-type-selector'),
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: <ButtonSegment<PostType>>[
                for (final PostType type in PostType.values)
                  ButtonSegment<PostType>(
                    value: type,
                    label: Text(type.label),
                    icon: Icon(type.icon),
                  ),
              ],
              selected: <PostType>{
                if (field.value != null) field.value!,
              },
              onSelectionChanged: (Set<PostType> selection) => field
                  .didChange(selection.isEmpty ? null : selection.first),
            ),
            if (field.hasError) _FieldError(field.errorText!),
          ],
        );
      },
    );
  }
}

/// 物品分类选择：8 个分类用 chip 平铺，和首页的筛选条手感一致。
class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.onSaved});

  final FormFieldSetter<ItemCategory> onSaved;

  @override
  Widget build(BuildContext context) {
    return FormField<ItemCategory>(
      key: const Key('publish-category-field'),
      onSaved: onSaved,
      validator: (ItemCategory? value) => value == null ? '请选择物品分类' : null,
      builder: (FormFieldState<ItemCategory> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final ItemCategory category in ItemCategory.values)
                  ChoiceChip(
                    key: Key('publish-category-${category.name}'),
                    label: Text(category.label),
                    avatar: Icon(category.icon, size: 18),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    selected: field.value == category,
                    onSelected: (bool _) => field.didChange(category),
                  ),
              ],
            ),
            if (field.hasError) _FieldError(field.errorText!),
          ],
        );
      },
    );
  }
}

/// 丢失 / 拾取时间：点开后依次选日期与时刻。
class _EventTimeField extends StatelessWidget {
  const _EventTimeField({required this.onTap, required this.onSaved});

  final Future<void> Function(FormFieldState<DateTime> field) onTap;
  final FormFieldSetter<DateTime> onSaved;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return FormField<DateTime>(
      key: const Key('publish-time-field'),
      onSaved: onSaved,
      validator: (DateTime? value) {
        if (value == null) {
          return '请选择时间';
        }
        if (value.isAfter(DateTime.now())) {
          return '时间不能晚于此刻';
        }
        return null;
      },
      builder: (FormFieldState<DateTime> field) {
        final DateTime? value = field.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              key: const Key('publish-time-picker'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(field),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: field.hasError ? scheme.error : scheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value == null
                            ? '选择丢失 / 拾取的时间'
                            : formatDateTime(value),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: value == null ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_calendar_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError) _FieldError(field.errorText!),
          ],
        );
      },
    );
  }
}

/// 图片（选填）的占位说明。
///
/// TODO(image): 接入本地存储后再做选图、缩略图与删除；现在只给说明，
/// 不放一个点了没反应的假按钮。
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.add_photo_alternate_outlined,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '暂不支持选择图片，将在接入本地存储时实现。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
