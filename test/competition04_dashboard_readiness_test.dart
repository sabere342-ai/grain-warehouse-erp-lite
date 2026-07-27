import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_controller.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_export_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_alerts_section.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';
import 'package:grain_warehouse_erp_lite/features/help/help_guide_screen.dart';

void main() {
  group('COMPETITION-04 dashboard readiness', () {
    test('uses the canonical financial-account balance without mutation',
        () async {
      final financialAccounts = LocalFinancialAccountRepository();
      final account = await financialAccounts.createAccount(
        FinancialAccountDraft(
          name: 'الخزينة',
          type: FinancialAccountType.treasury,
          createdByUserId: _owner.id,
        ),
      );
      await financialAccounts.setOpeningBalance(
        accountId: account.id,
        amountQirsh: 10000,
        effectiveDate: DateTime(2026, 1, 1),
        createdByUserId: _owner.id,
      );
      await financialAccounts.createEntry(
        accountId: account.id,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: 5000,
        sourceType: FinancialAccountEntrySource.expense,
        sourceDocumentId: 'expense-1',
        effectiveDate: DateTime(2026, 1, 2),
        createdByUserId: _owner.id,
      );
      final before = await financialAccounts.allAccountBalances(
        includeInactive: true,
      );

      final data = await _service(financialAccounts).load();
      final after = await financialAccounts.allAccountBalances(
        includeInactive: true,
      );

      expect(data.cashBalanceQirsh, 5000);
      expect(
          after.single.currentBalanceQirsh, before.single.currentBalanceQirsh);
    });

    testWidgets('employee dashboard denies protected readers before loading',
        (tester) async {
      final auth = await _signedIn(UserRole.employee);
      var dashboardReads = 0;
      var guidanceReads = 0;
      var alertReads = 0;

      await tester.pumpWidget(
        _harness(
          auth: auth,
          controller: DashboardController(
            loadData: () async {
              dashboardReads++;
              return _data();
            },
          ),
          loadGuidance: () async {
            guidanceReads++;
            return DashboardGuidanceState.empty();
          },
          loadAlerts: () async {
            alertReads++;
            return OwnerAlertData.empty();
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(dashboardReads, 0);
      expect(guidanceReads, 0);
      expect(alertReads, 0);
      expect(
        find.text('ملخصات لوحة المتابعة المالية متاحة للمالك فقط.'),
        findsOneWidget,
      );
      expect(find.text('إجمالي أرصدة الحسابات المالية'), findsNothing);
      expect(find.text('تنبيهات المالك'), findsNothing);
    });

    testWidgets('owner renders signed canonical values without overflow',
        (tester) async {
      final auth = await _signedIn(UserRole.owner);
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          auth: auth,
          theme: AppTheme.fromPreset(AppThemePreset.highContrast),
          controller: DashboardController(loadData: () async => _data()),
          loadGuidance: () async => DashboardGuidanceState.empty(),
          loadAlerts: () async => OwnerAlertData.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إجمالي أرصدة الحسابات المالية'), findsOneWidget);
      expect(find.text(MoneyUtils.formatPiastersAsEgp(-2500)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dashboard shortcuts open real destinations and return',
        (tester) async {
      final auth = await _signedIn(UserRole.owner);
      await tester.binding.setSurfaceSize(const Size(1024, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          auth: auth,
          controller: DashboardController(loadData: () async => _data()),
          loadGuidance: () async => DashboardGuidanceState.empty(),
          loadAlerts: () async => OwnerAlertData.empty(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('تصدير نسخة احتياطية'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('تصدير نسخة احتياطية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تصدير نسخة احتياطية'));
      await tester.pumpAndSettle();
      expect(find.byType(BackupExportScreen), findsOneWidget);
      expect(find.byTooltip('رجوع'), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 2000),
        2000,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('دليل الاستخدام'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpGuideScreen), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dashboard prioritizes daily operations over admin tools',
        (tester) async {
      final auth = await _signedIn(UserRole.owner);
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          auth: auth,
          controller: DashboardController(loadData: () async => _data()),
          loadGuidance: () async => DashboardGuidanceState.empty(),
          loadAlerts: () async => OwnerAlertData.empty(),
        ),
      );
      await tester.pumpAndSettle();

      final dailySummary =
          find.byKey(const Key('dashboard-daily-summary-section-title'));
      final adminTitle =
          find.byKey(const Key('dashboard-administration-section-title'));
      final backupCard =
          find.byKey(const Key('dashboard-backup-administration-card'));

      expect(dailySummary, findsOneWidget);
      expect(adminTitle, findsOneWidget);
      expect(backupCard, findsOneWidget);
      expect(
        tester.getTopLeft(dailySummary).dy,
        lessThan(tester.getTopLeft(adminTitle).dy),
      );
      expect(
        tester.getTopLeft(adminTitle).dy,
        lessThan(tester.getTopLeft(backupCard).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

DashboardService _service(FinancialAccountRepository financialAccounts) {
  final products = LocalProductRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  final customers = LocalCustomerRepository();
  final suppliers = LocalSupplierRepository();
  return DashboardService(
    saleRepository: LocalSaleRepository(
      productRepository: products,
      inventoryRepository: inventory,
    ),
    inventoryRepository: inventory,
    productRepository: products,
    expenseRepository: LocalExpenseRepository(),
    customerAccountRepository:
        LocalCustomerAccountRepository(customerRepository: customers),
    financialAccountRepository: financialAccounts,
    supplierAccountRepository:
        LocalSupplierAccountRepository(supplierRepository: suppliers),
  );
}

DashboardData _data() => const DashboardData(
      todaySalesQirsh: 0,
      todayCashSalesQirsh: 0,
      todayCreditSalesQirsh: 0,
      todayCollectionsQirsh: 0,
      todaySupplierPaymentsQirsh: 0,
      todayExpensesQirsh: 0,
      cashBalanceQirsh: -2500,
      customerReceivablesQirsh: 0,
      supplierPayablesQirsh: 0,
      totalStockKg: 0,
      wheatStockKg: 0,
      stockAlertCount: 0,
      hasData: true,
    );

Widget _harness({
  required AuthController auth,
  required DashboardController controller,
  required Future<DashboardGuidanceState> Function() loadGuidance,
  required Future<OwnerAlertData> Function() loadAlerts,
  ThemeData? theme,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: DashboardScreen(
        controller: controller,
        loadGuidance: loadGuidance,
        loadAlerts: loadAlerts,
      ),
    ),
  );
}

Future<AuthController> _signedIn(UserRole role) async {
  final user = AppUser(
    id: '${role.name}-competition-04',
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

final _owner = AppUser(
  id: 'owner-competition-04',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
