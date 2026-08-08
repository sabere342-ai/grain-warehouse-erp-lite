import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_workflow_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/negative_balance_approval_requests_screen.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  testWidgets(
      'owner sees approval actions, details, and no small-screen overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _WidgetFixture.create();
    final auth = await fixture.signedInOwner();
    await tester.pumpWidget(fixture.harness(auth));
    await tester.pumpAndSettle();

    expect(find.text('طلبات الموافقة'), findsOneWidget);
    expect(find.text('مصروف'), findsOneWidget);
    expect(find.textContaining('مقدم الطلب:'), findsOneWidget);
    expect(find.textContaining('الرصيد:'), findsOneWidget);
    expect(find.textContaining('العجز:'), findsOneWidget);
    expect(find.text('اعتماد وتنفيذ فورًا'), findsOneWidget);
    expect(find.text('رفض'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('مصروف'));
    await tester.pumpAndSettle();
    expect(find.textContaining('العملية لم تُنفذ بعد'), findsOneWidget);
    expect(find.text('رجوع'), findsOneWidget);
    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
  });

  testWidgets('ordinary requester cannot approve and can cancel',
      (tester) async {
    final fixture = await _WidgetFixture.create();
    final auth = await fixture.signedInEmployee();
    await tester.pumpWidget(fixture.harness(auth));
    await tester.pumpAndSettle();

    expect(find.text('اعتماد وتنفيذ فورًا'), findsNothing);
    expect(find.text('رفض'), findsNothing);
    expect(find.text('إلغاء الطلب'), findsOneWidget);
    await tester.tap(find.text('إلغاء الطلب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'إلغاء من مقدم الطلب');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect((await fixture.requests.findById(fixture.request.id))!.status,
        NegativeBalanceApprovalRequestStatus.cancelled);
    expect(await fixture.expenses.listExpenses(), isEmpty);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id),
        100);
  });

  testWidgets('back button pops the approval queue route', (tester) async {
    final fixture = await _WidgetFixture.create();
    final auth = await fixture.signedInOwner();
    await tester.pumpWidget(fixture.harness(auth, startWithLauncher: true));
    await tester.tap(find.text('فتح الطلبات'));
    await tester.pumpAndSettle();
    expect(find.text('طلبات الموافقة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('approval-requests-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('فتح الطلبات'), findsOneWidget);
  });
}

class _WidgetFixture {
  _WidgetFixture({
    required this.authRepository,
    required this.audit,
    required this.accounts,
    required this.account,
    required this.requests,
    required this.expenses,
    required this.workflow,
    required this.request,
  });

  static Future<_WidgetFixture> create() async {
    final authRepository = LocalAuthRepository.demo();
    final audit = LocalAuditLogRepository();
    final legacyRepository = LocalNegativeBalanceApprovalRepository();
    final legacyService = NegativeBalanceApprovalService(
      authRepository: authRepository,
      approvalRepository: legacyRepository,
      auditLogRepository: audit,
    );
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: audit,
      negativeBalanceApprovalService: legacyService,
    );
    final account = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'خزينة الموافقات',
        type: FinancialAccountType.treasury,
        allowNegativeBalance: true,
        createdByUserId: 'owner-demo',
      ),
    );
    await accounts.setOpeningBalance(
      accountId: account.id,
      amountQirsh: 100,
      effectiveDate: DateTime(2026, 7, 1),
      createdByUserId: 'owner-demo',
    );
    final suppliers = LocalSupplierRepository();
    final products = LocalProductRepository();
    final inventory = LocalInventoryRepository(productRepository: products);
    final supplierAccounts = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
      negativeBalanceApprovalService: legacyService,
    );
    final expenses = LocalExpenseRepository(
      auditLogRepository: audit,
      financialAccountRepository: accounts,
    );
    final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      supplierAccountRepository: supplierAccounts,
      financialAccountRepository: accounts,
      auditLogRepository: audit,
    );
    final requests = LocalNegativeBalanceApprovalRequestRepository();
    final workflow = NegativeBalanceApprovalWorkflowService(
      authRepository: authRepository,
      requestRepository: requests,
      legacyApprovalService: legacyService,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
      supplierRepository: suppliers,
      supplierAccountRepository: supplierAccounts,
      expenseRepository: expenses,
      purchaseRepository: purchases,
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(products),
      inventoryRepository: inventory,
    );
    final request = await requests.createRequest(
      NegativeBalanceApprovalRequestDraft(
        idempotencyKey: 'widget-expense',
        operationType: NegativeBalanceApprovalRequestOperationType.expense,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
        amountQirsh: 500,
        sourceDocumentId: 'widget-expense',
        payloadJson: '{"kind":"expense"}',
        payloadFingerprint: 'widget-fingerprint',
        requesterActorId: 'employee-demo',
        balanceAtRequestQirsh: 100,
        expectedBalanceAtRequestQirsh: -400,
        deficitAtRequestQirsh: 400,
        reason: 'اختبار واجهة الطلبات',
      ),
    );
    return _WidgetFixture(
      authRepository: authRepository,
      audit: audit,
      accounts: accounts,
      account: account,
      requests: requests,
      expenses: expenses,
      workflow: workflow,
      request: request,
    );
  }

  final LocalAuthRepository authRepository;
  final LocalAuditLogRepository audit;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount account;
  final LocalNegativeBalanceApprovalRequestRepository requests;
  final LocalExpenseRepository expenses;
  final NegativeBalanceApprovalWorkflowService workflow;
  final NegativeBalanceApprovalRequest request;

  Future<AuthController> signedInOwner() => _signedIn(
        phone: '01000000000',
        password: 'owner123',
      );

  Future<AuthController> signedInEmployee() => _signedIn(
        phone: '01100000000',
        password: 'employee123',
      );

  Future<AuthController> _signedIn({
    required String phone,
    required String password,
  }) async {
    final controller = AuthController(repository: authRepository);
    await controller.initialize();
    await controller.signIn(phone: phone, password: password);
    return controller;
  }

  Widget harness(AuthController auth, {bool startWithLauncher = false}) {
    final screen = NegativeBalanceApprovalRequestsScreen(
      workflowService: workflow,
      requestRepository: requests,
      financialAccountRepository: accounts,
      authRepository: authRepository,
    );
    return AuthScope(
      controller: auth,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: startWithLauncher
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => screen),
                      ),
                      child: const Text('فتح الطلبات'),
                    ),
                  ),
                ),
              )
            : Scaffold(body: screen),
      ),
    );
  }
}
