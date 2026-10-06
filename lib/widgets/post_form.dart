import 'package:flutter/material.dart';

import '../data/user_store.dart';
import '../models/item_post.dart';
import '../utils/time_format.dart';

/// 发布界面与编辑界面共用的信息表单。
///
/// 《Basic Info》里「发布」与「编辑」填的是同一组字段，校验规则也完全一致，
/// 所以表单实体只写一份：两个界面各自套一层 AppBar 与提交后的流程即可。
/// （发布界面负责「发布成功」弹窗与清空，编辑界面负责回填与保存。）
///
/// 用 [PostForm.createKey] 建 key，拿到 [PostFormState] 复用外部控制：
///
/// ```dart
/// final GlobalKey<PostFormState> _formKey = PostForm.createKey();
/// ...
/// _formKey.currentState?.save();   // 校验通过后写入并回调
/// _formKey.currentState?.reset();  // 清空表单与已出现的提醒
/// ```
class PostForm extends StatefulWidget {
  const PostForm({
    super.key,
    required this.onSaved,
    this.initial,
    this.initialContact,
    this.submitLabel = '发布信息',
    this.hint = '带 * 的为必填项。',
  });

  /// 校验通过后回传组装好的信息。
  ///
  /// 新建时 [ItemPost.id] 已按 `local-<微秒时间戳>` 生成；
  /// 编辑时除被改动的字段外其余原样保留。
  final ValueChanged<ItemPost> onSaved;

  /// 被编辑的信息；`null` 表示新建。
  final ItemPost? initial;

  /// 新建时的默认联系方式，由「我的」界面的账户信息提供。
  final String? initialContact;

  /// 底部提交按钮的文案。
  final String submitLabel;

  /// 表单顶部的一行说明。
  final String hint;

  /// 建一个可以拿到 [PostFormState] 的 key。
  static GlobalKey<PostFormState> createKey() =>
      GlobalKey<PostFormState>(debugLabel: 'PostForm');

  @override
  State<PostForm> createState() => PostFormState();
}

