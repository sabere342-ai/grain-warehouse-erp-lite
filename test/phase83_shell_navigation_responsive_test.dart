import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 83 adaptive application shell', () {
    testWidgets('phone exposes every permitted destination through More drawer',
        (tester) async {
      await _setViewport(tester, const Size(360, 800));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);

      await tester.pumpWidget(_harness(auth));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
      expect(find.text('المزيد'), findsOneWidget);
      expect(find.byKey(const Key('desktop-navigation-sidebar')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile-navigation-drawer')), findsOneWidget);
      expect(find.text('طلبات الموافقة'), findsOneWidget);
      final drawerScrollable = find
          .descendant(
            of: find.byKey(const Key('mobile-navigation-drawer')),
            matching: find.byType(Scrollable),
          )
          .last;
      await tester.scrollUntilVisible(
        find.text('الإعدادات'),
        300,
        scrollable: drawerScrollable,
      );
      expect(find.text('الإعدادات'), findsOneWidget);

      await tester.tapAt(const Offset(8, 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المزيد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الموردون'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('suppliers-search-field')), findsOneWidget);
      expect(find.byKey(const Key('shell-back-button')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('shell-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('لوحة متابعة غلال'), findsOneWidget);
      expect(find.byKey(const Key('shell-back-button')), findsNothing);
    });

    testWidgets(
        'Windows width uses scrollable sidebar and no bottom navigation',
        (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);

      await tester.pumpWidget(_harness(auth));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('desktop-navigation-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
      expect(find.text('الرئيسية'), findsWidgets);
      expect(find.text('الموردون'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Alt+Left follows shell back contract without duplicating dashboard',
        (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);

      await tester.pumpWidget(_harness(auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الموردون'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shell-back-button')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(find.text('لوحة متابعة غلال'), findsOneWidget);
      expect(find.byKey(const Key('shell-back-button')), findsNothing);
      expect(find.byType(DashboardShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resizing between compact and desktop keeps the active surface',
        (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);
      await tester.pumpWidget(_harness(auth));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);

      tester.view.physicalSize = const Size(1100, 720);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('desktop-navigation-sidebar')), findsOneWidget);
      expect(find.text('لوحة متابعة غلال'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet portrait keeps compact navigation without overflow',
        (tester) async {
      await _setViewport(tester, const Size(800, 1024));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);

      await tester.pumpWidget(_harness(auth));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
      expect(find.byKey(const Key('desktop-navigation-sidebar')), findsNothing);
      expect(find.text('لوحة متابعة غلال'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide Windows viewport preserves the centered content shell',
        (tester) async {
      await _setViewport(tester, const Size(1600, 900));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);

      await tester.pumpWidget(_harness(auth));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('desktop-navigation-sidebar')), findsOneWidget);
      expect(find.byKey(const Key('mobile-bottom-navigation')), findsNothing);
      expect(find.text('لوحة متابعة غلال'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<AuthController> _signedInOwner() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}

Widget _harness(AuthController auth) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const DashboardShell(),
    ),
  );
}
