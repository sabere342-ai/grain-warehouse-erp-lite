import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/advances_and_refunds_report_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_reports/financial_reports_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';

void main() {
  group('AdvancesAndRefundsReportScreen', () {
    testWidgets('opens from Financial Reports and returns without mutation',
        (tester) async {
      final auth = await _signedInController(UserRole.owner);
      final balancesBefore =
          await AppRepositories.financialAccountRepository.allAccountBalances();
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_financialReportsHarness(auth));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(900);
      await tester.pumpAndSettle();
      final reportEntry = find.text('تقرير رد السلف وعكسها');
      await tester.tap(reportEntry);
      await tester.pumpAndSettle();

      expect(find.byType(AdvancesAndRefundsReportScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('تقرير رد السلف وعكسها'), findsOneWidget);
      expect(
        find.text('لا توجد عمليات رد سلف أو عكسها في الفترة المحددة.'),
        findsOneWidget,
      );
      final backButton = find.byTooltip('رجوع');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(AdvancesAndRefundsReportScreen), findsNothing);
      expect(find.byType(FinancialReportsScreen), findsOneWidget);
      expect(
          await AppRepositories.financialAccountRepository.allAccountBalances(),
          balancesBefore);
    });

    testWidgets('denies an employee before rendering protected report data',
        (tester) async {
      final auth = await _signedInController(UserRole.employee);

      await tester.pumpWidget(_reportHarness(auth));
      await tester.pump();

      expect(
        find.text('ليس لديك صلاحية عرض التقارير المالية.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('لا توجد عمليات رد سلف أو عكسها في الفترة المحددة.'),
          findsNothing);
    });

    testWidgets('builds the truthful empty state in RTL dark narrow layout',
        (tester) async {
      final auth = await _signedInController(UserRole.owner);
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _reportHarness(
          auth,
          theme: AppTheme.fromPreset(AppThemePreset.highContrast),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsWidgets);

      final scrollState = tester.state<ScrollableState>(scrollableFinder.first);
      expect(scrollState.position.maxScrollExtent, greaterThan(0.0),
          reason: 'content must overflow the narrow viewport');

      scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('لا توجد عمليات رد سلف أو عكسها في الفترة المحددة.'),
        findsOneWidget,
      );
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

Future<AuthController> _signedInController(UserRole role) async {
  final user = AppUser(
    id: '${role.name}-test',
    name: 'مستخدم اختبار',
    phone: role == UserRole.owner ? '01000000000' : '01000000001',
    role: role,
    isActive: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final repository = LocalAuthRepository(
    seedAccounts: [LocalAuthAccount(user: user, password: 'password123')],
  );
  final controller = AuthController(repository: repository);
  await controller.initialize();
  await controller.signIn(phone: user.phone, password: 'password123');
  return controller;
}

Widget _financialReportsHarness(AuthController auth) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const FinancialReportsScreen(),
    ),
  );
}

Widget _reportHarness(AuthController auth, {ThemeData? theme}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AdvancesAndRefundsReportScreen(),
    ),
  );
}
