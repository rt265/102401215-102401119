import 'dart:io' show IOException;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../data/photo_store.dart';
import '../data/user_store.dart';
import '../models/item_post.dart';
import '../services/photo_picker.dart';
import '../utils/time_format.dart';
import 'max_width_body.dart';
import 'post_photo.dart';

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
    this.onChanged,
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

  /// 表单内容有任何改动（含 [PostFormState.reset]）时回调。
  ///
  /// 供宿主刷新「有没有未保存的改动」这类界面状态；表单本身不依赖它。
  final VoidCallback? onChanged;

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

  /// 表单**刚打开时**的校验时机。
  ///
  /// 新建时先不提醒，点了提交再开始；编辑时一进来就是
  /// [AutovalidateMode.onUserInteraction]——清空某个必填项立刻能看到提醒。
  AutovalidateMode get _initialAutovalidateMode => widget.initial == null
      ? AutovalidateMode.disabled
      : AutovalidateMode.onUserInteraction;

  /// 第一次提交失败后改为 [AutovalidateMode.onUserInteraction]：
  /// 提醒过一次之后，边填边校验，不必反复点提交。
  late AutovalidateMode _autovalidateMode = _initialAutovalidateMode;

  // 下面几个控制器既给「清空」用，也给 save() 读当前输入用。
  // TextFormField 传了 controller 时 initialValue 必须为 null，
  // 而 FormState.reset() 是把文本复位成 widget.initialValue ?? ''，
  // 所以带 controller 的字段在 reset 后就是空串——「清空」正靠这一点。
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _locationController = TextEditingController(
    text: widget.initial?.location ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final TextEditingController _contactController = TextEditingController(
    text: _initialContact,
  );

  // 已选的值不在 controller 的管辖范围内，另外用这几个字段记录当前选择：
  // 用户每改一次由选择器的 onChanged 回写，save() 直接读它们。
  //
  // 注意：选择器的 FormField.initialValue 绑的是 widget.initial?.xxx（不可变的原始初值），
  // **不是**下面这几个字段。FormFieldState.reset() 的实现是 `_value = widget.initialValue`，
  // 若把会被用户改动的 _type / _category / _eventTime 传进去，reset 会把上一次的选择
  // 原样「复位」回来，等于清不掉。
  late PostType? _type = widget.initial?.type;

  late ItemCategory? _category = widget.initial?.category;

  late DateTime? _eventTime = widget.initial?.eventTime;

  /// 表单当前带的图片（文件名，见 `PhotoStore`），顺序就是用户看到的顺序。
  ///
  /// 新建时是空列表，编辑时是这条信息原有的图片——`ItemPost.imagePaths`
  /// 里可能混着迁移前的绝对路径，所以统一过一道 [imageFilenamesOf]。
  late List<String> _imagePaths = widget.initial == null
      ? <String>[]
      : imageFilenamesOf(widget.initial!);

  /// 本次编辑新存进来的图片草稿。
  ///
  /// 懒建：只有真的选了图才开会话，没选图的表单（绝大多数）不会白白建一个。
  /// 用户清空 / 还原表单或直接退出编辑页时，这个会话里的图片会被删掉，
  /// 不会在图片目录里留下没人引用的文件。
  FormImageSession? _photoSession;

  /// 一次最多带几张图片。
  static const int maxPhotoCount = 9;

  /// 表单**刚打开时**的图片，[reset] 要还原到它。
  ///
  /// 必须在 State 构造时就定下来（不能写成 `late final ... = List.of(_imagePaths)`）：
  /// `late` 是**第一次读到才求值**，而第一次读它的地方正是 [reset]——那时
  /// `_imagePaths` 已经被用户选过图了，还原就成了「还原到用户刚选的那张」。
  late final List<String> _initialImagePaths = widget.initial == null
      ? <String>[]
      : imageFilenamesOf(widget.initial!);

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
    // 编辑页被直接关掉（没点保存）时，本次选进来的图片还没人引用，删掉。
    _photoSession?.discard();
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

  /// 表单内容是否已经和刚打开时不一样。
  ///
  /// 比较的就是 [save] 会写进信息里的那几个字段，比较前先 `trim()`——
  /// 多打一个空格不算改动，不该因此弹出「放弃修改？」。
  /// 新建表单（[PostForm.initial] 为 `null`）时，什么都没填就是 `false`。
  bool get isDirty {
    final ItemPost? initial = widget.initial;

    final String contact = _contactController.text.trim();
    final String initialContact = initial?.contact ?? '';
    // 账户自动带进来的联系方式用户并没有动过，不算改动。
    final bool contactChanged =
        contact != initialContact &&
        !(initialContact.isEmpty && contact == (_autoFilledContact ?? ''));

    return _type != initial?.type ||
        _category != initial?.category ||
        _eventTime != initial?.eventTime ||
        !listEquals(
          _imagePaths,
          initial == null ? const <String>[] : imageFilenamesOf(initial),
        ) ||
        _titleController.text.trim() != (initial?.title ?? '') ||
        _locationController.text.trim() != (initial?.location ?? '') ||
        _descriptionController.text.trim() != (initial?.description ?? '') ||
        contactChanged;
  }

  /// 内容被改动后通知宿主（宿主据此刷新「有没有未保存的改动」）。
  void _notifyChanged() => widget.onChanged?.call();

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
            // 主键由客户端生成，不走数据库自增：`posts.id` 是 TEXT 主键
            // （见 db_schema.dart 的建表语句），SQLite 不会给 TEXT 主键填值；
            // 而且落库前内存快照就先更新了，id 必须在这儿定下来。
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
            imagePaths: List<String>.unmodifiable(_imagePaths),
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
            imagePaths: List<String>.unmodifiable(_imagePaths),
          );

    // 图片交出去了（信息持有它们），本次编辑会话到此结束。
    _photoSession?.commit();
    _photoSession = null;
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

  /// 清空 / 还原表单：连同已出现的提醒一起复位。
  ///
  /// 新建时是「清空」（发布界面的按钮），编辑时是「还原为打开时的内容」
  /// （编辑界面的按钮）——同一套复位，只是初值不同。
  ///
  /// 账户里登记过的联系方式会重新填上——同一个人接着发下一条时，
  /// 不必再手打一遍。
  void reset() {
    // 各个 FormField 复位到自己的 initialValue（= `widget.initial?.xxx`）：
    // 新建时那是 null，等于清空；编辑时是刚打开时的值，等于还原。
    _formKey.currentState?.reset();
    setState(() {
      // 这几个字段是 save() 组装信息时的数据来源，必须跟着一起回到初值，
      // 否则清空后它们还留着用户上一次的选择，下一条会被静默沿用。
      _type = widget.initial?.type;
      _category = widget.initial?.category;
      _eventTime = widget.initial?.eventTime;
      _imagePaths = List<String>.of(_initialImagePaths);
      // 复位后回到「刚打开表单」时的校验时机，而不是一律关掉提醒：
      // 新建时仍是先不提醒，编辑时仍是边填边校验。
      _autovalidateMode = _initialAutovalidateMode;
    });
    // 本次选进来的图片随复位一起丢掉：清空 / 还原之后它们不该再占着图片目录。
    _photoSession?.discard();
    _photoSession = null;
    _autoFilledContact = null;
    _syncAccountContact();
    // 复位也是一次内容变化：宿主要据此把「有未保存的改动」收回 false。
    _notifyChanged();
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

    final DateTime value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    field.didChange(value);
    _eventTime = value;
    _notifyChanged();
  }

  /// 选图入口：先问从哪来（相册 / 拍照），再把图片收进私有目录。
  Future<void> _pickPhotos() async {
    final PhotoStore? photos = PhotoScope.maybeOf(context);
    if (photos == null) {
      // 没有图片仓库就没法落盘（纯内存预览会走到这里），如实说明而不是弹个空相册。
      _showMessage('当前环境不支持选择图片。');
      return;
    }

    final PhotoPickSource? source = await _askPhotoSource();
    if (source == null || !mounted) {
      return;
    }

    final PhotoPicker picker =
        PhotoPickerScope.maybeOf(context) ?? DevicePhotoPicker();
    final FormImageSession session = _photoSession ??= photos.beginSession();

    final List<String> picked;
    try {
      picked = await picker.pick(source);
    } on PhotoPickCanceled {
      // 用户自己退出的，不用提示。
      return;
    } on PhotoPickFailure catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
      return;
    }
    if (!mounted) {
      return;
    }

    final int remaining = maxPhotoCount - _imagePaths.length;
    if (remaining <= 0) {
      _showMessage('最多只能带 $maxPhotoCount 张图片。');
      return;
    }
    // 相册是多选，用户可能一口气选超：多出来的直接丢掉，并把结果说清楚。
    final List<String> accepted = picked
        .take(remaining)
        .toList(growable: false);

    final List<String> added = <String>[];
    for (final String sourcePath in accepted) {
      try {
        added.add(await session.savePicked(sourcePath));
      } on IOException {
        // 某一张读不到（系统临时文件被回收等）不该让整次选择白费，跳过它。
        continue;
      }
    }
    if (!mounted) {
      return;
    }

    if (added.isEmpty) {
      _showMessage('图片没能保存下来，请重试。');
      return;
    }
    setState(() => _imagePaths = <String>[..._imagePaths, ...added]);
    _notifyChanged();

    final int dropped = picked.length - accepted.length;
    if (dropped > 0) {
      _showMessage('最多只能带 $maxPhotoCount 张图片，已忽略多选的 $dropped 张。');
    }
  }

  /// 删除表单里的一张图片。
  ///
  /// 图片还在会话里（本次选的、还没保存）时顺手从磁盘删掉；已经在信息上的图片
  /// 只从列表里摘掉——真正落盘的那份等保存时随信息一起更新，或者随信息一起删。
  void _removePhoto(int index) {
    final String name = _imagePaths[index];
    final FormImageSession? session = _photoSession;
    final bool isDraft = session?.filenames.contains(name) ?? false;

    setState(() {
      _imagePaths = <String>[..._imagePaths]..removeAt(index);
    });
    _notifyChanged();

    if (isDraft) {
      // 草稿图摘下来就没人要了；会话下次 discard 也会兜住，这里直接删更干净。
      PhotoScope.maybeOf(context)?.deleteFiles(<String>[name]);
    }
  }

  Future<PhotoPickSource?> _askPhotoSource() {
    return showModalBottomSheet<PhotoPickSource>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              ListTile(
                key: const Key('publish-photo-source-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(PhotoPickSource.gallery.label),
                onTap: () =>
                    Navigator.of(sheetContext).pop(PhotoPickSource.gallery),
              ),
              ListTile(
                key: const Key('publish-photo-source-camera'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(PhotoPickSource.camera.label),
                onTap: () =>
                    Navigator.of(sheetContext).pop(PhotoPickSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: MaxWidthBody(
        child: SingleChildScrollView(
          key: const Key('publish-form'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              const _FieldLabel('信息类型', isRequired: true),
              _TypeSelector(
                initialValue: widget.initial?.type,
                onChanged: (PostType? value) {
                  _type = value;
                  _notifyChanged();
                },
              ),
              const SizedBox(height: 18),

              const _FieldLabel('物品名称', isRequired: true),
              TextFormField(
                key: const Key('publish-title-field'),
                controller: _titleController,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _notifyChanged(),
                decoration: _decoration('例如：校园一卡通（蓝色卡套）'),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? '请填写物品名称' : null,
              ),
              const SizedBox(height: 18),

              const _FieldLabel('物品分类', isRequired: true),
              _CategorySelector(
                initialValue: widget.initial?.category,
                onChanged: (ItemCategory? value) {
                  _category = value;
                  _notifyChanged();
                },
              ),
              const SizedBox(height: 18),

              const _FieldLabel('地点', isRequired: true),
              TextFormField(
                key: const Key('publish-location-field'),
                controller: _locationController,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _notifyChanged(),
                decoration: _decoration('例如：图书馆一楼大厅'),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? '请填写地点' : null,
              ),
              const SizedBox(height: 18),

              const _FieldLabel('时间', isRequired: true),
              _EventTimeField(
                initialValue: widget.initial?.eventTime,
                onTap: _pickEventTime,
              ),
              const SizedBox(height: 18),

              const _FieldLabel('描述'),
              TextFormField(
                key: const Key('publish-description-field'),
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 200,
                onChanged: (_) => _notifyChanged(),
                decoration: _decoration('颜色、特征、存放位置等，写清楚更容易对上。注意保护个人隐私'),
              ),
              const SizedBox(height: 10),

              const _FieldLabel('联系方式', isRequired: true),
              TextFormField(
                key: const Key('publish-contact-field'),
                controller: _contactController,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _notifyChanged(),
                decoration: _decoration(
                  '例如：手机 138****6621',
                  helper: '留下手机号 / 微信 / QQ，方便对方联系你',
                ),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? '请填写联系方式' : null,
              ),
              const SizedBox(height: 18),

              _FieldLabel('图片（最多 $maxPhotoCount 张）'),
              _PhotoField(
                paths: _imagePaths,
                maxCount: maxPhotoCount,
                onAdd: _pickPhotos,
                onRemove: _removePhoto,
              ),
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
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            isRequired ? ' *' : '',
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
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
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
              selected: <PostType>{if (field.value != null) field.value!},
              onSelectionChanged: (Set<PostType> selection) {
                final PostType? value = selection.isEmpty
                    ? null
                    : selection.first;
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: field.hasError
                          ? scheme.error
                          : scheme.outlineVariant,
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
                        value == null ? '选择丢失 / 拾取的时间' : formatDateTime(value),
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

/// 图片（选填）：已选的缩略图 + 一个「加号」入口。
///
/// 缩略图上可以单张删除；张数上限由调用方（表单的 `maxPhotoCount`）管，
/// 到了上限就把入口收起来，而不是让用户点了再被拒。
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.paths,
    required this.maxCount,
    required this.onAdd,
    required this.onRemove,
  });

  /// 当前图片（文件名），顺序即显示顺序。
  final List<String> paths;

  final int maxCount;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool canAdd = paths.length < maxCount;

    if (paths.isEmpty && !canAdd) {
      // 理论上进不来（上限至少是 1），留个不崩的兜底。
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            // 手机（360–411dp）约 3 列，内容列拉宽到上限 700px 时自动长到约 5 列。
            maxCrossAxisExtent: 140,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            // 上面一行缩略图就是正方形，格子跟着图片走。
            childAspectRatio: 1,
          ),
          itemCount: paths.length + (canAdd ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index == paths.length) {
              return _AddTile(
                key: const Key('publish-photo-add'),
                onTap: onAdd,
              );
            }
            final String name = paths[index];
            final String filePath = resolvePhotoPath(context, name);
            return Stack(
              key: Key('publish-photo-$index'),
              fit: StackFit.expand,
              children: <Widget>[
                PostPhotoView(filePath: filePath),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Material(
                    color: scheme.scrim.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: Key('publish-photo-remove-$index'),
                      customBorder: const CircleBorder(),
                      onTap: () => onRemove(index),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          paths.isEmpty
              ? '带上物品的照片，更容易被认出来。'
              : '已选 ${paths.length} / $maxCount 张，点右上角的 × 可以删掉。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 图片网格里的「加一张」格子。
class _AddTile extends StatelessWidget {
  const _AddTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Center(
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
