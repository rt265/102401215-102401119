/// 账户表单（`lib/widgets/account_form.dart`）的文案。
///
/// 这个表单被「我的」界面与设置里的账户界面共用，两边的测试都会断言它的
/// 校验提示，所以单独一份，不并进任何一边。
abstract final class AccountFormStrings {
  /// 提交按钮的默认文案（调用方可以另外传一个，见 `AccountForm.submitLabel`）。
  static const String defaultSubmitLabel = '保存';

  static const String nameLabel = '称呼';
  static const String nameHint = '例如：张同学';
  static const String nameRequired = '请填写称呼';

  static const String contactLabel = '常用联系方式';
  static const String contactHint = '例如：手机 138****6621';
  static const String contactHelper = '发布信息时自动带出，之后可以修改';
  static const String contactRequired = '请填写联系方式';
}