/// [PostForm] 的状态：文本字段的初值、校验与保存都在这里。
class PostFormState extends State<PostForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  /// 第一次提交失败后改为 [AutovalidateMode.onUserInteraction]：
  /// 提醒过一次之后，边填边校验，不必反复点提交。
  ///
  /// 编辑界面一进来就是 [AutovalidateMode.onUserInteraction]，
  /// 清空某个必填项时立刻能看到提醒。
  late AutovalidateMode _autovalidateMode = widget.initial == null
      ? AutovalidateMode.disabled
      : AutovalidateMode.onUserInteraction;

  // 下面几个控制器是为「清空」准备的：TextField 只有带 controller
  // 或 initialValue 时才能被 FormState.reset() 复位。
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _locationController =
      TextEditingController(text: widget.initial?.location ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final TextEditingController _contactController =
      TextEditingController(text: _initialContact);

  // 已选的值同样带初值，改动由下面各个选择器回写：
  // 文本字段用 controller，选择项用这几个字段（它们不在 controller 的管辖范围内）。
  late PostType? _type = widget.initial?.type;

  late ItemCategory? _category = widget.initial?.category;

  late DateTime? _eventTime = widget.initial?.eventTime;

  String get _initialContact =>
      widget.initial?.contact ?? widget.initialContact ?? '';

  /// 上一次由账户带进「联系方式」的值，用来避免覆盖用户自己的输入。
  String? _autoFilledContact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAccountContact();
  }

  /// 把账户里的联系方式填进空的联系方式字段。
  ///
  /// 发布界面挂在主页外壳里，进页面时账户可能还没登记；
  /// 等到用户登记完再切回来，这里再把默认值补上。
  void _syncAccountContact() {
    final String? accountContact = UserScope.maybeOf(context)?.contact;
    if (accountContact == null || accountContact.isEmpty) {
      return;
    }
    if (_autoFilledContact == accountContact) {
      return;
    }
    if (_contactController.text.trim().isNotEmpty) {
      return;
    }
    _autoFilledContact = accountContact;
    _contactController.text = accountContact;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  /// 把视口带回表单顶部，让最前面的提醒可见。
  void scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// 校验表单：不通过时只把提醒显示出来并返回 `null`，不产生任何信息。
  ///
  /// 调用方拿 `null` 就什么都不做（编辑界面不会白关掉页面）。
  ItemPost? save() {
    final FormState? form = _formKey.currentState;
    if (form == null) {
      return null;
    }

    if (!form.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      scrollToTop();
      return null;
    }

    form.save();

    final DateTime now = DateTime.now();
    final ItemPost? initial = widget.initial;
    final ItemPost post = initial == null
        ? ItemPost(
            // TODO(storage): 接入本地 SQLite 后由数据库生成主键。
            id: 'local-${now.microsecondsSinceEpoch}',
            type: _type!,
            title: _titleController.text.trim(),
            category: _category!,
            location: _locationController.text.trim(),
            eventTime: _eventTime!,
            contact: _contactController.text.trim(),
            createdAt: now,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            // 本机用户发布的信息，「我的」界面会把它列出来。
            isMine: true,
          )
        : initial.copyWith(
            type: _type,
            title: _titleController.text.trim(),
            category: _category,
            location: _locationController.text.trim(),
            eventTime: _eventTime,
            contact: _contactController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );

    return post;
  }

  /// 校验通过后写入表单并回调 [PostForm.onSaved]。
  void submit() {
    final ItemPost? post = save();
    if (post == null) {
      return;
    }
    widget.onSaved(post);
  }

  /// 清空表单：连同已出现的提醒一起复位。
  ///
  /// 账户里登记过的联系方式会重新填上——同一个人接着发下一条时，
  /// 不必再手打一遍。
  void reset() {
    _formKey.currentState?.reset();
    setState(() => _autovalidateMode = AutovalidateMode.disabled);
    _autoFilledContact = null;
    _syncAccountContact();
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

    final DateTime value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    field.didChange(value);
    _eventTime = value;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
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
              widget.hint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            const _FieldLabel('信息类型', isRequired: true),
            _TypeSelector(
              initialValue: _type,
              onChanged: (PostType? value) => _type = value,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('物品名称', isRequired: true),
            TextFormField(
              key: const Key('publish-title-field'),
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: _decoration('例如：校园一卡通（蓝色卡套）'),
              validator: (String? value) =>
                  (value ?? '').trim().isEmpty ? '请填写物品名称' : null,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('物品分类', isRequired: true),
            _CategorySelector(
              initialValue: _category,
              onChanged: (ItemCategory? value) => _category = value,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('地点', isRequired: true),
            TextFormField(
              key: const Key('publish-location-field'),
              controller: _locationController,
              textInputAction: TextInputAction.next,
              decoration: _decoration('例如：图书馆一楼大厅'),
              validator: (String? value) =>
                  (value ?? '').trim().isEmpty ? '请填写地点' : null,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('时间', isRequired: true),
            _EventTimeField(
              initialValue: _eventTime,
              onTap: _pickEventTime,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('描述'),
            TextFormField(
              key: const Key('publish-description-field'),
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 200,
              decoration: _decoration('颜色、特征、存放位置等，写清楚更容易对上。注意保护个人隐私'),
            ),
            const SizedBox(height: 10),

            const _FieldLabel('联系方式', isRequired: true),
            TextFormField(
              key: const Key('publish-contact-field'),
              controller: _contactController,
              textInputAction: TextInputAction.done,
              decoration: _decoration(
                '例如：手机 138****6621',
                helper: '留下手机号 / 微信 / QQ，方便对方联系你',
              ),
              validator: (String? value) =>
                  (value ?? '').trim().isEmpty ? '请填写联系方式' : null,
            ),
            const SizedBox(height: 18),

            const _FieldLabel('图片'),
            const _ImagePlaceholder(),
            const SizedBox(height: 24),

            SizedBox(
              height: 48,
              child: FilledButton.icon(
                // 表单里的控件沿用 `publish-` 前缀的 key：发布与编辑填的是同一组字段，
                // 两个界面共用这套 key 后，widget 测试的填写流程也能共用。
                key: const Key('publish-submit-button'),
                onPressed: submit,
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(widget.submitLabel),
              ),
            ),
          ],
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
  const _TypeSelector({required this.onChanged, this.initialValue});

  final ValueChanged<PostType?> onChanged;
  final PostType? initialValue;

  @override
  Widget build(BuildContext context) {
    return FormField<PostType>(
      key: const Key('publish-type-field'),
      initialValue: initialValue,
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
              onSelectionChanged: (Set<PostType> selection) {
                final PostType? value =
                    selection.isEmpty ? null : selection.first;
                field.didChange(value);
                onChanged(value);
              },
            ),
            if (field.hasError) _FieldError(field.errorText!),
          ],
        );
      },
    );
  }
}

/// 物品分类选择：分类用 chip 平铺，和首页的筛选条手感一致。
class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.onChanged, this.initialValue});

  final ValueChanged<ItemCategory> onChanged;
  final ItemCategory? initialValue;

  @override
  Widget build(BuildContext context) {
    return FormField<ItemCategory>(
      key: const Key('publish-category-field'),
      initialValue: initialValue,
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
                    onSelected: (bool _) {
                      field.didChange(category);
                      onChanged(category);
                    },
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
  const _EventTimeField({required this.onTap, this.initialValue});

  final Future<void> Function(FormFieldState<DateTime> field) onTap;
  final DateTime? initialValue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return FormField<DateTime>(
      key: const Key('publish-time-field'),
      initialValue: initialValue,
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
