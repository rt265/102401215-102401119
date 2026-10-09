import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/data/user_store.dart';
import 'package:lost_and_found/models/user_account.dart';
import 'package:lost_and_found/pages/account_page.dart';
import 'package:lost_and_found/utils/time_format.dart';

import 'helpers/page_harness.dart';

const String _name = '张同学';
const String _contact = '微信 umbrella_zhang';
final DateTime _since = DateTime(2026, 5, 1, 12);

UserStore signUpStore() => UserStore(
  initialAccount: UserAccount(
    displayName: _name,
    contact: _contact,
    createdAt: _since,
  ),
);

/// 只装账户界面（UI 事项 12 从设置页拆出来的子界面）。
Widget buildAccountPage({UserStore? users}) {
  return buildSettingsHost(users: users, home: const AccountPage());
}

void main() {
  testWidgets('未登记时给出登记入口', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildAccountPage());

    expect(find.text('账户'), findsOneWidget);
    expect(find.byKey(const Key('account-back-button')), findsOneWidget);
    expect(find.byKey(const Key('account-card')), findsOneWidget);
    expect(find.text('还没有登记账户。'), findsOneWidget);
    expect(find.byKey(const Key('account-register')), findsOneWidget);
    // 未登记时没有资料可改、也没得退出。
    expect(find.byKey(const Key('account-edit')), findsNothing);
    expect(find.byKey(const Key('account-sign-out')), findsNothing);
  });

  testWidgets('登记账户：两项都必填，存完收起表单', (WidgetTester tester) async {
    useTallScreen(tester);
    final UserStore users = UserStore();
    await tester.pumpWidget(buildAccountPage(users: users));

    await tapAt(tester, find.byKey(const Key('account-register')));
    expect(find.byKey(const Key('account-name-field')), findsOneWidget);

    // 两项都是必填，先空提交一次。
    await tapAt(tester, find.byKey(const Key('account-submit')));
    expect(find.text('请填写称呼'), findsOneWidget);
    expect(find.text('请填写联系方式'), findsOneWidget);

    await typeInto(tester, const Key('account-name-field'), _name);
    await typeInto(tester, const Key('account-contact-field'), _contact);
    await tapAt(tester, find.byKey(const Key('account-submit')));

    expect(users.account?.displayName, _name);
    expect(users.account?.contact, _contact);
    // 存完收起表单，卡片上直接变成账户信息。
    expect(find.byKey(const Key('account-name-field')), findsNothing);
    expect(textAt(tester, const Key('account-name')), _name);
    expect(textAt(tester, const Key('account-contact')), _contact);
    expect(find.text('账户资料已保存'), findsOneWidget);
  });

  testWidgets('表单取消后回到未登记的展示态', (WidgetTester tester) async {
    useTallScreen(tester);
    final UserStore users = UserStore();
    await tester.pumpWidget(buildAccountPage(users: users));

    await tapAt(tester, find.byKey(const Key('account-register')));
    await tapAt(tester, find.byKey(const Key('account-cancel')));

    expect(find.byKey(const Key('account-name-field')), findsNothing);
    expect(find.byKey(const Key('account-register')), findsOneWidget);
    expect(users.account, isNull);
  });

  testWidgets('已登记时展示资料与登记时间', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildAccountPage(users: signUpStore()));

    expect(textAt(tester, const Key('account-name')), _name);
    expect(textAt(tester, const Key('account-contact')), _contact);
    expect(textAt(tester, const Key('account-since')), formatDate(_since));
    expect(find.byKey(const Key('account-edit')), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
  });

  testWidgets('修改资料会回填原值，且首次登记时间不变', (WidgetTester tester) async {
    useTallScreen(tester);
    final UserStore users = signUpStore();
    await tester.pumpWidget(buildAccountPage(users: users));

    await tapAt(tester, find.byKey(const Key('account-edit')));
    expect(find.text('修改资料'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('account-name-field')))
          .controller
          ?.text,
      _name,
    );

    await typeInto(tester, const Key('account-name-field'), '李同学');
    await tapAt(tester, find.byKey(const Key('account-submit')));

    expect(users.account?.displayName, '李同学');
    expect(users.account?.contact, _contact);
    // 首次登记时间保留：改资料不是重新登记。
    expect(users.account?.createdAt, _since);
    expect(textAt(tester, const Key('account-name')), '李同学');
    expect(textAt(tester, const Key('account-since')), formatDate(_since));
  });

  testWidgets('退出登录要先确认，确认后回到未登记状态', (WidgetTester tester) async {
    useTallScreen(tester);
    final UserStore users = signUpStore();
    await tester.pumpWidget(buildAccountPage(users: users));

    await tapAt(tester, find.byKey(const Key('account-sign-out')));
    expect(find.byKey(const Key('account-sign-out-dialog')), findsOneWidget);

    // 先取消：账户还在。
    await tapAt(tester, find.byKey(const Key('account-dialog-cancel')));
    expect(users.account, isNotNull);
    expect(find.byKey(const Key('account-sign-out-dialog')), findsNothing);

    await tapAt(tester, find.byKey(const Key('account-sign-out')));
    await tapAt(tester, find.byKey(const Key('account-dialog-confirm')));

    expect(users.account, isNull);
    expect(find.byKey(const Key('account-register')), findsOneWidget);
    expect(find.text('已退出登录'), findsOneWidget);
  });

  testWidgets('返回键能关掉账户界面', (WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(buildPushHost(() => const AccountPage()));

    await tapAt(tester, find.byKey(const Key('open-page')));
    expect(find.byType(AccountPage), findsOneWidget);

    await tapAt(tester, find.byKey(const Key('account-back-button')));
    expect(find.byType(AccountPage), findsNothing);
  });
}
