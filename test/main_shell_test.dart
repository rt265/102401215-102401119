import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lost_and_found/main.dart';
import 'package:lost_and_found/theme/app_layout.dart';

import 'helpers/shell_nav.dart';

/// 把测试视口调成 [size] 逻辑像素（默认是 800×600）。
void useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 外壳当前摆在第几个标签（三个界面都挂在 `IndexedStack` 上，凭这个认选中项）。
int? shownTab(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

void main() {
  group('主界面外壳按可用宽度切换导航摆法', () {
    testWidgets('手机竖屏宽度（400）用底部导航栏', (WidgetTester tester) async {
      useScreen(tester, const Size(400, 800));
      await tester.pumpWidget(const LostAndFoundApp());

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(mainTab('首页'), findsOneWidget);
    });

    testWidgets('宽屏（1000）换成侧边导航栏', (WidgetTester tester) async {
      useScreen(tester, const Size(1000, 800));
      await tester.pumpWidget(const LostAndFoundApp());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(mainTab('首页'), findsOneWidget);
    });

    testWidgets('断点落在 599 与 600 之间', (WidgetTester tester) async {
      expect(AppLayout.navigationRailBreakpoint, 600);

      useScreen(tester, const Size(599, 800));
      await tester.pumpWidget(const LostAndFoundApp());
      expect(find.byType(NavigationBar), findsOneWidget);

      // 同一棵树上把宽度推过断点：只换摆法，不重新挂载。
      tester.view.physicalSize = const Size(600, 800);
      await tester.pump();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('侧边导航栏能切换三个界面', (WidgetTester tester) async {
      useScreen(tester, const Size(1000, 800));
      await tester.pumpWidget(const LostAndFoundApp());

      expect(shownTab(tester), 0);

      await tester.tap(mainTab('发布'));
      await tester.pumpAndSettle();
      expect(shownTab(tester), 1);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1,
      );
      // 发布表单确实建出来了（三个界面都在 IndexedStack 上，所以按 Key 认）。
      expect(find.byKey(const Key('publish-submit-button')), findsOneWidget);

      await tester.tap(mainTab('我的'));
      await tester.pumpAndSettle();
      expect(shownTab(tester), 2);

      await tester.tap(mainTab('首页'));
      await tester.pumpAndSettle();
      expect(shownTab(tester), 0);
    });

    testWidgets('宽度变化后选中项与界面状态都不丢', (WidgetTester tester) async {
      useScreen(tester, const Size(1000, 800));
      await tester.pumpWidget(const LostAndFoundApp());

      await tester.tap(mainTab('我的'));
      await tester.pumpAndSettle();
      expect(shownTab(tester), 2);

      // 从宽屏缩回手机宽度：外壳重建，选中项与三个界面的状态都该原样留着。
      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(shownTab(tester), 2);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .selectedIndex,
        2,
      );
    });
  });
}
