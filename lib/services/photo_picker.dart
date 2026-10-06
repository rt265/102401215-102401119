import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// 图片来源：相册 / 拍照。
enum PhotoPickSource {
  gallery('从相册选择'),
  camera('拍一张');

  const PhotoPickSource(this.label);

  final String label;
}

/// 选择图片的能力。
///
/// 抽成接口是为了让表单在测试里能塞一个假实现：真正的相册 / 相机弹窗
/// 在 widget 测试里既弹不出来，也不该弹。
abstract interface class PhotoPicker {
  /// 让用户选一批图片，返回**系统临时目录**里的绝对路径。
  ///
  /// 图片还没进应用的私有目录——那是 `PhotoStore` 的事。
  /// 用户放弃选择时抛 [PhotoPickCanceled]，其他失败抛 [PhotoPickFailure]。
  Future<List<String>> pick(PhotoPickSource source);
}

/// 用户放弃选择（或还没选就退出了）。
///
/// 与「选图失败」分开：取消不是错误，界面不该弹提示。
class PhotoPickCanceled implements Exception {
  const PhotoPickCanceled();

  @override
  String toString() => 'PhotoPickCanceled';
}

/// 选图失败：拿不到图片、或系统没给权限。
class PhotoPickFailure implements Exception {
  const PhotoPickFailure(this.message);

  /// 可以直接给用户看的说明。
  final String message;

  @override
  String toString() => 'PhotoPickFailure: $message';
}

/// 真正调系统相册 / 相机的实现。`image_picker` 只在这个文件里出现。
class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<String>> pick(PhotoPickSource source) async {
    try {
      if (source == PhotoPickSource.camera) {
        // 拍照一次一张：相机界面关掉后回到表单，想再拍再点一次即可。
        final XFile? shot = await _picker.pickImage(
          source: ImageSource.camera,
          // 原图动辄几 MB，落进私有目录只会白占空间；缩到够看清楚的尺寸。
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
        );
        if (shot == null) {
          throw const PhotoPickCanceled();
        }
        return <String>[shot.path];
      }

      final List<XFile> picked = await _picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (picked.isEmpty) {
        throw const PhotoPickCanceled();
      }
      return picked.map((XFile file) => file.path).toList(growable: false);
    } on PhotoPickCanceled {
      rethrow;
    } on PhotoPickFailure {
      rethrow;
    } catch (error) {
      // 相册权限被拒、模拟器没有相机、平台通道没实现……都归到这里。
      // 不把原始错误直接抛给界面：那串英文对用户没有意义。
      throw const PhotoPickFailure('打不开相册或相机，请检查系统权限后重试。');
    }
  }
}

/// 把 [PhotoPicker] 沿 widget 树下发。
///
/// 不套这层时 [maybeOf] 返回 `null`，调用方退回 [DevicePhotoPicker]：
/// 这样发布页与编辑页不必各自把 picker 传一路，测试里又能整个换掉。
class PhotoPickerScope extends InheritedWidget {
  const PhotoPickerScope({
    super.key,
    required this.picker,
    required super.child,
  });

  final PhotoPicker picker;

  static PhotoPicker? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoPickerScope>()?.picker;

  @override
  bool updateShouldNotify(PhotoPickerScope oldWidget) =>
      picker != oldWidget.picker;
}
