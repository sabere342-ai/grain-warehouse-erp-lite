import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/grain_warehouse_app.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';

void main() {
  testWidgets('starts at first owner setup when no owner exists',
      (tester) async {
    final controller = AuthController(repository: LocalAuthRepository.empty());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    expect(find.text('إعداد المالك الأول'), findsOneWidget);
    expect(find.text('إنشاء حساب المالك'), findsOneWidget);
  });

  testWidgets('first owner setup creates an owner session', (tester) async {
    final controller = AuthController(repository: LocalAuthRepository.empty());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'مالك المخزن');
    await tester.enterText(fields.at(1), '01000000000');
    await tester.enterText(fields.at(2), 'owner123');
    await tester.tap(find.text('إنشاء حساب المالك'));
    await tester.pumpAndSettle();

    expect(find.text('لوحة متابعة غلال'), findsOneWidget);
    expect(find.text('المالك'), findsOneWidget);
  });

  testWidgets('owner sees all functional owner navigation items',
      (tester) async {
    await _setDesktopSize(tester);
    final controller = await _signedInDemoController(
      phone: '01000000000',
      password: 'owner123',
    );

    await tester.pumpWidget(
      _testApp(controller, initializeAuth: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('العملاء'), findsWidgets);
    final sidebarScrollable = find.descendant(
      of: find.byKey(const Key('desktop-navigation-sidebar')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('الإعدادات'),
      300,
      scrollable: sidebarScrollable,
    );
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('التقارير'), findsOneWidget);
    expect(find.text('سجل التدقيق'), findsOneWidget);
    expect(find.text('المصروفات'), findsOneWidget);
  });

  testWidgets('employee cannot see owner-only navigation items',
      (tester) async {
    await _setDesktopSize(tester);
    final controller = await _signedInDemoController(
      phone: '01100000000',
      password: 'employee123',
    );

    await tester.pumpWidget(
      _testApp(controller, initializeAuth: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsNothing);
    expect(find.text('سجل التدقيق'), findsNothing);
    expect(find.text('التقارير'), findsNothing);
    expect(find.text('العملاء'), findsWidgets);
    expect(find.text('المصروفات'), findsWidgets);
    expect(find.text('الموظف'), findsOneWidget);
  });
}

GrainWarehouseApp _testApp(
  AuthController authController, {
  bool initializeAuth = true,
}) {
  final themeController = ThemeController(
    repository: LocalThemeSettingsRepository(),
  );
  final businessIdentityController = BusinessIdentityController(
    repository: LocalBusinessIdentityRepository(),
  );
  addTearDown(themeController.dispose);
  addTearDown(businessIdentityController.dispose);
  return GrainWarehouseApp(
    authController: authController,
    themeController: themeController,
    businessIdentityController: businessIdentityController,
    initializeAuth: initializeAuth,
  );
}

Future<AuthController> _signedInDemoController({
  required String phone,
  required String password,
}) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}

Future<void> _setDesktopSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
