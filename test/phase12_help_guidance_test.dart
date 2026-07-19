import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';
import 'package:grain_warehouse_erp_lite/features/help/help_guide_screen.dart';

void main() {
  group('Phase 12 help and first-run guidance', () {
    testWidgets('help entry point appears on dashboard', (tester) async {
      final auth = await _signedInOwner();
      await tester.pumpWidget(
        _harness(
          DashboardScreen(
            loadGuidance: () async => DashboardGuidanceState.empty(),
          ),
          auth: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('دليل الاستخدام'), findsOneWidget);
      expect(find.text('خطوات العمل اليومية'), findsOneWidget);
    });

    testWidgets('help screen contains key Arabic sections', (tester) async {
      await tester.pumpWidget(_harness(const HelpGuideScreen()));
      await tester.pumpAndSettle();

      expect(find.text('دليل الاستخدام'), findsOneWidget);
      expect(find.text('أول مرة تستخدم النظام'), findsOneWidget);
      expect(find.text('خطوات العمل اليومية'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('شرح مبسط للشاشات'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('شرح مبسط للشاشات'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('تنبيهات مهمة'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('تنبيهات مهمة'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('للمالك فقط'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('للمالك فقط'), findsOneWidget);
      expect(
        find.textContaining(
          'لا تستخدم حركة مخزون يدوية إلا عند الجرد أو التصحيح',
        ),
        findsOneWidget,
      );
      expect(
          find.textContaining('إلغاء المستند لا يحذف الأصل'), findsOneWidget);
      expect(find.textContaining('حركة عكسية'), findsOneWidget);
    });

    testWidgets('dashboard help button opens help screen', (tester) async {
      final auth = await _signedInOwner();
      await tester.pumpWidget(
        _harness(
          DashboardScreen(
            loadGuidance: () async => DashboardGuidanceState.empty(),
          ),
          auth: auth,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('دليل الاستخدام'));
      await tester.pumpAndSettle();

      expect(find.text('طريقة تشغيل مخزن الغلال'), findsOneWidget);
      expect(find.text('أول مرة تستخدم النظام'), findsOneWidget);
    });

    testWidgets('first-run guidance appears when there is no meaningful data',
        (tester) async {
      final auth = await _signedInOwner();
      await tester.pumpWidget(
        _harness(
          DashboardScreen(
            loadGuidance: () async => DashboardGuidanceState.empty(),
          ),
          auth: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ابدأ بإضافة أول صنف في المخزن.'), findsOneWidget);
    });

    testWidgets('guidance changes after products and stock exist',
        (tester) async {
      final auth = await _signedInOwner();
      await tester.pumpWidget(
        _harness(
          DashboardScreen(
            loadGuidance: () async => const DashboardGuidanceState(
              productCount: 1,
              stockMovementCount: 1,
              saleCount: 0,
            ),
          ),
          auth: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('بعد وجود رصيد، يمكنك تسجيل المبيعات عند خروج الحبوب.'),
        findsOneWidget,
      );
    });
  });
}

Widget _harness(Widget child, {AuthController? auth}) {
  final app = MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: child,
  );
  return auth == null ? app : AuthScope(controller: auth, child: app);
}

Future<AuthController> _signedInOwner() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}
