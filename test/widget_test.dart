import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/grain_warehouse_app.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';

void main() {
  testWidgets('starts at first owner setup when no owner exists',
      (tester) async {
    await tester.pumpWidget(const GrainWarehouseApp());
    await tester.pumpAndSettle();

    expect(find.text('إعداد المالك الأول'), findsOneWidget);
    expect(find.text('إنشاء حساب المالك'), findsOneWidget);
  });

  testWidgets('first owner setup creates an owner session', (tester) async {
    await tester.pumpWidget(const GrainWarehouseApp());
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'مالك المخزن');
    await tester.enterText(fields.at(1), '01000000000');
    await tester.enterText(fields.at(2), 'owner123');
    await tester.tap(find.text('إنشاء حساب المالك'));
    await tester.pumpAndSettle();

    expect(find.text('لوحة متابعة المخزن'), findsOneWidget);
    expect(find.text('المالك'), findsOneWidget);
  });

  testWidgets('owner sees only pilot-ready owner navigation items', (tester) async {
    await _setDesktopSize(tester);
    final controller = await _signedInDemoController(
      phone: '01000000000',
      password: 'owner123',
    );

    await tester.pumpWidget(
      GrainWarehouseApp(
        authController: controller,
        initializeAuth: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsWidgets);
    expect(find.text('التقارير'), findsWidgets);
    expect(find.text('سجل التدقيق'), findsNothing);
    expect(find.text('العملاء'), findsNothing);
    expect(find.text('المصروفات'), findsNothing);
  });

  testWidgets('employee cannot see owner-only navigation items',
      (tester) async {
    await _setDesktopSize(tester);
    final controller = await _signedInDemoController(
      phone: '01100000000',
      password: 'employee123',
    );

    await tester.pumpWidget(
      GrainWarehouseApp(
        authController: controller,
        initializeAuth: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsNothing);
    expect(find.text('سجل التدقيق'), findsNothing);
    expect(find.text('التقارير'), findsNothing);
    expect(find.text('الموظف'), findsOneWidget);
  });
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
